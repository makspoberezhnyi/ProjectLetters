import SwiftUI
import AppKit

public enum StudioTheme {
    // Studio Workspace Colors (Deep OLED Space-Black & Crisp Light Adapting)
    public static let canvasBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.045, green: 0.048, blue: 0.055, alpha: 1.0)
            : NSColor(red: 0.92, green: 0.93, blue: 0.95, alpha: 1.0)
    }))

    public static let islandBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.08, green: 0.085, blue: 0.10, alpha: 0.85)
            : NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 0.88)
    }))

    public static let panelBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.11, green: 0.115, blue: 0.13, alpha: 0.95)
            : NSColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 0.95)
    }))

    public static let surfaceHighlight = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name.rawValue.contains("Dark")
            ? NSColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1.0)
            : NSColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1.0)
    }))

    // Authentic Physical Paper Sheet (Crisp bright paper white in all modes)
    public static let paperBackground = Color(red: 1.0, green: 1.0, blue: 1.0)
    public static let paperTextColor = Color(red: 0.08, green: 0.08, blue: 0.10)

    // Luminous Color Tokens (Apple Pro Dark Palette)
    public static let luminousAmber = Color(red: 0.98, green: 0.65, blue: 0.22)
    public static let luminousCyan = Color(red: 0.28, green: 0.78, blue: 0.96)
    public static let luminousPurple = Color(red: 0.75, green: 0.45, blue: 0.98)
    public static let luminousEmerald = Color(red: 0.25, green: 0.84, blue: 0.56)
    public static let luminousRuby = Color(red: 0.98, green: 0.35, blue: 0.45)
    public static let luminousBlue = Color(red: 0.24, green: 0.55, blue: 0.98)

    public static let accent = Color.accentColor
    public static let border = Color.primary.opacity(0.08)
    public static let subtleBorder = Color.primary.opacity(0.04)
    public static let hoverHighlight = Color.primary.opacity(0.06)
    public static let activeHighlight = Color.accentColor.opacity(0.12)

    // Elevation & Depth Shadows
    public static let paperShadowColor = Color.black.opacity(0.24)
    public static let hudShadowColor = Color.black.opacity(0.22)
    public static let ambientGlowColor = Color(red: 0.25, green: 0.45, blue: 0.95).opacity(0.06)
}
