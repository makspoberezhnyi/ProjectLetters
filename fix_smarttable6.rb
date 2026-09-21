path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# 1. Update font in dataCellView
data_cell_font_regex = /\.font\(\.system\(size: 11.*?\.foregroundColor\(hasFormula \? \.blue : Color\(red: 0\.12, green: 0\.12, blue: 0\.14\)\)\s+\} else \{\s+Text\(displayValue\.isEmpty \? "" : displayValue\)\s+\.font\(\.system\(size: 12\)\)/m

new_data_cell_font = <<-SWIFT
.font(getTableFont(size: 11))
                .foregroundColor(hasFormula ? .blue : Color(red: 0.12, green: 0.12, blue: 0.14))
            } else {
                Text(displayValue.isEmpty ? "" : displayValue)
                    .font(getTableFont(size: 12))
SWIFT
content.sub!(data_cell_font_regex, new_data_cell_font)

# 2. Update body to include headers and gutters
body_regex = /public var body: some View \{\s+VStack\(spacing: 0\) \{\s+let gridCount = tableData\.rows\.count \+ 1\s+ForEach\(0\.\.<gridCount, id: \\\.self\) \{ rowIdx in.*?\} else \{/m

new_body = <<-SWIFT
public var body: some View {
        VStack(spacing: 0) {
            // Header Row (A, B, C...)
            HStack(spacing: 0) {
                // Top-Left Corner (Delete Table)
                Text("")
                    .frame(width: 32, height: 24)
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

                ForEach(0..<tableData.headers.count, id: \\.self) { colIdx in
                    let colLetter = TableFormulaEvaluator.columnLetter(for: colIdx)
                    Text(colLetter)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Color.primary.opacity(0.04))
                        .overlay(
                            Rectangle()
                                .frame(width: 1)
                                .foregroundColor(Color.primary.opacity(0.1)),
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
            ForEach(0..<gridCount, id: \\.self) { rowIdx in
                HStack(spacing: 0) {
                    // Left Row Gutter (1, 2, 3...)
                    Text("\\(rowIdx + 1)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 32)
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

    @ViewBuilder
    private func dataCellView(rowIdx: Int, colIdx: Int) -> some View {
        let cellKey = "\\(rowIdx),\\(colIdx)"
        let isEditing = activeEditingCell == cellKey
        let rawValue: String = {
            if rowIdx == 0 {
SWIFT
content.sub!(/public var body: some View \{.*?if rowIdx == 0 \{/m, new_body)

File.write(path, content)
