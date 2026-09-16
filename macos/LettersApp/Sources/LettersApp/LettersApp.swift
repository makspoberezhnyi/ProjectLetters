import SwiftUI
import LettersKit

@main
struct LettersApp: App {
    var body: some Scene {
        WindowGroup {
            MainEditorView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    // New window
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
