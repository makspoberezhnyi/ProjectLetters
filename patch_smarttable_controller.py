import re

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "r") as f:
    code = f.read()

# 1. Update bindings
code = re.sub(r'@Binding var tableData: StudioTableData', 
              r'@ObservedObject var store: LettersDocumentController\n    var tableId: UUID\n    private var tableData: StudioTableData {\n        store.tables.first(where: { $0.id == tableId }) ?? StudioTableData(headers: [], rows: [])\n    }', code)

# 2. Update all the mutators
def replace_mutation(func_name, action_name, logic):
    pattern = r'private func ' + func_name + r'\([^)]*\) \{[\s\S]*?onChange\?\(\)\n    \}'
    replacement = f"""private func {func_name} {{
        store.mutateTable(id: tableId, actionName: "{action_name}") {{ data in
{logic}
        }}
        onChange?()
    }}"""
    
    if "deleteRow" in func_name:
        pattern = r'private func deleteRow\(at index: Int\) \{[\s\S]*?onChange\?\(\)\n    \}'
        replacement = f"""private func deleteRow(at index: Int) {{
        let totalRows = tableData.rows.count + 1
        guard totalRows > 1 else {{ return }}
        store.mutateTable(id: tableId, actionName: "{action_name}") {{ data in
{logic}
        }}
        onChange?()
    }}"""
    if "deleteColumn" in func_name:
        pattern = r'private func deleteColumn\(at index: Int\) \{[\s\S]*?onChange\?\(\)\n    \}'
        replacement = f"""private func deleteColumn(at index: Int) {{
        guard tableData.headers.count > 1 else {{ return }}
        store.mutateTable(id: tableId, actionName: "{action_name}") {{ data in
{logic}
        }}
        onChange?()
    }}"""
    global code
    code = re.sub(pattern, replacement, code)

replace_mutation('addRow', 'Add Row', '            let newRow = Array(repeating: "", count: data.headers.count)\n            data.rows.append(newRow)')
replace_mutation('addColumn', 'Add Column', '            let colLetter = TableFormulaEvaluator.columnLetter(for: data.headers.count)\n            data.headers.append("Column \\(colLetter)")\n            for r in 0..<data.rows.count {\n                data.rows[r].append("")\n            }')
replace_mutation('insertRow\\(at index: Int\\)', 'Insert Row', '            let newRow = Array(repeating: "", count: data.headers.count)\n            if index == 0 {\n                data.rows.insert(data.headers, at: 0)\n                data.headers = newRow\n            } else {\n                data.rows.insert(newRow, at: max(0, min(index - 1, data.rows.count)))\n            }')
replace_mutation('insertColumn\\(at index: Int\\)', 'Insert Column', '            let safeIndex = max(0, min(index, data.headers.count))\n            data.headers.insert("", at: safeIndex)\n            for r in 0..<data.rows.count {\n                data.rows[r].insert("", at: safeIndex)\n            }')

code = re.sub(r'private func deleteRow\(at index: Int\) \{[\s\S]*?onChange\?\(\)\n    \}', f"""private func deleteRow(at index: Int) {{
        let totalRows = tableData.rows.count + 1
        guard totalRows > 1 else {{ return }}
        store.mutateTable(id: tableId, actionName: "Delete Row") {{ data in
            if index == 0 {{
                data.headers = data.rows.removeFirst()
            }} else {{
                let dataRow = index - 1
                if data.rows.indices.contains(dataRow) {{
                    data.rows.remove(at: dataRow)
                }}
            }}
        }}
        onChange?()
    }}""", code)

code = re.sub(r'private func deleteColumn\(at index: Int\) \{[\s\S]*?onChange\?\(\)\n    \}', f"""private func deleteColumn(at index: Int) {{
        guard tableData.headers.count > 1 else {{ return }}
        store.mutateTable(id: tableId, actionName: "Delete Column") {{ data in
            if data.headers.indices.contains(index) {{
                data.headers.remove(at: index)
                for r in 0..<data.rows.count {{
                    if data.rows[r].indices.contains(index) {{
                        data.rows[r].remove(at: index)
                    }}
                }}
            }}
        }}
        onChange?()
    }}""", code)

# Fix handleCellTap
code = re.sub(r'    private func handleCellTap\(rowIdx: Int, colIdx: Int, cellKey: String\) \{[\s\S]*?activeEditingCell = cellKey\n    \}', '''    private func handleCellTap(rowIdx: Int, colIdx: Int, cellKey: String) {
        if let active = activeEditingCell, active != cellKey {
            let parts = active.split(separator: ",")
            if parts.count == 2, let r = Int(parts[0]), let c = Int(parts[1]) {
                let activeText = getRawValue(rowIdx: r, colIdx: c)
                if activeText.hasPrefix("=") {
                    let lastChar = activeText.last ?? " "
                    if "+-*/(,= ".contains(lastChar) {
                        let refStr = "\\(TableFormulaEvaluator.columnLetter(for: colIdx))\\(rowIdx + 1)"
                        store.mutateTable(id: tableId, actionName: "Insert Reference") { data in
                            if r == 0 {
                                if data.headers.indices.contains(c) {
                                    data.headers[c] = activeText + refStr
                                }
                            } else {
                                let dRow = r - 1
                                if data.rows.indices.contains(dRow), data.rows[dRow].indices.contains(c) {
                                    data.rows[dRow][c] = activeText + refStr
                                }
                            }
                        }
                    }
                }
            }
        }
        activeEditingCell = cellKey
    }''', code)

# Fix setRawValue directly mutating tableData
code = re.sub(r'tableData\.headers\[colIdx\] = val', 'store.mutateTable(id: tableId) { $0.headers[colIdx] = val }', code)
code = re.sub(r'tableData\.rows\[dataRow\]\[colIdx\] = val', 'store.mutateTable(id: tableId) { $0.rows[dataRow][colIdx] = val }', code)
code = re.sub(r'tableData\.rows\[dataRow\]\.append\(""\)', 'store.mutateTable(id: tableId) { $0.rows[dataRow].append("") }', code)
code = re.sub(r'tableData\.columnNotes\?\[colIdx\] = val', 'store.mutateTable(id: tableId) { $0.columnNotes?[colIdx] = val }', code)
code = re.sub(r'tableData\.rowNotes\?\[rowIdx\] = val', 'store.mutateTable(id: tableId) { $0.rowNotes?[rowIdx] = val }', code)

# Fix resizing mutators
code = re.sub(r'tableData\.columnWidths = Array', 'store.mutateTable(id: tableId) { $0.columnWidths = Array', code)
code = re.sub(r'tableData\.tableWidth = actualTableWidth', '$0.tableWidth = actualTableWidth }', code)

code = re.sub(r'tableData\.columnWidths = cw\n            \n            // Adjust table width to match new sum\n            let newSum = cw\.reduce\(0, \+\) \+ 32\n            tableData\.tableWidth = newSum', 'store.mutateTable(id: tableId) { $0.columnWidths = cw; $0.tableWidth = cw.reduce(0, +) + 32 }', code)

code = re.sub(r'tableData\.tableWidth = max', 'store.mutateTable(id: tableId) { $0.tableWidth = max', code)
code = re.sub(r'tableData\.tableHeight = max', '$0.tableHeight = max', code)
code = re.sub(r'\(baseH \+ val\.translation\.height\)\n                        }', '(baseH + val.translation.height) }', code)

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "w") as f:
    f.write(code)

