path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

target_row_gutter = /\/\/ Left Row Number Gutter\s+Text\("\\\(rowNumber\)"\)\s+\.font\(\.system\(size: 9, weight: \.bold\)\)\s+\.foregroundColor\(\.secondary\.opacity\(0\.8\)\)\s+\.frame\(width: 24\)\s+\.frame\(maxHeight: \.infinity\)\s+\.background\(Color\(red: 0\.94, green: 0\.95, blue: 0\.97\)\)\s+\.overlay\(\s+Rectangle\(\)\s+\.frame\(width: 1\)\s+\.foregroundColor\(Color\.black\.opacity\(0\.1\)\),\s+alignment: \.trailing\s+\)/m

new_row_gutter = <<-SWIFT
// Left Row Number Gutter
                        Text("\\(rowNumber)")
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

if content.match?(target_row_gutter)
  content.sub!(target_row_gutter, new_row_gutter)
  puts "Replaced Row Number Gutter successfully."
else
  puts "Failed to match Row Number Gutter!"
end

File.write(path, content)
