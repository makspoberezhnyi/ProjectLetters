import re

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "r") as f:
    code = f.read()

pattern = r'StudioDocumentHistoryView\(isPresented: \$showDocumentHistory, store: documentController\)\n                                        \}\n                                    \)'
replacement = r'StudioDocumentHistoryView(isPresented: $showDocumentHistory, store: documentController)'

code = re.sub(pattern, replacement, code)

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "w") as f:
    f.write(code)
