import Foundation
import JavaScriptCore
let context = JSContext()!
let result = context.evaluateScript("10 / 0")
if result?.isNumber == true {
    let num = result!.toNumber()!
    if num.doubleValue.isInfinite {
        print("Infinity")
    } else {
        print(num)
    }
}
