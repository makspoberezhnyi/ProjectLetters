import re

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "r") as f:
    code = f.read()

# Revert all
pattern = r'VStack\(spacing: 0\) \{\n            Group \{\n                Button\(\"\"\) \{ documentController.undo\(\) \}.keyboardShortcut\(\"z\", modifiers: \.command\).hidden\(\)\n                Button\(\"\"\) \{ documentController.redo\(\) \}.keyboardShortcut\(\"Z\", modifiers: \[\.command, \.shift\]\).hidden\(\)\n            \}'
code = re.sub(pattern, 'VStack(spacing: 0) {', code)

# Apply only to the first one
code = code.replace('VStack(spacing: 0) {', '''VStack(spacing: 0) {
            Group {
                Button("") { documentController.undo() }.keyboardShortcut("z", modifiers: .command).hidden()
                Button("") { documentController.redo() }.keyboardShortcut("Z", modifiers: [.command, .shift]).hidden()
            }''', 1)

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "w") as f:
    f.write(code)
