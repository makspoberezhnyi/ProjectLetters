path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# SmartTableView body
body_regex = /public var body: some View \{\s+VStack\(alignment: \.leading, spacing: 6\) \{\s+\/\/ 2\. Interactive Spreadsheet Grid.*?\.padding\(\.vertical, 8\)\s+\}/m

new_body = <<-SWIFT
public var body: some View {
        VStack(spacing: 0) {
            let gridCount = tableData.rows.count + 1
            ForEach(0..<gridCount, id: \\.self) { rowIdx in
                HStack(spacing: 0) {
                    ForEach(0..<tableData.headers.count, id: \\.self) { colIdx in
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
        .padding(.vertical, 8)
    }
SWIFT

if content.match?(body_regex)
  content.sub!(body_regex, new_body)
  puts "Replaced body."
else
  puts "Failed to replace body."
end

# Remove headerCellView completely
header_cell_regex = /@ViewBuilder\s+private func headerCellView\(colIdx: Int\) -> some View \{.*?\}\s+@ViewBuilder\s+private func dataCellView/m
content.sub!(header_cell_regex, "@ViewBuilder\n    private func dataCellView")

# Update dataCellView to use unified grid logic
data_cell_regex = /private func dataCellView\(rowIdx: Int, colIdx: Int\) -> some View \{.*?alignment: \.trailing\s+\)\s+\}/m

new_data_cell = <<-SWIFT
private func dataCellView(rowIdx: Int, colIdx: Int) -> some View {
        let cellKey = "\\(rowIdx),\\(colIdx)"
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
                .font(.system(size: 11, design: hasFormula || Double(displayValue) != nil ? .monospaced : .default))
                .foregroundColor(hasFormula ? .blue : Color(red: 0.12, green: 0.12, blue: 0.14))
            } else {
                Text(displayValue.isEmpty ? "" : displayValue)
                    .font(.system(size: 12))
                    .foregroundColor(hasFormula ? .accentColor : .primary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activeEditingCell = cellKey
                    }
                    .help("Formula: \\(rawValue)")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Divider()
            Button("Add Column Before") { insertColumn(at: colIdx) }
            Button("Add Column After") { insertColumn(at: colIdx + 1) }
            Button("Delete Column") { deleteColumn(at: colIdx) }
            Divider()
            if let onDelete = onDelete {
                Button("Delete Table", role: .destructive) { onDelete() }
            }
        }
    }
SWIFT

if content.match?(data_cell_regex)
  content.sub!(data_cell_regex, new_data_cell)
  puts "Replaced data cell."
else
  puts "Failed to replace data cell."
end

File.write(path, content)
