import Foundation
import JavaScriptCore

let sanitized = "10.5 + 20 * (5 - 2)"
if let context = JSContext() {
    context.exceptionHandler = { context, exception in
        // Ignore or handle
    }
    let result = context.evaluateScript(sanitized)
    if result?.isNumber == true {
        print(result!.toNumber()!)
    } else {
        print("Error")
    }
}
