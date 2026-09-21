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
    private static let functionRegex = try! NSRegularExpression(pattern: "(SUM|AVERAGE|AVG|MIN|MAX|COUNT|PRODUCT|IF|CONCAT|CONCATENATE|ABS|ROUND|INT|MEDIAN|STDEV)\\s*\\(([^)]+)\\)", options: [.caseInsensitive])
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

                var resultVal: Double = 0.0
                var resultStr: String? = nil
                
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
                case "ABS":
                    resultVal = numbers.first.map { abs($0) } ?? 0.0
                case "ROUND":
                    let val = numbers.first ?? 0.0
                    let places = numbers.dropFirst().first ?? 0.0
                    let multiplier = pow(10.0, places)
                    resultVal = round(val * multiplier) / multiplier
                case "INT":
                    resultVal = numbers.first.map { floor($0) } ?? 0.0
                case "MEDIAN":
                    let sorted = numbers.sorted()
                    if sorted.isEmpty { resultVal = 0.0 }
                    else if sorted.count % 2 == 1 { resultVal = sorted[sorted.count / 2] }
                    else { resultVal = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0 }
                case "IF":
                    // basic IF parser: IF(A1, 1, 0)
                    let cond = numbers.first ?? 0.0
                    let trueVal = numbers.dropFirst().first ?? 0.0
                    let falseVal = numbers.dropFirst(2).first ?? 0.0
                    resultVal = cond != 0.0 ? trueVal : falseVal
                case "CONCAT", "CONCATENATE":
                    // special string handler
                    resultStr = argTokens.map { token in
                        let t = token.trimmingCharacters(in: .whitespaces)
                        if t.hasPrefix("\"") && t.hasSuffix("\"") {
                            return String(t.dropFirst().dropLast())
                        } else if let coord = parseCellReference(t), rows.indices.contains(coord.row), rows[coord.row].indices.contains(coord.col) {
                            return rows[coord.row][coord.col]
                        }
                        return t
                    }.joined()
                default:
                    resultVal = 0.0
                }

                let finalReplacement = resultStr ?? formatNumber(resultVal)
                expr = nsExpr.replacingCharacters(in: match.range, with: finalReplacement)
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

        if sanitized.isEmpty { return "" }
        
        // Basic safety check for NSExpression to prevent obvious crashes
        let unsafeChars = CharacterSet(charactersIn: "+-*/.")
        if let last = sanitized.last, String(last).rangeOfCharacter(from: unsafeChars) != nil {
            return "#ERROR"
        }
        if let first = sanitized.first, String(first).rangeOfCharacter(from: unsafeChars) != nil && first != "-" {
            return "#ERROR"
        }
        
        do {
            // Using a simple regex to prevent severe syntax errors
            let validRegex = try NSRegularExpression(pattern: "^[0-9\\+\\-\\*\\/\\(\\)\\.\\s]+$")
            let range = NSRange(location: 0, length: (sanitized as NSString).length)
            if validRegex.firstMatch(in: sanitized, options: [], range: range) != nil {
                let mathExpr = NSExpression(format: sanitized)
                if let result = mathExpr.expressionValue(with: nil, context: nil) as? NSNumber {
                    return formatNumber(result.doubleValue)
                }
            } else {
                return "#ERROR"
            }
        } catch {
            return "#ERROR"
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

    public var columnWidths: [CGFloat]?
    public var tableWidth: CGFloat?
    public var tableHeight: CGFloat?
    public var columnNotes: [Int: String]?
    public var rowNotes: [Int: String]?



    public init(

        title: String = "Table",
        headers: [String] = ["", "", "", ""],
        rows: [[String]] = [
            ["", "", "", ""],
            ["", "", "", ""],
            ["", "", "", ""]
        ],
        columnWidths: [CGFloat]? = nil,
        tableWidth: CGFloat? = nil,
        tableHeight: CGFloat? = nil,
        columnNotes: [Int: String]? = nil,
        rowNotes: [Int: String]? = nil
    ) {
        self.title = title



        self.headers = headers
        self.rows = rows
        self.columnWidths = columnWidths
        self.tableWidth = tableWidth
        self.tableHeight = tableHeight
        self.columnNotes = columnNotes
        self.rowNotes = rowNotes
    }




    /// Returns the computed text for a specific cell
    public func evaluatedCell(row: Int, col: Int) -> String {
        let grid = [headers] + rows
        guard grid.indices.contains(row), grid[row].indices.contains(col) else { return "" }
        let raw = grid[row][col]
        if raw.hasPrefix("=") {
            var visited: Set<String> = []
            return TableFormulaEvaluator.evaluate(formula: raw, rows: grid, visited: &visited)
        }
        return raw
    }


    /// Evaluates all cells in the table for export
    public func evaluatedRows() -> [[String]] {
        let grid = [headers] + rows
        return (0..<grid.count).map { r in
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
    @FocusState private var activeEditingCell: String?
    @State private var actualTableWidth: CGFloat = 600
    @State private var dragBaseTableWidth: CGFloat? = nil
    @State private var dragBaseTableHeight: CGFloat? = nil
    @State private var actualTableHeight: CGFloat = 200


    
    public var fontFamily: String

    public init(
        tableData: Binding<StudioTableData>,
        fontFamily: String = "Default Serif (Georgia)",
        onDelete: (() -> Void)? = nil,
        onChange: (() -> Void)? = nil,
        onToast: ((String) -> Void)? = nil
    ) {
        self._tableData = tableData
        self.fontFamily = fontFamily
        self.onDelete = onDelete
        self.onChange = onChange
        self.onToast = onToast
    }


    public var body: some View {
        VStack(spacing: 0) {
            // Header Row (A, B, C...)
            HStack(spacing: 0) {
                // Top-Left Corner (Delete Table)
                Text("")
                    .frame(width: 44, height: 24)
                    .background(Color.primary.opacity(0.04))
                    .overlay(
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(Color.primary.opacity(0.1)),
                        alignment: .trailing
                    )
                    .contextMenu {
                        if let onDelete = onDelete {
                            Button("Delete Table", role: .destructive) { onDelete() }
                        }
                    }

                ForEach(0..<tableData.headers.count, id: \.self) { colIdx in
                    let colLetter = TableFormulaEvaluator.columnLetter(for: colIdx)
                    HStack(spacing: 2) {
                        Text(colLetter)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("(note)", text: Binding(
                            get: { tableData.columnNotes?[colIdx] ?? "" },
                            set: { val in 
                                if tableData.columnNotes == nil { tableData.columnNotes = [:] }
                                tableData.columnNotes?[colIdx] = val
                                onChange?()
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                        .frame(width: 40)
                    }
                    .frame(maxWidth: getColumnWidth(colIdx) == nil ? .infinity : nil)

                        .frame(width: getColumnWidth(colIdx))
                        .frame(height: 24)
                        .background(Color.primary.opacity(0.04))
                        .overlay(
                            ZStack(alignment: .trailing) {
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundColor(Color.primary.opacity(0.1))
                                
                                // Column Resizer Handle
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 6)
                                    .offset(x: 3)
                                    .onHover { isHovered in
                                        if isHovered { NSCursor.crosshair.push() } else { NSCursor.pop() }
                                    }
                                    .gesture(
                                        DragGesture()
                                            .onChanged { val in
                                                handleColumnDrag(colIdx: colIdx, translation: val.translation.width)
                                            }
                                            .onEnded { _ in
                                                endColumnDrag()
                                            }
                                    )
                            },
                            alignment: .trailing
                        )
                        .contextMenu {
                            Button("Add Column Before") { insertColumn(at: colIdx) }
                            Button("Add Column After") { insertColumn(at: colIdx + 1) }
                            Button("Delete Column") { deleteColumn(at: colIdx) }
                        }

                }
            }
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.primary.opacity(0.1)),
                alignment: .bottom
            )

            // Data Rows
            let gridCount = tableData.rows.count + 1
            ForEach(0..<gridCount, id: \.self) { rowIdx in
                HStack(spacing: 0) {
                    // Left Row Gutter (1, 2, 3...)
                    VStack(spacing: 0) {
                        Text("\(rowIdx + 1)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("(note)", text: Binding(
                            get: { tableData.rowNotes?[rowIdx] ?? "" },
                            set: { val in 
                                if tableData.rowNotes == nil { tableData.rowNotes = [:] }
                                tableData.rowNotes?[rowIdx] = val
                                onChange?()
                            }
                        ))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                        .frame(width: 40)
                    }
                    .frame(width: 44)
                        .frame(maxHeight: .infinity)
                        .background(Color.primary.opacity(0.04))
                        .overlay(
                            Rectangle()
                                .frame(width: 1)
                                .foregroundColor(Color.primary.opacity(0.1)),
                            alignment: .trailing
                        )
                        .contextMenu {
                            Button("Add Row Above") { insertRow(at: rowIdx) }
                            Button("Add Row Below") { insertRow(at: rowIdx + 1) }
                            Button("Delete Row") { deleteRow(at: rowIdx) }
                        }

                    ForEach(0..<tableData.headers.count, id: \.self) { colIdx in
                        self.dataCellView(rowIdx: rowIdx, colIdx: colIdx)
                    }
                }
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.primary.opacity(0.1)),
                    alignment: .bottom
                )
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    self.actualTableWidth = geo.size.width
                    self.actualTableHeight = geo.size.height
                }
            }
        )

        .frame(width: tableData.tableWidth, height: tableData.tableHeight)

        .overlay(
            // Bottom Right Drag Handle for Table Resizing
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 8, height: 8)
                .offset(x: 4, y: 4)
                .onHover { isHovered in
                    if isHovered { NSCursor.crosshair.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            if dragBaseTableWidth == nil {
                                dragBaseTableWidth = tableData.tableWidth ?? actualTableWidth
                                dragBaseTableHeight = tableData.tableHeight ?? actualTableHeight
                            }
                            let newW = max(200, (dragBaseTableWidth!) + val.translation.width)
                            let newH = max(100, (dragBaseTableHeight!) + val.translation.height)
                            tableData.tableWidth = newW
                            tableData.tableHeight = newH
                            onChange?()

                        }
                        .onEnded { _ in
                            dragBaseTableWidth = nil
                            dragBaseTableHeight = nil
                        }

                )
            , alignment: .bottomTrailing
        )
        .padding(.vertical, 8)

    }

    @ViewBuilder
    private func dataCellView(rowIdx: Int, colIdx: Int) -> some View {
        let cellKey = "\(rowIdx),\(colIdx)"
        let isEditing = activeEditingCell == cellKey
        let rawValue: String = {
            if rowIdx == 0 {
                return tableData.headers.indices.contains(colIdx) ? tableData.headers[colIdx] : ""
            } else {
                let dataRow = rowIdx - 1
                if tableData.rows.indices.contains(dataRow), tableData.rows[dataRow].indices.contains(colIdx) {
                    return tableData.rows[dataRow][colIdx]
                }
            }
            return ""
        }()
        let hasFormula = rawValue.hasPrefix("=")
        let displayValue = tableData.evaluatedCell(row: rowIdx, col: colIdx)

        ZStack(alignment: .leading) {
            Color.clear
                .contentShape(Rectangle())

                
            
            if isEditing || !hasFormula {
                TextField("—", text: Binding(

                    get: { rawValue },
                    set: { newVal in
                        if rowIdx == 0 {
                            if tableData.headers.indices.contains(colIdx) {
                                tableData.headers[colIdx] = newVal
                                onChange?()
                            }
                        } else {
                            let dataRow = rowIdx - 1
                            if tableData.rows.indices.contains(dataRow) {
                                while tableData.rows[dataRow].count <= colIdx {
                                    tableData.rows[dataRow].append("")
                                }
                                tableData.rows[dataRow][colIdx] = newVal
                                onChange?()
                            }
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .focused($activeEditingCell, equals: cellKey)
                .font(getTableFont(size: 11))
                .foregroundColor(hasFormula ? .blue : Color(red: 0.12, green: 0.12, blue: 0.14))
            } else {
                Text(displayValue.isEmpty ? "" : displayValue)
                    .font(getTableFont(size: 12))
                    .foregroundColor(hasFormula ? .accentColor : .primary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activeEditingCell = cellKey
                    }
                    .help("Formula: \(rawValue)")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: getColumnWidth(colIdx) == nil ? .infinity : nil, alignment: .leading)
        .frame(width: getColumnWidth(colIdx), alignment: .leading)
        .overlay(
            Rectangle()
                .frame(width: 1)

                .foregroundColor(Color.primary.opacity(0.1)),
            alignment: .trailing
        )
    }

    private func getTableFont(size: CGFloat) -> Font {
        switch fontFamily {
        case "SF Pro (Modern Sans)": return .system(size: size)
        case "New York (Editorial)": return .custom("NewYork-Regular", size: size)
        case "SF Mono (Code)": return .system(size: size, design: .monospaced)
        case "Default Serif (Georgia)": return .custom("Georgia", size: size)
        default: return .system(size: size)
        }
    }

        @State private var dragBaseColWidths: [CGFloat]? = nil

    private func getColumnWidth(_ colIdx: Int) -> CGFloat? {
        guard let cw = tableData.columnWidths, cw.indices.contains(colIdx) else { return nil }
        return cw[colIdx]
    }

    private func handleColumnDrag(colIdx: Int, translation: CGFloat) {
        if tableData.columnWidths == nil {
            // If dragging for the first time, we need to freeze all current geometric widths.
            // A simple approximation if we don't have true geometric widths is distributing evenly:
            let defaultW = (actualTableWidth - 32) / CGFloat(tableData.headers.count) // 32 is row gutter
            tableData.columnWidths = Array(repeating: defaultW, count: tableData.headers.count)
            // also fix the overall table width so it doesn't jump
            tableData.tableWidth = actualTableWidth
        }
        
        if dragBaseColWidths == nil {
            dragBaseColWidths = tableData.columnWidths
        }
        
        if var cw = tableData.columnWidths, let base = dragBaseColWidths, base.indices.contains(colIdx) {
            cw[colIdx] = max(40, base[colIdx] + translation)
            tableData.columnWidths = cw
            
            // Adjust table width to match new sum
            let newSum = cw.reduce(0, +) + 32
            tableData.tableWidth = newSum
            
            onChange?()
        }
    }

    private func endColumnDrag() {
        dragBaseColWidths = nil
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

    private func insertRow(at index: Int) {
        let newRow = Array(repeating: "", count: tableData.headers.count)
        if index == 0 {
            // Inserting before headers means new row becomes headers, old headers become row 0
            tableData.rows.insert(tableData.headers, at: 0)
            tableData.headers = newRow
        } else {
            tableData.rows.insert(newRow, at: max(0, min(index - 1, tableData.rows.count)))
        }
        onChange?()
    }

    private func insertColumn(at index: Int) {
        let safeIndex = max(0, min(index, tableData.headers.count))
        tableData.headers.insert("", at: safeIndex)
        for r in 0..<tableData.rows.count {
            tableData.rows[r].insert("", at: safeIndex)
        }
        onChange?()
    }

    private func deleteRow(at index: Int) {
        let totalRows = tableData.rows.count + 1
        guard totalRows > 1 else { return } // Can't delete the only row
        
        if index == 0 {
            // Deleting headers -> Row 0 becomes headers
            tableData.headers = tableData.rows.removeFirst()
        } else {
            let dataRow = index - 1
            if tableData.rows.indices.contains(dataRow) {
                tableData.rows.remove(at: dataRow)
            }
        }
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
