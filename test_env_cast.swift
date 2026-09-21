import SwiftUI
import AppKit

let window = NSWindow()
let view = Text("").environment(\.undoManager, window.undoManager)
