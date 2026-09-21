path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# I will replace from `public var body` up to `// MARK: - Actions`
target_regex = /public var body: some View \{.*?\n\s+\/\/\ MARK: - Actions/m

new_content = <<-SWIFT
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

    // MARK: - Actions
SWIFT

content.sub!(target_regex, new_content)

File.write(path, content)
