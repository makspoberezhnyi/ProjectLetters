path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# 1. Expand function Regex
old_regex = 'private static let functionRegex = try! NSRegularExpression(pattern: "(SUM|AVERAGE|AVG|MIN|MAX|COUNT|PRODUCT)\\\\s*\\\\(([^)]+)\\\\)", options: [.caseInsensitive])'
new_regex = 'private static let functionRegex = try! NSRegularExpression(pattern: "(SUM|AVERAGE|AVG|MIN|MAX|COUNT|PRODUCT|IF|CONCAT|CONCATENATE|ABS|ROUND|INT|MEDIAN|STDEV)\\\\s*\\\\(([^)]+)\\\\)", options: [.caseInsensitive])'
content.sub!(old_regex, new_regex)

# 2. Expand evaluate function cases
old_eval = <<-SWIFT
                let resultVal: Double
                switch funcName {
                case "SUM":
                    resultVal = numbers.reduce(0.0, +)
                case "AVERAGE", "AVG":
                    resultVal = numbers.isEmpty ? 0.0 : numbers.reduce(0.0, +) / Double(numbers.count)
                case "MIN":
                    resultVal = numbers.min() ?? 0.0
                case "MAX":
                    resultVal = numbers.max() ?? 0.0
                case "COUNT":
                    resultVal = Double(numbers.count)
                case "PRODUCT":
                    resultVal = numbers.isEmpty ? 0.0 : numbers.reduce(1.0, *)
                default:
                    resultVal = 0.0
                }

                expr = nsExpr.replacingCharacters(in: match.range, with: formatNumber(resultVal))
SWIFT

new_eval = <<-SWIFT
                var resultVal: Double = 0.0
                var resultStr: String? = nil
                
                switch funcName {
                case "SUM":
                    resultVal = numbers.reduce(0.0, +)
                case "AVERAGE", "AVG":
                    resultVal = numbers.isEmpty ? 0.0 : numbers.reduce(0.0, +) / Double(numbers.count)
                case "MIN":
                    resultVal = numbers.min() ?? 0.0
                case "MAX":
                    resultVal = numbers.max() ?? 0.0
                case "COUNT":
                    resultVal = Double(numbers.count)
                case "PRODUCT":
                    resultVal = numbers.isEmpty ? 0.0 : numbers.reduce(1.0, *)
                case "ABS":
                    resultVal = numbers.first.map { abs($0) } ?? 0.0
                case "ROUND":
                    let val = numbers.first ?? 0.0
                    let places = numbers.dropFirst().first ?? 0.0
                    let multiplier = pow(10.0, places)
                    resultVal = round(val * multiplier) / multiplier
                case "INT":
                    resultVal = numbers.first.map { floor($0) } ?? 0.0
                case "MEDIAN":
                    let sorted = numbers.sorted()
                    if sorted.isEmpty { resultVal = 0.0 }
                    else if sorted.count % 2 == 1 { resultVal = sorted[sorted.count / 2] }
                    else { resultVal = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0 }
                case "IF":
                    // basic IF parser: IF(A1, 1, 0)
                    let cond = numbers.first ?? 0.0
                    let trueVal = numbers.dropFirst().first ?? 0.0
                    let falseVal = numbers.dropFirst(2).first ?? 0.0
                    resultVal = cond != 0.0 ? trueVal : falseVal
                case "CONCAT", "CONCATENATE":
                    // special string handler
                    resultStr = argTokens.map { token in
                        let t = token.trimmingCharacters(in: .whitespaces)
                        if t.hasPrefix("\\"") && t.hasSuffix("\\"") {
                            return String(t.dropFirst().dropLast())
                        } else if let coord = parseCellReference(t), rows.indices.contains(coord.row), rows[coord.row].indices.contains(coord.col) {
                            return rows[coord.row][coord.col]
                        }
                        return t
                    }.joined()
                default:
                    resultVal = 0.0
                }

                let finalReplacement = resultStr ?? formatNumber(resultVal)
                expr = nsExpr.replacingCharacters(in: match.range, with: finalReplacement)
SWIFT

content.sub!(old_eval, new_eval)

File.write(path, content)
