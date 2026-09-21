path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)
content.gsub!(/\.overlay\n\(/, ".overlay(")
content.gsub!(/\.background\n\(/, ".background(")
File.write(path, content)
