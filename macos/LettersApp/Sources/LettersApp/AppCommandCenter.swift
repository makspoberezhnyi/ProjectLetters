import AppKit
import SwiftUI

public extension Notification.Name {
    static let lettersNewDocument = Notification.Name("lettersNewDocument")
    static let lettersOpenDocument = Notification.Name("lettersOpenDocument")
    static let lettersImportWordOrPDF = Notification.Name("lettersImportWordOrPDF")
    static let lettersSaveDocument = Notification.Name("lettersSaveDocument")
    static let lettersExportDocx = Notification.Name("lettersExportDocx")
    static let lettersExportPDF = Notification.Name("lettersExportPDF")
    static let lettersPrintDocument = Notification.Name("lettersPrintDocument")
    static let lettersOpenSettings = Notification.Name("lettersOpenSettings")

    static let lettersToggleFindReplace = Notification.Name("lettersToggleFindReplace")
    static let lettersToggleBold = Notification.Name("lettersToggleBold")
    static let lettersToggleItalic = Notification.Name("lettersToggleItalic")
    static let lettersToggleUnderline = Notification.Name("lettersToggleUnderline")
    static let lettersAlignLeft = Notification.Name("lettersAlignLeft")
    static let lettersAlignCenter = Notification.Name("lettersAlignCenter")
    static let lettersAlignRight = Notification.Name("lettersAlignRight")

    static let lettersInsertTable = Notification.Name("lettersInsertTable")
    static let lettersInsertImage = Notification.Name("lettersInsertImage")
    static let lettersInsertVideo = Notification.Name("lettersInsertVideo")
    static let lettersInsertCitation = Notification.Name("lettersInsertCitation")
    static let lettersInsertPageBreak = Notification.Name("lettersInsertPageBreak")

    static let lettersZoomIn = Notification.Name("lettersZoomIn")
    static let lettersZoomOut = Notification.Name("lettersZoomOut")
    static let lettersZoomReset = Notification.Name("lettersZoomReset")
    static let lettersToggleOutline = Notification.Name("lettersToggleOutline")
    static let lettersToggleAIDrawer = Notification.Name("lettersToggleAIDrawer")
    static let lettersToggleCommandPalette = Notification.Name("lettersToggleCommandPalette")
}

@MainActor
public final class AppCommandCenter: NSObject, NSMenuItemValidation {
    public static let shared = AppCommandCenter()

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }

    public static func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "MainMenu")

        // 1. Letters App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Letters")
        appMenu.addItem(withTitle: "About Letters", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(handleMenuAction(_:)), keyEquivalent: ",")
        settingsItem.target = AppCommandCenter.shared
        settingsItem.representedObject = Notification.Name.lettersOpenSettings
        appMenu.addItem(settingsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Letters", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Letters", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        
        addMenuItem(to: fileMenu, title: "New Document", notification: .lettersNewDocument, keyEquivalent: "n")
        addMenuItem(to: fileMenu, title: "Open...", notification: .lettersOpenDocument, keyEquivalent: "o")
        addMenuItem(to: fileMenu, title: "Import Word or PDF...", notification: .lettersImportWordOrPDF, keyEquivalent: "i", modifiers: [.command, .shift])
        fileMenu.addItem(NSMenuItem.separator())
        addMenuItem(to: fileMenu, title: "Save .letters", notification: .lettersSaveDocument, keyEquivalent: "s")
        
        let exportItem = NSMenuItem(title: "Export", action: nil, keyEquivalent: "")
        let exportMenu = NSMenu(title: "Export")
        addMenuItem(to: exportMenu, title: "Export as Word Document (.docx)...", notification: .lettersExportDocx, keyEquivalent: "S", modifiers: [.command, .shift])
        addMenuItem(to: exportMenu, title: "Export as Vector PDF (.pdf)...", notification: .lettersExportPDF, keyEquivalent: "e", modifiers: [.command, .shift])
        exportItem.submenu = exportMenu
        fileMenu.addItem(exportItem)
        
        fileMenu.addItem(NSMenuItem.separator())
        addMenuItem(to: fileMenu, title: "Print...", notification: .lettersPrintDocument, keyEquivalent: "p")
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        addMenuItem(to: editMenu, title: "Find & Replace...", notification: .lettersToggleFindReplace, keyEquivalent: "f")
        addMenuItem(to: editMenu, title: "Command Palette...", notification: .lettersToggleCommandPalette, keyEquivalent: "k")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. Format Menu
        let formatMenuItem = NSMenuItem()
        let formatMenu = NSMenu(title: "Format")
        addMenuItem(to: formatMenu, title: "Bold", notification: .lettersToggleBold, keyEquivalent: "b")
        addMenuItem(to: formatMenu, title: "Italic", notification: .lettersToggleItalic, keyEquivalent: "i")
        addMenuItem(to: formatMenu, title: "Underline", notification: .lettersToggleUnderline, keyEquivalent: "u")
        formatMenu.addItem(NSMenuItem.separator())
        addMenuItem(to: formatMenu, title: "Align Left", notification: .lettersAlignLeft, keyEquivalent: "{")
        addMenuItem(to: formatMenu, title: "Align Center", notification: .lettersAlignCenter, keyEquivalent: "|")
        addMenuItem(to: formatMenu, title: "Align Right", notification: .lettersAlignRight, keyEquivalent: "}")
        formatMenuItem.submenu = formatMenu
        mainMenu.addItem(formatMenuItem)

        // 5. Insert Menu
        let insertMenuItem = NSMenuItem()
        let insertMenu = NSMenu(title: "Insert")
        addMenuItem(to: insertMenu, title: "Smart Calculation Table", notification: .lettersInsertTable, keyEquivalent: "t")
        addMenuItem(to: insertMenu, title: "Figure / Image...", notification: .lettersInsertImage, keyEquivalent: "")
        addMenuItem(to: insertMenu, title: "Video Embed Card...", notification: .lettersInsertVideo, keyEquivalent: "")
        addMenuItem(to: insertMenu, title: "Linked Bibliographic Citation...", notification: .lettersInsertCitation, keyEquivalent: "c", modifiers: [.command, .option])
        insertMenu.addItem(NSMenuItem.separator())
        addMenuItem(to: insertMenu, title: "Page Break", notification: .lettersInsertPageBreak, keyEquivalent: "\r")
        insertMenuItem.submenu = insertMenu
        mainMenu.addItem(insertMenuItem)

        // 6. View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        addMenuItem(to: viewMenu, title: "Zoom In", notification: .lettersZoomIn, keyEquivalent: "=")
        addMenuItem(to: viewMenu, title: "Zoom Out", notification: .lettersZoomOut, keyEquivalent: "-")
        addMenuItem(to: viewMenu, title: "Actual Size (100%)", notification: .lettersZoomReset, keyEquivalent: "0")
        viewMenu.addItem(NSMenuItem.separator())
        addMenuItem(to: viewMenu, title: "Toggle Outline & Pages", notification: .lettersToggleOutline, keyEquivalent: "1", modifiers: [.command, .option])
        addMenuItem(to: viewMenu, title: "Toggle AI Copilot Companion", notification: .lettersToggleAIDrawer, keyEquivalent: "j")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 7. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // 8. Help Menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "Letters Studio Documentation", action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        return mainMenu
    }

    private static func addMenuItem(
        to menu: NSMenu,
        title: String,
        notification: Notification.Name,
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) {
        let item = NSMenuItem(title: title, action: #selector(handleMenuAction(_:)), keyEquivalent: keyEquivalent)
        item.target = AppCommandCenter.shared
        item.representedObject = notification
        item.keyEquivalentModifierMask = modifiers
        menu.addItem(item)
    }

    @objc private func handleMenuAction(_ sender: NSMenuItem) {
        if let notifName = sender.representedObject as? Notification.Name {
            NotificationCenter.default.post(name: notifName, object: nil)
        }
    }
}
