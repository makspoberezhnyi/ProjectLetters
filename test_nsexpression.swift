import Foundation
let expr = "()"
let mathExpr = NSExpression(format: expr)
print(mathExpr.expressionValue(with: nil, context: nil))
