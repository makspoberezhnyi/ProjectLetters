import SwiftUI

public enum StudioTheme {
    // Studio Workspace Colors (Affinity / Figma Dark & Light Adapting)
    public static let canvasBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
            : NSColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1.0)
    }))

    public static let panelBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)
            : NSColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
    }))

    public static let surfaceHighlight = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.20, green: 0.20, blue: 0.23, alpha: 1.0)
            : NSColor(red: 0.89, green: 0.90, blue: 0.92, alpha: 1.0)
    }))

    public static let paperBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0)
            : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    }))

    public static let accent = Color.accentColor
    public static let border = Color.primary.opacity(0.10)
    public static let subtleBorder = Color.primary.opacity(0.06)
}
