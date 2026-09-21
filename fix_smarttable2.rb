path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# 1. Header Columns Badges replacement
target_headers = /\/\/ Header Columns\s+ForEach\(0\.\.<tableData\.headers\.count, id: \\\.self\) \{ colIdx in\s+let colLetter = TableFormulaEvaluator\.columnLetter\(for: colIdx\)\s+HStack\(spacing: 4\) \{\s+\/\/ Column Letter Badge.*?deleteColumn\(at: colIdx\)\s+\}\s+label: \{\s+Image\(systemName: "xmark"\).*?\}\s+\.buttonStyle\(\.plain\)\s+\.help\("Delete column \\\(colLetter\)"\)\s+\}\s+\}\s+\.padding\(\.horizontal, 8\)\s+\.padding\(\.vertical, 6\)\s+\.frame\(maxWidth: \.infinity, alignment: \.leading\)\s+\.background\(Color\(red: 0\.93, green: 0\.95, blue: 0\.98\)\)\s+\.overlay\(\s+Rectangle\(\)\s+\.frame\(width: 1\)\s+\.foregroundColor\(Color\.black\.opacity\(0\.1\)\),\s+alignment: \.trailing\s+\)/m

new_headers = <<-SWIFT
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

if content.match?(target_headers)
  content.sub!(target_headers, new_headers)
  puts "Replaced Header Columns successfully."
else
  puts "Failed to match Header Columns!"
end

# 2. Row Delete Button & Padding replacement
target_row_delete = /\.padding\(\.horizontal, 8\)\s+\.padding\(\.vertical, 6\)\s+\.frame\(maxWidth: \.infinity, alignment: \.leading\)\s+\.overlay\(\s+Rectangle\(\)\s+\.frame\(width: 1\)\s+\.foregroundColor\(Color\.primary\.opacity\(0\.1\)\),\s+alignment: \.trailing\s+\)\s+\}\s+\/\/ Row Delete Button\s+if tableData\.rows\.count > 1 \{\s+Button \{\s+deleteRow\(at: rowIdx\)\s+\} label: \{\s+Image\(systemName: "minus\.circle\.fill"\)\s+\.font\(\.system\(size: 9\)\)\s+\.foregroundColor\(\.red\.opacity\(0\.5\)\)\s+\}\s+\.buttonStyle\(\.plain\)\s+\.padding\(\.horizontal, 5\)\s+\.help\("Delete row \\\(rowNumber\)"\)\s+\}/m

new_row_delete = <<-SWIFT
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

if content.match?(target_row_delete)
  content.sub!(target_row_delete, new_row_delete)
  puts "Replaced Row Delete button successfully."
else
  puts "Failed to match Row Delete button!"
end


File.write(path, content)
