import Foundation

let path = "macos/LettersApp/Sources/LettersApp/MainEditorView.swift"
var content = try! String(contentsOfFile: path)

let target = """
        .onAppear {
            runLinter()
        }
"""

let replacement = """
        .onAppear {
            runLinter()
            
            editorController.onSelectAllRequested = {
                let totalLength = documentPageSlices.last.map { $0.range.location + $0.range.length } ?? (rawText as NSString).length
                self.selectionRange = NSRange(location: 0, length: totalLength)
            }
            
            editorController.onImportFile = { url in
                self.importFileNatively(url: url)
            }
        }
"""

content = content.replacingOccurrences(of: target, with: replacement)
try! content.write(toFile: path, atomically: true, encoding: .utf8)
