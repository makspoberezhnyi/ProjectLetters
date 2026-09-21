path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# 1. Remove Top Toolbar (HStack with 'Data Table' and buttons)
toolbar_regex = /\/\/ 1\. Top Toolbar & Title.*?VStack\(spacing: 0\) \{/m
content.sub!(toolbar_regex, "VStack(spacing: 0) {")

# 2. Make row # indicator much cleaner
row_gutter_regex = /\/\/ Corner Gutter \(Row index placeholder\).*?Text\("#"\).*?alignment: \.trailing\n\s+\)/m

new_row_gutter = <<-SWIFT
// Corner Gutter
                    Text("")
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.04))
                        .overlay(
                            Rectangle()
                                .frame(width: 1)
                                .foregroundColor(Color.primary.opacity(0.1)),
                            alignment: .trailing
                        )
SWIFT
content.sub!(row_gutter_regex, new_row_gutter)

# 3. Simplify Column Badges (A, B, C)
header_cols_regex = /\/\/ Header Columns.*?ForEach\(0\.\.<tableData\.headers\.count, id: \\\.self\) \{ colIdx in.*?let colLetter = TableFormulaEvaluator\.columnLetter\(for: colIdx\).*?HStack\(spacing: 4\) \{.*?\/\/ Column Letter Badge.*?Text\(colLetter\).*?\.background\(Color\.blue\.opacity\(0\.1\), in: RoundedRectangle\(cornerRadius: 3\)\).*?TextField\("Header".*?if tableData\.headers\.count > 1 \{.*?deleteColumn.*?\}\n\s+\}\n\s+\}\n\s+\.padding\(\.horizontal, 8\)\n\s+\.padding\(\.vertical, 6\)\n\s+\.frame\(maxWidth: \.infinity, alignment: \.leading\)\n\s+\.background\(Color\(red: 0\.93, green: 0\.95, blue: 0\.98\)\)\n\s+\.overlay\(\n\s+Rectangle\(\)\n\s+\.frame\(width: 1\)\n\s+\.foregroundColor\(Color\.black\.opacity\(0\.1\)\),\n\s+alignment: \.trailing\n\s+\)/m

new_header_cols = <<-SWIFT
// Header Columns
                    ForEach(0..<tableData.headers.count, id: \\.self) { colIdx in
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
SWIFT

content.sub!(header_cols_regex, new_header_cols)

# 4. Simplify Row Indicators
row_ind_regex = /\/\/ Row Indicator \(Number\).*?Text\(rowNumber\).*?alignment: \.trailing\n\s+\)/m
new_row_ind = <<-SWIFT
// Row Indicator (Number)
                        Text(rowNumber)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 24)
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
SWIFT

content.sub!(row_ind_regex, new_row_ind)

# 5. Simplify Data Cells (Remove 'fx' badge)
data_cell_regex = /\/\/ Evaluated Display with fx tag\s+HStack\(spacing: 4\) \{\s+Text\("fx"\)\s+\.font\(\.system\(size: 8, weight: \.bold\)\)\s+\.foregroundColor\(\.blue\.opacity\(0\.7\)\)\s+Text\(displayValue\.isEmpty \? "—" : displayValue\)\s+\.font\(\.system\(size: 11, weight: \.semibold\)\)\s+\.foregroundColor\(Color\(red: 0\.1, green: 0\.1, blue: 0\.15\)\)\s+\}/m

new_data_cell = <<-SWIFT
// Evaluated Display without fx tag
                                    Text(displayValue.isEmpty ? "" : displayValue)
                                        .font(.system(size: 12))
                                        .foregroundColor(hasFormula ? .accentColor : .primary)
SWIFT

content.sub!(data_cell_regex, new_data_cell)

# 6. Adjust Data Cell styling & Delete Row button
cell_style_regex = /\.padding\(\.horizontal, 8\)\s+\.padding\(\.vertical, 6\)\s+\.frame\(maxWidth: \.infinity, alignment: \.leading\)\s+\.overlay\(\s+Rectangle\(\)\s+\.frame\(width: 1\)\s+\.foregroundColor\(Color\.black\.opacity\(0\.08\)\),\s+alignment: \.trailing\s+\)\s+\}\s+\/\/ Row Delete Button\s+if tableData\.rows\.count > 1 \{\s+Button \{\s+deleteRow\(at: rowIdx\)\s+\} label: \{\s+Image\(systemName: "minus\.circle\.fill"\)\s+\.font\(\.system\(size: 9\)\)\s+\.foregroundColor\(\.red\.opacity\(0\.5\)\)\s+\}\s+\.buttonStyle\(\.plain\)\s+\.padding\(\.horizontal, 5\)\s+\.help\("Delete row \\\(rowNumber\)"\)\s+\}/m

new_cell_style = <<-SWIFT
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
SWIFT

content.sub!(cell_style_regex, new_cell_style)

# 7. Modify TextField to allow Command+A
# We can't trivially fix global Cmd+A vs TextField Cmd+A conflicts from regex,
# but we can try removing standard padding/margins so the layout is tighter.
# Also fix padding of the table body.
body_regex = /VStack\(spacing: 0\) \{\s+\/\/ Column Letter Indicator & Header Row/m
new_body = <<-SWIFT
VStack(spacing: 0) {
                // Column Letter Indicator & Header Row
SWIFT
content.sub!(body_regex, new_body)

table_border_regex = /\.background\(Color\.white\)\s+\.overlay\(\s+RoundedRectangle\(cornerRadius: 8, style: \.continuous\)\s+\.stroke\(Color\.blue\.opacity\(0\.2\), style: StrokeStyle\(lineWidth: 1, dash: \[4\]\)\)\s+\)/m

new_table_border = <<-SWIFT
.background(Color(NSColor.textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
SWIFT

content.sub!(table_border_regex, new_table_border)

File.write(path, content)
