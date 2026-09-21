import re

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "r") as f:
    code = f.read()

# Fix init
code = re.sub(
    r'public init\(\n        tableData: Binding<StudioTableData>,',
    'public init(\n        store: LettersDocumentController,\n        tableId: UUID,',
    code
)
code = re.sub(
    r'self\._tableData = tableData',
    'self.store = store\n        self.tableId = tableId',
    code
)

# Fix insertRow
code = re.sub(r'    private func insertRow\(at index: Int\) \{[\s\S]*?onChange\?\(\)\n    \}', '''    private func insertRow(at index: Int) {
        store.mutateTable(id: tableId, actionName: "Insert Row") { data in
            let newRow = Array(repeating: "", count: data.headers.count)
            if index == 0 {
                data.rows.insert(data.headers, at: 0)
                data.headers = newRow
            } else {
                data.rows.insert(newRow, at: max(0, min(index - 1, data.rows.count)))
            }
        }
        onChange?()
    }''', code)

# Fix insertColumn
code = re.sub(r'    private func insertColumn\(at index: Int\) \{[\s\S]*?onChange\?\(\)\n    \}', '''    private func insertColumn(at index: Int) {
        store.mutateTable(id: tableId, actionName: "Insert Column") { data in
            let safeIndex = max(0, min(index, data.headers.count))
            data.headers.insert("", at: safeIndex)
            for r in 0..<data.rows.count {
                data.rows[r].insert("", at: safeIndex)
            }
        }
        onChange?()
    }''', code)

# Fix handlePaste
code = re.sub(r'        if let parsed = StudioTableData.fromTSV\(clipboard\) \?\? StudioTableData.fromCSV\(clipboard\) \{[\s\S]*?onChange\?\(\)\n        \}', '''        if let parsed = StudioTableData.fromTSV(clipboard) ?? StudioTableData.fromCSV(clipboard) {
            store.mutateTable(id: tableId, actionName: "Paste Data") { data in
                data.headers = parsed.headers
                data.rows = parsed.rows
            }
            onChange?()
        }''', code)

# Fix set of columnNotes: if tableData.columnNotes == nil { tableData.columnNotes = [:] }
code = re.sub(r'if tableData\.columnNotes == nil \{ tableData\.columnNotes = \[:\] \}', 'store.mutateTable(id: tableId) { if $0.columnNotes == nil { $0.columnNotes = [:] } }', code)

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "w") as f:
    f.write(code)
