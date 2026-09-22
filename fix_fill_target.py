with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "r") as f:
    code = f.read()

bad_code = """                    let sourceVal = data.cells[sourceR][sourceC].rawValue
                    if sourceVal.hasPrefix("=") {
                        let newVal = TableFormulaEvaluator.extrapolateFormula(sourceVal, rowOffset: rowOffset, colOffset: colOffset)
                        data.cells[r][sourceC].rawValue = newVal
                    } else {
                        data.cells[r][sourceC].rawValue = sourceVal
                    }"""

good_code = """                    let sourceVal = data.rows[sourceR][sourceC]
                    if sourceVal.hasPrefix("=") {
                        let newVal = TableFormulaEvaluator.extrapolateFormula(sourceVal, rowOffset: rowOffset, colOffset: colOffset)
                        data.rows[r][c] = newVal
                    } else {
                        data.rows[r][c] = sourceVal
                    }"""

code = code.replace(bad_code, good_code)

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "w") as f:
    f.write(code)
