with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "r") as f:
    code = f.read()

bad_check = "if parentNode.bundle.rawText == newBundle.rawText && parentNode.bundle.tables.count == newBundle.tables.count {"
good_check = "if parentNode.bundle.rawText == newBundle.rawText && parentNode.bundle.tables == newBundle.tables {"
code = code.replace(bad_check, good_check)

debounce_raw = """        $rawText
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.commitSnapshot(actionName: "Typing", isMilestone: false)
            }
            .store(in: &cancellables)"""

debounce_tables = """        $tables
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.commitSnapshot(actionName: "Table Edit", isMilestone: false)
            }
            .store(in: &cancellables)"""

if debounce_tables not in code:
    code = code.replace(debounce_raw, debounce_raw + "\n\n" + debounce_tables)

# Also fix the Add Table so it modifies rawText FIRST then adds table, or just explicitly commits.
# Wait, let's fix toolbar Table Insert.
add_table_search = """            documentController.tables.append(newTable)
            let marker = "\\n\\n[[table:\\(newTable.id.uuidString)]]\\n\\n"
            if selectionRange.location <= (documentController.rawText as NSString).length {
                let ns = documentController.rawText as NSString
                documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
            } else {
                documentController.rawText += marker
            }"""

add_table_replace = """            let marker = "\\n\\n[[table:\\(newTable.id.uuidString)]]\\n\\n"
            if selectionRange.location <= (documentController.rawText as NSString).length {
                let ns = documentController.rawText as NSString
                documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
            } else {
                documentController.rawText += marker
            }
            // Append table AFTER modifying rawText so they are part of the same frame
            documentController.tables.append(newTable)
            documentController.commitSnapshot(actionName: "Insert Table", isMilestone: true)"""

code = code.replace(add_table_search, add_table_replace)

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "w") as f:
    f.write(code)
