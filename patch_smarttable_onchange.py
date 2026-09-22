with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "r") as f:
    code = f.read()

search = """                                    onChange: {
                                        showToast("✓ Table updated")
                                    },"""

replace = """                                    onChange: {
                                        documentController.commitSnapshot(actionName: "Edit Table", isMilestone: false)
                                    },"""

code = code.replace(search, replace)

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "w") as f:
    f.write(code)
