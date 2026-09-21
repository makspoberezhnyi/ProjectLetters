import AppKit

class MyTextView: NSTextView {
    override func selectAll(_ sender: Any?) {
        print("selectAll called!")
    }
}

let tv = MyTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
tv.string = "Hello"
NSApplication.shared.sendAction(#selector(NSText.selectAll(_:)), to: tv, from: nil)
