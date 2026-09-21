import AppKit

let tv1 = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
tv1.string = "Hello 1"
tv1.setSelectedRange(NSRange(location: 0, length: 7))

let tv2 = NSTextView(frame: NSRect(x: 0, y: 100, width: 100, height: 100))
tv2.string = "Hello 2"
tv2.setSelectedRange(NSRange(location: 0, length: 7))

print("tv1 selected range: \(tv1.selectedRange())")
print("tv2 selected range: \(tv2.selectedRange())")
