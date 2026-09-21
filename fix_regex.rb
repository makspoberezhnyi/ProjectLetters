path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
lines = File.readlines(path)
lines[99] = '    private static let functionRegex = try! NSRegularExpression(pattern: "(SUM|AVERAGE|AVG|MIN|MAX|COUNT|PRODUCT|IF|CONCAT|CONCATENATE|ABS|ROUND|INT|MEDIAN|STDEV)\\\\s*\\\\(([^)]+)\\\\)", options: [.caseInsensitive])' + "\n"
File.write(path, lines.join)
