import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = AppCommandCenter.buildMainMenu()

        let contentView = MainEditorView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1380, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 1080, height: 720)
        window.center()
        window.title = "Letters"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        // Ensure the hosting view has a concrete frame before attachment
        hostingView.frame = window.contentRect(forFrameRect: window.frame)
        window.contentView = hostingView
        self.window = window

        bringToFront()
    }

    // Called both on first launch AND every time the app is re-activated (e.g. clicking the dock icon).
    // This guarantees the window appears even when Xcode holds focus during debug launch.
    func applicationWillBecomeActive(_ notification: Notification) {
        bringToFront()
    }

    private func bringToFront() {
        guard let w = window else { return }
        // Forcefully push our app to the front of the window stack.
        // NSRunningApplication.current.activate is the strongest possible activation signal.
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
enum LettersMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
