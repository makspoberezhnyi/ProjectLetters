import AppKit

class MyTextView: NSTextView {
    // Can we override something to make it draw selection?
}
let tv = MyTextView()
print(tv.selectedTextAttributes)
