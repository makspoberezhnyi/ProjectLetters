import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = AppCommandCenter.buildMainMenu()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1380, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        let targetScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let screenFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        window.setFrameOrigin(NSPoint(
            x: screenFrame.origin.x + (screenFrame.width - 1380) / 2,
            y: screenFrame.origin.y + (screenFrame.height - 900) / 2
        ))
        
        window.minSize = NSSize(width: 1080, height: 720)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenPrimary]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.title = "Letters"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true

        let hostingView = NSHostingView(rootView: MainEditorView())
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = window.contentRect(forFrameRect: window.frame)
        window.contentView = hostingView
        self.window = window

        bringToFront()
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        bringToFront()
    }

    private func bringToFront() {
        guard let w = window else { return }
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
}

@MainActor private var sharedDelegate: AppDelegate?

@main
@MainActor
enum LettersMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        sharedDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}
