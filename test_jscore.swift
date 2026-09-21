import Foundation
import JavaScriptCore

let sanitized = "()"
if let context = JSContext() {
    let result = context.evaluateScript(sanitized)
    if result?.isNumber == true {
        print(result!.toNumber()!)
    } else {
        print("Not a number or error")
    }
}
