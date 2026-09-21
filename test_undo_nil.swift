import SwiftUI
import AppKit

let contentView = Text("Hello")
let hostingView = NSHostingView(rootView: contentView)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = hostingView

// Let's see if we can get the window undo manager
let um = window.undoManager
if um != nil {
    print("NSWindow has an UndoManager")
} else {
    print("No UndoManager")
}
