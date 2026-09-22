with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "r") as f:
    code = f.read()

sidebar_search = """                                    onInsertTable: { table in
                                        documentController.tables.append(table)
                                        let marker = "\\n\\n[[table:\\(table.id.uuidString)]]\\n\\n"
                                        if selectionRange.location <= (documentController.rawText as NSString).length {
                                            let ns = documentController.rawText as NSString
                                            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
                                        } else {
                                            documentController.rawText += marker
                                        }
                                    },"""

sidebar_replace = """                                    onInsertTable: { table in
                                        let marker = "\\n\\n[[table:\\(table.id.uuidString)]]\\n\\n"
                                        if selectionRange.location <= (documentController.rawText as NSString).length {
                                            let ns = documentController.rawText as NSString
                                            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
                                        } else {
                                            documentController.rawText += marker
                                        }
                                        documentController.tables.append(table)
                                        documentController.commitSnapshot(actionName: "Insert Table", isMilestone: true)
                                    },"""

code = code.replace(sidebar_search, sidebar_replace)

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "w") as f:
    f.write(code)
