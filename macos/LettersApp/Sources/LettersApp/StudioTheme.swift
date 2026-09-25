import SwiftUI
import AppKit

public enum StudioTheme {
    public static let canvasBackground = Color(NSColor.underPageBackgroundColor)
    public static let islandBackground = Color(NSColor.controlBackgroundColor)
    public static let panelBackground = Color(NSColor.windowBackgroundColor)
    public static let surfaceHighlight = Color(NSColor.selectedControlColor)

    public static let paperBackground = Color(NSColor.textBackgroundColor)
    public static let paperTextColor = Color(NSColor.textColor)

    public static let luminousAmber = Color.orange
    public static let luminousCyan = Color.cyan
    public static let luminousPurple = Color.purple
    public static let luminousEmerald = Color.green
    public static let luminousRuby = Color.red
    public static let luminousBlue = Color.blue

    public static let accent = Color.accentColor
    public static let border = Color(NSColor.separatorColor)
    public static let subtleBorder = Color(NSColor.gridColor)
    public static let hoverHighlight = Color(NSColor.unemphasizedSelectedTextBackgroundColor)
    public static let activeHighlight = Color.accentColor.opacity(0.12)

    public static let paperShadowColor = Color.black.opacity(0.15)
    public static let hudShadowColor = Color.black.opacity(0.15)
    public static let ambientGlowColor = Color.accentColor.opacity(0.06)
}
