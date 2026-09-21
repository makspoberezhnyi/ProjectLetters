path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

methods_regex = /private func deleteRow\(at index: Int\)/
new_methods = <<-SWIFT
private func insertRow(at index: Int) {
        let newRow = Array(repeating: "", count: tableData.headers.count)
        tableData.rows.insert(newRow, at: max(0, min(index, tableData.rows.count)))
        onChange?()
    }

    private func insertColumn(at index: Int) {
        let safeIndex = max(0, min(index, tableData.headers.count))
        let colLetter = TableFormulaEvaluator.columnLetter(for: tableData.headers.count)
        tableData.headers.insert("Col \\(colLetter)", at: safeIndex)
        for r in 0..<tableData.rows.count {
            tableData.rows[r].insert("", at: safeIndex)
        }
        onChange?()
    }

    private func deleteRow(at index: Int)
SWIFT
content.sub!(methods_regex, new_methods)

headers_regex = Regexp.new("let colLetter = TableFormulaEvaluator\\.columnLetter\\(for: colIdx\\)\\s+HStack\\(spacing: 8\\) \\{\\s+Text\\(colLetter\\).*?\\}\\s+\\}\\s+\\}\\s+\\.overlay", Regexp::MULTILINE)

new_headers = <<-SWIFT
self.headerCellView(colIdx: colIdx)
                    }
                }
                .overlay
SWIFT
content.sub!(headers_regex, new_headers)

data_cells_regex = Regexp.new('let cellKey = "\\\\(rowIdx),\\\\(colIdx)"\\s+let isEditing = activeEditingCell == cellKey.*?alignment: \\.trailing\\s+\\)\\s+\\}\\s+\\}\\s+\\.background', Regexp::MULTILINE)

new_data_cells = <<-SWIFT
self.dataCellView(rowIdx: rowIdx, colIdx: colIdx)
                        }
                    }
                    .background
SWIFT
content.sub!(data_cells_regex, new_data_cells)

helpers = <<-SWIFT
    @ViewBuilder
    private func headerCellView(colIdx: Int) -> some View {
        let colLetter = TableFormulaEvaluator.columnLetter(for: colIdx)
        HStack(spacing: 8) {
            Text(colLetter)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            
            TextField("Header", text: Binding(
                get: { tableData.headers.indices.contains(colIdx) ? tableData.headers[colIdx] : "" },
                set: { tableData.headers[colIdx] = $0; onChange?() }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder
    private func dataCellView(rowIdx: Int, colIdx: Int) -> some View {
        let cellKey = "\\(rowIdx),\\(colIdx)"
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
    }

    // MARK: - Actions
SWIFT

content.sub!("// MARK: - Actions", helpers)
File.write(path, content)
