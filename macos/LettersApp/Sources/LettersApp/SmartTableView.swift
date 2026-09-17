import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct StudioTableData: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var title: String = "Interactive Smart Table"
    public var headers: [String]
    public var rows: [[String]]

    public init(
        title: String = "Interactive Smart Table",
        headers: [String] = ["Item / Metric", "Q1 Actual", "Q2 Actual", "Total"],
        rows: [[String]] = [
            ["Core Platform", "$1,200", "$2,400", "$3,600"],
            ["AI Copilot", "$800", "$1,600", "$2,400"],
            ["Enterprise Studio", "$2,500", "$5,000", "$7,500"]
        ]
    ) {
        self.title = title
        self.headers = headers
        self.rows = rows
    }

    public func toMarkdown() -> String {
        var md = "| " + headers.joined(separator: " | ") + " |\n"
        md += "| " + headers.map { _ in ":---" }.joined(separator: " | ") + " |\n"
        for row in rows {
            md += "| " + row.joined(separator: " | ") + " |\n"
        }
        return md
    }

    public func toCSV() -> String {
        var csv = headers.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        for row in rows {
            csv += row.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        }
        return csv
    }

    public func toTSV() -> String {
        var tsv = headers.joined(separator: "\t") + "\n"
        for row in rows {
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
            rows: dataRows.isEmpty ? [Array(repeating: "$0", count: headers.count)] : dataRows
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
            rows: dataRows.isEmpty ? [Array(repeating: "$0", count: headers.count)] : dataRows
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

public struct SmartTableView: View {
    @Binding var tableData: StudioTableData
    var onDelete: (() -> Void)? = nil
    var onChange: (() -> Void)? = nil
    var onToast: ((String) -> Void)? = nil

    @State private var showingImportMenu: Bool = false

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
            // Table Pro Action Strip
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "tablecells.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 12))
                    Text(tableData.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
                }

                Spacer()

                // Table Actions
                HStack(spacing: 4) {
                    // 1. Copy for Excel / Sheets
                    Button {
                        copyTableForExcel()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy for Excel")
                        }
                        .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Copy table formatted for Microsoft Excel & Google Sheets")

                    // 2. Export as CSV
                    Button {
                        exportTableAsCSV()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.doc")
                            Text("Export CSV")
                        }
                        .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Export as .csv file")

                    // 3. Paste from Excel
                    Button {
                        pasteFromExcel()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.doc")
                            Text("Paste Excel")
                        }
                        .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Paste spreadsheet data copied from Excel or Numbers")

                    // 4. Add Row / Column
                    Button {
                        addRow()
                    } label: {
                        Label("Row", systemImage: "plus")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Add new data row")

                    Button {
                        addColumn()
                    } label: {
                        Label("Col", systemImage: "plus")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Add new column")

                    // 5. Auto Sum Formula
                    Button {
                        recalculateTotals()
                    } label: {
                        Label("Auto Sum", systemImage: "function")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .help("Automatically compute sum for Total column")

                    // 6. Delete
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

            // Graphical Table Grid
            VStack(spacing: 0) {
                // 1. Header Row
                HStack(spacing: 0) {
                    ForEach(0..<tableData.headers.count, id: \.self) { colIdx in
                        HStack {
                            TextField("Header", text: Binding(
                                get: { tableData.headers.indices.contains(colIdx) ? tableData.headers[colIdx] : "" },
                                set: { tableData.headers[colIdx] = $0; onChange?() }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))

                            if tableData.headers.count > 1 {
                                Button {
                                    deleteColumn(at: colIdx)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .help("Delete column")
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
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

                // 2. Data Rows
                ForEach(0..<tableData.rows.count, id: \.self) { rowIdx in
                    HStack(spacing: 0) {
                        ForEach(0..<tableData.headers.count, id: \.self) { colIdx in
                            TextField("—", text: Binding(
                                get: {
                                    if tableData.rows.indices.contains(rowIdx),
                                       tableData.rows[rowIdx].indices.contains(colIdx) {
                                        return tableData.rows[rowIdx][colIdx]
                                    }
                                    return ""
                                },
                                set: { newVal in
                                    if tableData.rows.indices.contains(rowIdx) {
                                        while tableData.rows[rowIdx].count <= colIdx {
                                            tableData.rows[rowIdx].append("")
                                        }
                                        tableData.rows[rowIdx][colIdx] = evaluateFormulaInput(newVal)
                                        onChange?()
                                    }
                                }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: colIdx == tableData.headers.count - 1 ? .semibold : .regular, design: colIdx > 0 ? .monospaced : .default))
                            .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundColor(Color.black.opacity(0.08)),
                                alignment: .trailing
                            )
                        }

                        // Row Delete Icon
                        if tableData.rows.count > 1 {
                            Button {
                                deleteRow(at: rowIdx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 6)
                            .help("Delete row")
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

    // MARK: - Formula Evaluation
    private func evaluateFormulaInput(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("=") else { return text }

        let expr = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        // Evaluate arithmetic expression like =1200+2400 or =150*1.2
        let sanitized = expr.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let mathExpr = NSExpression(format: sanitized)
        if let result = mathExpr.expressionValue(with: nil, context: nil) as? NSNumber {
            return "$\(result.intValue)"
        }
        return text
    }

    // MARK: - Actions
    private func addRow() {
        let newRow = Array(repeating: "$0", count: tableData.headers.count)
        tableData.rows.append(newRow)
        onChange?()
    }

    private func addColumn() {
        let colNum = tableData.headers.count + 1
        tableData.headers.append("Column \(colNum)")
        for r in 0..<tableData.rows.count {
            tableData.rows[r].append("$0")
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

    private func recalculateTotals() {
        for r in 0..<tableData.rows.count {
            var sum: Double = 0
            for c in 1..<tableData.rows[r].count - 1 {
                let valStr = tableData.rows[r][c].replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                if let val = Double(valStr.trimmingCharacters(in: .whitespaces)) {
                    sum += val
                }
            }
            if sum > 0 && tableData.rows[r].count > 1 {
                let lastIdx = tableData.rows[r].count - 1
                tableData.rows[r][lastIdx] = "$\(Int(sum))"
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
        panel.nameFieldStringValue = "Table_Export.csv"
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
