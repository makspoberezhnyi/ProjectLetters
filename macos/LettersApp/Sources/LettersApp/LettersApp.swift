import SwiftUI
import AppKit
import LettersKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct LettersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Letters") {
            MainEditorView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    // New document
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Letters") {
                Button("Command Palette...") {
                    // Trigger Cmd+K
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("Export as DOCX...") {
                    // Export
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}
