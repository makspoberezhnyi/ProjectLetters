import SwiftUI

public struct StudioTableData: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var headers: [String]
    public var rows: [[String]]

    public init(
        headers: [String] = ["Item / Metric", "Q1 Actual", "Q2 Actual", "Total"],
        rows: [[String]] = [
            ["Core Platform", "$1,200", "$2,400", "$3,600"],
            ["AI Copilot", "$800", "$1,600", "$2,400"],
            ["Enterprise Studio", "$2,500", "$5,000", "$7,500"]
        ]
    ) {
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

    public init(
        tableData: Binding<StudioTableData>,
        onDelete: (() -> Void)? = nil,
        onChange: (() -> Void)? = nil
    ) {
        self._tableData = tableData
        self.onDelete = onDelete
        self.onChange = onChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Table Pro Action Strip
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "tablecells.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 12))
                    Text("Interactive Table")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
                }

                Spacer()

                // Table Actions
                HStack(spacing: 4) {
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
                        Label("Column", systemImage: "plus")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Add new column")

                    Button {
                        recalculateTotals()
                    } label: {
                        Label("Auto Sum", systemImage: "function")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help("Automatically compute sum for Total column")

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
                                set: {
                                    if tableData.rows.indices.contains(rowIdx) {
                                        while tableData.rows[rowIdx].count <= colIdx {
                                            tableData.rows[rowIdx].append("")
                                        }
                                        tableData.rows[rowIdx][colIdx] = $0
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
}
