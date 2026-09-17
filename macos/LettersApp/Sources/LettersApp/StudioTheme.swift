import SwiftUI

public enum StudioTheme {
    // Studio Workspace Colors (Affinity / Figma Dark & Light Adapting)
    public static let canvasBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
            : NSColor(red: 0.88, green: 0.89, blue: 0.91, alpha: 1.0)
    }))

    public static let panelBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)
            : NSColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
    }))

    public static let surfaceHighlight = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1.0)
            : NSColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1.0)
    }))

    // Authentic Physical Paper Sheet (Crisp bright paper white in all modes like Pages / Affinity)
    public static let paperBackground = Color(red: 1.0, green: 1.0, blue: 1.0)
    public static let paperTextColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    public static let accent = Color.accentColor
    public static let border = Color.primary.opacity(0.12)
    public static let subtleBorder = Color.primary.opacity(0.06)
}
