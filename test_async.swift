import AppKit

class Coordinator: NSObject, NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        print("Delegate called!")
    }
}

let tv = NSTextView()
let coord = Coordinator()
tv.delegate = coord
tv.string = "Hello world this is a test"
print("Setting selection...")
tv.setSelectedRange(NSRange(location: 0, length: 5))
print("Selection set!")
