path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# In StudioTableData:
eval_regex = /public func evaluatedCell\(row: Int, col: Int\) -> String \{.*?return raw\s+\}/m

new_eval = <<-SWIFT
public func evaluatedCell(row: Int, col: Int) -> String {
        let grid = [headers] + rows
        guard grid.indices.contains(row), grid[row].indices.contains(col) else { return "" }
        let raw = grid[row][col]
        if raw.hasPrefix("=") {
            var visited: Set<String> = []
            return TableFormulaEvaluator.evaluate(formula: raw, rows: grid, visited: &visited)
        }
        return raw
    }
SWIFT

content.sub!(eval_regex, new_eval)

# evaluatedRows() in StudioTableData should also be updated
eval_rows_regex = /public func evaluatedRows\(\) -> \[\[String\]\] \{\s+return \(0\.\.<rows\.count\)\.map \{ r in\s+\(0\.\.<headers\.count\)\.map \{ c in\s+evaluatedCell\(row: r, col: c\)\s+\}\s+\}\s+\}/m

new_eval_rows = <<-SWIFT
public func evaluatedRows() -> [[String]] {
        let grid = [headers] + rows
        return (0..<grid.count).map { r in
            (0..<headers.count).map { c in
                evaluatedCell(row: r, col: c)
            }
        }
    }
SWIFT

content.sub!(eval_rows_regex, new_eval_rows)
File.write(path, content)
