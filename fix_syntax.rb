path = "macos/LettersApp/Sources/LettersApp/MainEditorView.swift"
content = File.read(path)

# Fix cover banner removal residue
target1 = /VStack\(spacing: 36\) \{\s+\)\s+\.frame\(width: currentSheetWidth \* zoomScale\)\s+\.padding\(\.bottom, 8\)\s+\.transition\(\.opacity\.combined\(with: \.scale\(scale: 0\.96\)\)\)\s+\}/m
content.sub!(target1, "VStack(spacing: 36) {")

File.write(path, content)
