import re

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "r") as f:
    code = f.read()

code = re.sub(
    r'            tableData.headers = parsed.headers\n            tableData.rows = parsed.rows',
    '''            store.mutateTable(id: tableId, actionName: "Paste Data") { data in
                data.headers = parsed.headers
                data.rows = parsed.rows
            }''',
    code
)

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "w") as f:
    f.write(code)
