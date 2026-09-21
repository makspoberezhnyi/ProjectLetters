import AppKit

class MyTextView: NSTextView {
    var isProgrammatic = false
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting: Bool) {
        isProgrammatic = true
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        isProgrammatic = false
    }
}
