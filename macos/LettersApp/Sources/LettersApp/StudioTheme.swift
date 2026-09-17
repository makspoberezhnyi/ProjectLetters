import SwiftUI
import AppKit

public enum StudioTheme {
    // Studio Workspace Colors (Affinity / Pages / Figma Dark & Light Adapting)
    public static let canvasBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
            : NSColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1.0)
    }))

    public static let panelBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 0.95)
            : NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 0.95)
    }))

    public static let surfaceHighlight = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.22, green: 0.22, blue: 0.26, alpha: 1.0)
            : NSColor(red: 0.92, green: 0.93, blue: 0.95, alpha: 1.0)
    }))

    // Authentic Physical Paper Sheet (Crisp bright paper white in all modes)
    public static let paperBackground = Color(red: 1.0, green: 1.0, blue: 1.0)
    public static let paperTextColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    public static let accent = Color.accentColor
    public static let border = Color.primary.opacity(0.10)
    public static let subtleBorder = Color.primary.opacity(0.05)
    public static let hoverHighlight = Color.primary.opacity(0.07)
    public static let activeHighlight = Color.accentColor.opacity(0.14)

    // Elevation & Depth Shadows
    public static let paperShadowColor = Color.black.opacity(0.16)
    public static let hudShadowColor = Color.black.opacity(0.18)
}
