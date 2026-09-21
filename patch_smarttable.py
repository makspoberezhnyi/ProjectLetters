import re

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "r") as f:
    code = f.read()

# 1. Remove DocumentUndoToken and DocumentUndoHelper completely
code = re.sub(r'class DocumentUndoToken: NSObject \{\}[\s\S]*?(?=\Z)', '', code)
code = re.sub(r'@MainActor\npublic class DocumentUndoHelper \{[\s\S]*?(?=class DocumentUndoToken|\Z)', '', code)
code = re.sub(r'public class DocumentUndoHelper \{[\s\S]*?(?=class DocumentUndoToken|\Z)', '', code)

# Clean up trailing newlines
code = code.rstrip() + "\n"

# 2. Change SmartTableView initialization
code = re.sub(r'@Environment\(\\\.undoManager\) var undoManager\n', '', code)
code = re.sub(r'@Binding var tableData: StudioTableData', '@ObservedObject var store: StudioBlockStore\n    var tableId: UUID\n    private var tableData: StudioTableData {\n        store.tables.first(where: { $0.id == tableId }) ?? StudioTableData(headers: [], rows: [])\n    }', code)

code = re.sub(r'tableData: Binding<StudioTableData>,', 'store: StudioBlockStore,\n        tableId: UUID,', code)
code = re.sub(r'self\._tableData = tableData', 'self.store = store\n        self.tableId = tableId', code)

# 3. Fix mutation functions
def replace_mutation(func_name, action_name, logic):
    pattern = r'private func ' + func_name + r'\([^)]*\) \{[\s\S]*?onChange\?\(\)\n    \}'
    replacement = f"""private func {func_name} {{
        store.mutateTable(id: tableId, actionName: "{action_name}") {{ data in
{logic}
        }}
        onChange?()
    }}"""
    # Specifically for deleteRow / deleteColumn which have more nested braces
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
code = re.sub(r'DocumentUndoHelper\.perform\(binding: _tableData, undoManager: undoManager, actionName: "Insert Reference", onChange: onChange\) \{ data in', 'store.mutateTable(id: tableId, actionName: "Insert Reference") { data in', code)

# Fix setRawValue, getRawValue, handleColumnDrag, which currently directly mutate `tableData` which is now read-only!
# We must wrap them in mutateTable WITHOUT an actionName (so it doesn't pollute undo stack)
code = re.sub(r'tableData\.headers\[colIdx\] = val', 'store.mutateTable(id: tableId) { $0.headers[colIdx] = val }', code)
code = re.sub(r'tableData\.rows\[dataRow\]\[colIdx\] = val', 'store.mutateTable(id: tableId) { $0.rows[dataRow][colIdx] = val }', code)
code = re.sub(r'tableData\.rows\[dataRow\]\.append\(""\)', 'store.mutateTable(id: tableId) { $0.rows[dataRow].append("") }', code)

code = re.sub(r'tableData\.columnNotes\?\[colIdx\] = val', 'store.mutateTable(id: tableId) { $0.columnNotes?[colIdx] = val }', code)
code = re.sub(r'tableData\.rowNotes\?\[rowIdx\] = val', 'store.mutateTable(id: tableId) { $0.rowNotes?[rowIdx] = val }', code)

# Fix dragging
code = re.sub(r'tableData\.columnWidths = Array', 'store.mutateTable(id: tableId) { $0.columnWidths = Array', code)
code = re.sub(r'tableData\.tableWidth = actualTableWidth', '$0.tableWidth = actualTableWidth }', code)

code = re.sub(r'tableData\.columnWidths = cw\n            \n            // Adjust table width to match new sum\n            let newSum = cw\.reduce\(0, \+\) \+ 32\n            tableData\.tableWidth = newSum', 'store.mutateTable(id: tableId) { $0.columnWidths = cw; $0.tableWidth = cw.reduce(0, +) + 32 }', code)

code = re.sub(r'tableData\.tableWidth = max', 'store.mutateTable(id: tableId) { $0.tableWidth = max', code)
code = re.sub(r'tableData\.tableHeight = max', '$0.tableHeight = max', code)
code = re.sub(r'\(baseH \+ val\.translation\.height\)\n                        }', '(baseH + val.translation.height) }', code)

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "w") as f:
    f.write(code)

