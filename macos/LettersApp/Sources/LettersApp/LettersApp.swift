import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "AppleFontSmoothing": 2,
            "CGFontRenderingMode": 2
        ])
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
        
        window.minSize = NSSize(width: 820, height: 600)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenPrimary]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.title = "Letters"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.delegate = self

        let hostingView = LettersHostingView(rootView: MainEditorView())
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
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            NSApp.activate(ignoringOtherApps: true)
        }
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return confirmProceedIfDirty()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return confirmProceedIfDirty() ? .terminateNow : .terminateCancel
    }

    private func confirmProceedIfDirty() -> Bool {
        guard let controller = LettersDocumentController.active, controller.isDirty else {
            return true
        }
        // Always write shadow recovery bundle before asking
        controller.performAutosave()

        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes made to “\(controller.title)”?"
        alert.informativeText = "Your changes will be lost if you don't save them. (An emergency autosave snapshot has also been backed up.)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn: // Save
            NotificationCenter.default.post(name: .lettersSaveDocument, object: nil)
            return !controller.isDirty
        case .alertSecondButtonReturn: // Cancel
            return false
        default: // Don't Save
            controller.isDirty = false
            return true
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let firstURL = urls.first else { return }
        NotificationCenter.default.post(name: Notification.Name("lettersOpenFileURL"), object: firstURL)
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

// MARK: - Crisp Retina / HiDPI-Aware Hosting View
final class LettersHostingView<Content: View>: NSHostingView<Content> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureLayerScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        configureLayerScale()
    }

    private func configureLayerScale() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        layer?.contentsScale = scale
        layer?.rasterizationScale = scale
        layer?.shouldRasterize = false
        layer?.allowsEdgeAntialiasing = true
        needsDisplay = true
    }
}

