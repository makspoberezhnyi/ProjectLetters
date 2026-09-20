import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Table Formula Evaluator
public final class TableFormulaEvaluator {
    /// Converts a 0-indexed column index to standard spreadsheet column letter (0 -> A, 1 -> B, ..., 26 -> AA)
    public static func columnLetter(for index: Int) -> String {
        var result = ""
        var num = index
        while num >= 0 {
            let charCode = UInt32(65 + (num % 26))
            if let scalar = UnicodeScalar(charCode) {
                result = String(Character(scalar)) + result
            }
            num = (num / 26) - 1
        }
        return result.isEmpty ? "A" : result
    }

    /// Converts column letter (e.g. "A", "B", "AA") to 0-indexed column index
    public static func columnIndex(for letter: String) -> Int? {
        let upper = letter.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty else { return nil }
        var result = 0
        for scalar in upper.unicodeScalars {
            guard scalar.value >= 65 && scalar.value <= 90 else { return nil }
            result = result * 26 + Int(scalar.value - 64)
        }
        return result - 1
    }

    /// Parses a single cell reference like "A1", "B2", "c3" into (col: 0, row: 0)
    public static func parseCellReference(_ ref: String) -> (col: Int, row: Int)? {
        let trimmed = ref.trimmingCharacters(in: .whitespaces).uppercased()
        let letters = trimmed.prefix(while: { $0.isLetter })
        let digits = trimmed.suffix(from: letters.endIndex)
        guard !letters.isEmpty, !digits.isEmpty, let rowNum = Int(digits), rowNum > 0 else { return nil }
        guard let colIdx = columnIndex(for: String(letters)) else { return nil }
        return (col: colIdx, row: rowNum - 1)
    }

    /// Parses a range like "A1:A3" or "A1:C2" into a list of cell coordinates
    public static func parseRangeReference(_ rangeStr: String) -> [(col: Int, row: Int)] {
        let parts = rangeStr.split(separator: ":")
        guard parts.count == 2,
              let start = parseCellReference(String(parts[0])),
              let end = parseCellReference(String(parts[1])) else {
            return []
        }
        let minCol = min(start.col, end.col)
        let maxCol = max(start.col, end.col)
        let minRow = min(start.row, end.row)
        let maxRow = max(start.row, end.row)

        var coords: [(col: Int, row: Int)] = []
        for r in minRow...maxRow {
            for c in minCol...maxCol {
                coords.append((col: c, row: r))
            }
        }
        return coords
    }

    /// Extracts numeric value of a cell, resolving formulas recursively with cycle protection
    public static func getNumericValue(
        rows: [[String]],
        col: Int,
        row: Int,
        visited: inout Set<String>
    ) -> Double {
        guard rows.indices.contains(row), rows[row].indices.contains(col) else { return 0.0 }
        let cellRef = "\(columnLetter(for: col))\(row + 1)"
        if visited.contains(cellRef) {
            return 0.0 // prevent cycle recursion
        }
        visited.insert(cellRef)
        defer { visited.remove(cellRef) }

        let raw = rows[row][col].trimmingCharacters(in: .whitespaces)
        if raw.hasPrefix("=") {
            let eval = evaluate(formula: raw, rows: rows, visited: &visited)
            return parseNumber(eval) ?? 0.0
        }
        return parseNumber(raw) ?? 0.0
    }

    public static func parseNumber(_ str: String) -> Double? {
        let cleaned = str
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned)
    }

    // Cached regex for function matching
    private static let functionRegex = try! NSRegularExpression(pattern: "(SUM|AVERAGE|AVG|MIN|MAX|COUNT|PRODUCT)\\s*\\(([^)]+)\\)", options: [.caseInsensitive])
    private static let cellRegex = try! NSRegularExpression(pattern: "\\b([A-Za-z]+[0-9]+)\\b", options: [])

    /// Evaluates any formula expression (e.g. "=A1-B1", "=SUM(A1:A3)", "=A1*1.15", "=AVERAGE(B1:B4)")
    public static func evaluate(
        formula: String,
        rows: [[String]],
        visited: inout Set<String>
    ) -> String {
        guard formula.hasPrefix("=") else { return formula }
        var expr = String(formula.dropFirst()).trimmingCharacters(in: .whitespaces)
        guard !expr.isEmpty else { return "" }

        // 1. Process Functions: SUM, AVERAGE, AVG, MIN, MAX, COUNT, PRODUCT
        while let match = functionRegex.firstMatch(in: expr, options: [], range: NSRange(location: 0, length: (expr as NSString).length)) {
                let nsExpr = expr as NSString
                let funcName = nsExpr.substring(with: match.range(at: 1)).uppercased()
                let argsStr = nsExpr.substring(with: match.range(at: 2))

                var numbers: [Double] = []
                let argTokens = argsStr.components(separatedBy: ",")
                for token in argTokens {
                    let t = token.trimmingCharacters(in: .whitespaces)
                    if t.contains(":") {
                        let coords = parseRangeReference(t)
                        for coord in coords {
                            numbers.append(getNumericValue(rows: rows, col: coord.col, row: coord.row, visited: &visited))
                        }
                    } else if let coord = parseCellReference(t) {
                        numbers.append(getNumericValue(rows: rows, col: coord.col, row: coord.row, visited: &visited))
                    } else if let num = parseNumber(t) {
                        numbers.append(num)
                    }
                }

                let resultVal: Double
                switch funcName {
                case "SUM":
                    resultVal = numbers.reduce(0.0, +)
                case "AVERAGE", "AVG":
                    resultVal = numbers.isEmpty ? 0.0 : numbers.reduce(0.0, +) / Double(numbers.count)
                case "MIN":
                    resultVal = numbers.min() ?? 0.0
                case "MAX":
                    resultVal = numbers.max() ?? 0.0
                case "COUNT":
                    resultVal = Double(numbers.count)
                case "PRODUCT":
                    resultVal = numbers.isEmpty ? 0.0 : numbers.reduce(1.0, *)
                default:
                    resultVal = 0.0
                }

                expr = nsExpr.replacingCharacters(in: match.range, with: formatNumber(resultVal))
            }

        // 2. Replace remaining individual cell references (e.g. A1, B2, C3) with their numeric values
        let nsExpr = expr as NSString
        let matches = cellRegex.matches(in: expr, options: [], range: NSRange(location: 0, length: nsExpr.length)).reversed()
        var replaced = expr
        for match in matches {
            let cellRefStr = (replaced as NSString).substring(with: match.range)
            if let coord = parseCellReference(cellRefStr) {
                let val = getNumericValue(rows: rows, col: coord.col, row: coord.row, visited: &visited)
                replaced = (replaced as NSString).replacingCharacters(in: match.range, with: "\(val)")
            }
        }
        expr = replaced

        // 3. Clean up for arithmetic evaluation
        let sanitized = expr
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        if let num = Double(sanitized) {
            return formatNumber(num)
        }

        let mathExpr = NSExpression(format: sanitized)
        if let result = mathExpr.expressionValue(with: nil, context: nil) as? NSNumber {
            return formatNumber(result.doubleValue)
        }

        return expr
    }

    public static func formatNumber(_ val: Double) -> String {
        if val.isInfinite || val.isNaN {
            return "#ERROR!"
        }
        if val.truncatingRemainder(dividingBy: 1.0) == 0 {
            return "\(Int(val))"
        }
        return String(format: "%.2f", val)
    }
}

// MARK: - Studio Table Data Model
public struct StudioTableData: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var title: String = "Table"
    public var headers: [String]
    public var rows: [[String]]

    public init(
        title: String = "Table",
        headers: [String] = ["Item", "Quantity (A)", "Unit Price (B)", "Total (A*B)"],
        rows: [[String]] = [
            ["Platform Core", "10", "150", "=A1*B1"],
            ["UI Components", "8", "120", "=A2*B2"],
            ["AI Services", "5", "300", "=A3*B3"]
        ]
    ) {
        self.title = title
        self.headers = headers
        self.rows = rows
    }

    /// Returns the computed text for a specific cell
    public func evaluatedCell(row: Int, col: Int) -> String {
        guard rows.indices.contains(row), rows[row].indices.contains(col) else { return "" }
        let raw = rows[row][col]
        if raw.hasPrefix("=") {
            var visited: Set<String> = []
            return TableFormulaEvaluator.evaluate(formula: raw, rows: rows, visited: &visited)
        }
        return raw
    }

    /// Evaluates all cells in the table for export
    public func evaluatedRows() -> [[String]] {
        return (0..<rows.count).map { r in
            (0..<headers.count).map { c in
                evaluatedCell(row: r, col: c)
            }
        }
    }

    public func toMarkdown() -> String {
        let eval = evaluatedRows()
        var md = "| " + headers.joined(separator: " | ") + " |\n"
        md += "| " + headers.map { _ in ":---" }.joined(separator: " | ") + " |\n"
        for row in eval {
            md += "| " + row.joined(separator: " | ") + " |\n"
        }
        return md
    }

    public func toCSV() -> String {
        let eval = evaluatedRows()
        var csv = headers.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        for row in eval {
            csv += row.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        }
        return csv
    }

    public func toTSV() -> String {
        let eval = evaluatedRows()
        var tsv = headers.joined(separator: "\t") + "\n"
        for row in eval {
            tsv += row.joined(separator: "\t") + "\n"
        }
        return tsv
    }

    private func escapeCSV(_ str: String) -> String {
        if str.contains(",") || str.contains("\"") || str.contains("\n") {
            return "\"\(str.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return str
    }

    public static func fromCSV(_ text: String) -> StudioTableData? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let parseLine: (String) -> [String] = { line in
            line.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" \t"))
            }
        }

        let headers = parseLine(lines[0])
        var dataRows: [[String]] = []
        for i in 1..<lines.count {
            dataRows.append(parseLine(lines[i]))
        }

        return StudioTableData(
            headers: headers,
            rows: dataRows.isEmpty ? [Array(repeating: "", count: headers.count)] : dataRows
        )
    }

    public static func fromTSV(_ text: String) -> StudioTableData? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let parseLine: (String) -> [String] = { line in
            line.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        let headers = parseLine(lines[0])
        var dataRows: [[String]] = []
        for i in 1..<lines.count {
            dataRows.append(parseLine(lines[i]))
        }

        return StudioTableData(
            headers: headers,
            rows: dataRows.isEmpty ? [Array(repeating: "", count: headers.count)] : dataRows
        )
    }

    public static func fromMarkdown(_ text: String) -> StudioTableData? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("|") && $0.hasSuffix("|") }

        guard lines.count >= 2 else { return nil }

        let parseRow: (String) -> [String] = { line in
            line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }

        let headers = parseRow(lines[0])
        var dataRows: [[String]] = []

        for i in 1..<lines.count {
            let row = parseRow(lines[i])
            if row.allSatisfy({ $0.contains("---") || $0.contains(":-") }) {
                continue
            }
            dataRows.append(row)
        }

        return StudioTableData(headers: headers, rows: dataRows.isEmpty ? [["", "", "", ""]] : dataRows)
    }
}

// MARK: - Smart Table View
public struct SmartTableView: View {
    @Binding var tableData: StudioTableData
    var onDelete: (() -> Void)? = nil
    var onChange: (() -> Void)? = nil
    var onToast: ((String) -> Void)? = nil

    @State private var showingFormulaHelper: Bool = false
    @State private var activeEditingCell: String? = nil // "row,col"

    public init(
        tableData: Binding<StudioTableData>,
        onDelete: (() -> Void)? = nil,
        onChange: (() -> Void)? = nil,
        onToast: ((String) -> Void)? = nil
    ) {
        self._tableData = tableData
        self.onDelete = onDelete
        self.onChange = onChange
        self.onToast = onToast
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 1. Table Header & Toolbar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "tablecells.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 12))

                    TextField("Table Title", text: $tableData.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
                        .frame(minWidth: 120, maxWidth: 260)
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 4) {
                    // Formula Reference Helper
                    Button {
                        showingFormulaHelper.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            Text("fx")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Formulas")
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .popover(isPresented: $showingFormulaHelper, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Table Formulas & Cell References")
                                .font(.system(size: 12, weight: .bold))

                            Text("Use column letters (A, B, C...) and row numbers (1, 2, 3...) to write formulas:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                FormulaTipRow(formula: "=A1+B1", desc: "Add two cells together")
                                FormulaTipRow(formula: "=A1-B1", desc: "Subtract cell B1 from A1")
                                FormulaTipRow(formula: "=A1*B1", desc: "Multiply quantity by price")
                                FormulaTipRow(formula: "=A1/B1", desc: "Divide cells")
                                FormulaTipRow(formula: "=SUM(A1:A5)", desc: "Sum a column range")
                                FormulaTipRow(formula: "=AVERAGE(B1:B5)", desc: "Compute average of range")
                                FormulaTipRow(formula: "=MIN(C1:C5)", desc: "Minimum value in range")
                                FormulaTipRow(formula: "=MAX(C1:C5)", desc: "Maximum value in range")
                            }
                            .padding(8)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(14)
                        .frame(width: 300)
                    }

                    // Add Row
                    Button {
                        addRow()
                    } label: {
                        Label("Row", systemImage: "plus")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Add new row")

                    // Add Column
                    Button {
                        addColumn()
                    } label: {
                        Label("Column", systemImage: "plus")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Add new column")

                    // Copy for Excel / TSV
                    Button {
                        copyTableForExcel()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Copy table formatted for Excel & Google Sheets")

                    // Paste Excel
                    Button {
                        pasteFromExcel()
                    } label: {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Paste spreadsheet data copied from Excel")

                    // Export CSV
                    Button {
                        exportTableAsCSV()
                    } label: {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Export as CSV file")

                    // Delete Table
                    if let onDelete = onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete table")
                        .padding(.leading, 4)
                    }
                }
            }
            .padding(.horizontal, 4)

            // 2. Interactive Spreadsheet Grid
            VStack(spacing: 0) {
                // Column Letter Indicator & Header Row
                HStack(spacing: 0) {
                    // Corner Gutter (Row index placeholder)
                    Text("#")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.7))
                        .frame(width: 24, height: 32)
                        .background(Color(red: 0.90, green: 0.92, blue: 0.95))
                        .overlay(
                            Rectangle()
                                .frame(width: 1)
                                .foregroundColor(Color.black.opacity(0.12)),
                            alignment: .trailing
                        )

                    // Header Columns
                    ForEach(0..<tableData.headers.count, id: \.self) { colIdx in
                        let colLetter = TableFormulaEvaluator.columnLetter(for: colIdx)
                        HStack(spacing: 4) {
                            // Column Letter Badge (A, B, C...)
                            Text(colLetter)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))

                            TextField("Header", text: Binding(
                                get: { tableData.headers.indices.contains(colIdx) ? tableData.headers[colIdx] : "" },
                                set: { tableData.headers[colIdx] = $0; onChange?() }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))

                            if tableData.headers.count > 1 {
                                Button {
                                    deleteColumn(at: colIdx)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                .help("Delete column \(colLetter)")
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.93, green: 0.95, blue: 0.98))
                        .overlay(
                            Rectangle()
                                .frame(width: 1)
                                .foregroundColor(Color.black.opacity(0.1)),
                            alignment: .trailing
                        )
                    }
                }
                .overlay(
                    Rectangle()
                        .frame(height: 1.5)
                        .foregroundColor(Color.black.opacity(0.18)),
                    alignment: .bottom
                )

                // Data Rows with Row Number Gutter (1, 2, 3...)
                ForEach(0..<tableData.rows.count, id: \.self) { rowIdx in
                    let rowNumber = rowIdx + 1
                    HStack(spacing: 0) {
                        // Left Row Number Gutter
                        Text("\(rowNumber)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                            .frame(width: 24)
                            .frame(maxHeight: .infinity)
                            .background(Color(red: 0.94, green: 0.95, blue: 0.97))
                            .overlay(
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundColor(Color.black.opacity(0.1)),
                                alignment: .trailing
                            )

                        // Data Cells
                        ForEach(0..<tableData.headers.count, id: \.self) { colIdx in
                            let cellKey = "\(rowIdx),\(colIdx)"
                            let isEditing = activeEditingCell == cellKey
                            let rawValue: String = {
                                if tableData.rows.indices.contains(rowIdx), tableData.rows[rowIdx].indices.contains(colIdx) {
                                    return tableData.rows[rowIdx][colIdx]
                                }
                                return ""
                            }()
                            let hasFormula = rawValue.hasPrefix("=")
                            let displayValue = tableData.evaluatedCell(row: rowIdx, col: colIdx)

                            ZStack(alignment: .leading) {
                                if isEditing || !hasFormula {
                                    TextField("—", text: Binding(
                                        get: { rawValue },
                                        set: { newVal in
                                            if tableData.rows.indices.contains(rowIdx) {
                                                while tableData.rows[rowIdx].count <= colIdx {
                                                    tableData.rows[rowIdx].append("")
                                                }
                                                tableData.rows[rowIdx][colIdx] = newVal
                                                onChange?()
                                            }
                                        }
                                    ))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11, design: hasFormula || Double(displayValue) != nil ? .monospaced : .default))
                                    .foregroundColor(hasFormula ? .blue : Color(red: 0.12, green: 0.12, blue: 0.14))
                                } else {
                                    // Evaluated Display with fx tag
                                    HStack(spacing: 4) {
                                        Text("fx")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.blue.opacity(0.7))

                                        Text(displayValue.isEmpty ? "—" : displayValue)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        activeEditingCell = cellKey
                                    }
                                    .help("Formula: \(rawValue)")
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundColor(Color.black.opacity(0.08)),
                                alignment: .trailing
                            )
                        }

                        // Row Delete Button
                        if tableData.rows.count > 1 {
                            Button {
                                deleteRow(at: rowIdx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.red.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 5)
                            .help("Delete row \(rowNumber)")
                        }
                    }
                    .background(rowIdx % 2 == 0 ? Color.white : Color(red: 0.98, green: 0.98, blue: 0.99))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.black.opacity(0.06)),
                        alignment: .bottom
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions
    private func addRow() {
        let newRow = Array(repeating: "", count: tableData.headers.count)
        tableData.rows.append(newRow)
        onChange?()
    }

    private func addColumn() {
        let colLetter = TableFormulaEvaluator.columnLetter(for: tableData.headers.count)
        tableData.headers.append("Column \(colLetter)")
        for r in 0..<tableData.rows.count {
            tableData.rows[r].append("")
        }
        onChange?()
    }

    private func deleteRow(at index: Int) {
        guard tableData.rows.count > 1, tableData.rows.indices.contains(index) else { return }
        tableData.rows.remove(at: index)
        onChange?()
    }

    private func deleteColumn(at index: Int) {
        guard tableData.headers.count > 1, tableData.headers.indices.contains(index) else { return }
        tableData.headers.remove(at: index)
        for r in 0..<tableData.rows.count {
            if tableData.rows[r].indices.contains(index) {
                tableData.rows[r].remove(at: index)
            }
        }
        onChange?()
    }

    private func copyTableForExcel() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(tableData.toTSV(), forType: .string)
        onToast?("✓ Copied table to clipboard for Excel / Sheets")
    }

    private func pasteFromExcel() {
        guard let clipboard = NSPasteboard.general.string(forType: .string), !clipboard.isEmpty else {
            onToast?("⚠️ Clipboard is empty")
            return
        }

        if let parsed = StudioTableData.fromTSV(clipboard) ?? StudioTableData.fromCSV(clipboard) {
            tableData.headers = parsed.headers
            tableData.rows = parsed.rows
            onChange?()
            onToast?("✓ Imported table from Excel clipboard")
        } else {
            onToast?("⚠️ Could not parse spreadsheet data")
        }
    }

    private func exportTableAsCSV() {
        let panel = NSSavePanel()
        panel.title = "Export Table as CSV"
        panel.nameFieldStringValue = "\(tableData.title.replacingOccurrences(of: " ", with: "_")).csv"
        if let type = UTType(filenameExtension: "csv") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try tableData.toCSV().write(to: url, atomically: true, encoding: .utf8)
                onToast?("✓ Exported CSV to \(url.lastPathComponent)")
            } catch {
                onToast?("⚠️ Failed to export CSV: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Formula Helper Tip Row
private struct FormulaTipRow: View {
    let formula: String
    let desc: String

    var body: some View {
        HStack {
            Text(formula)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.blue)
            Spacer()
            Text(desc)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
