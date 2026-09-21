path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

methods_regex = /private func insertRow\(at index: Int\).*?private func deleteColumn\(at index: Int\) \{.*?\}\s+onChange\?\(\)\s+\}/m

new_methods = <<-SWIFT
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
SWIFT

if content.match?(methods_regex)
  content.sub!(methods_regex, new_methods)
  puts "Replaced methods."
else
  puts "Failed to replace methods."
end
File.write(path, content)
