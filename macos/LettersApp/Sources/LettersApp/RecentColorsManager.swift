import SwiftUI
import AppKit

@MainActor
public final class RecentColorsManager: ObservableObject {
    public static let shared = RecentColorsManager()

    private let textColorsKey = "Letters_RecentTextColors"
    private let highlightColorsKey = "Letters_RecentHighlightColors"

    @Published public var recentTextColors: [Color] = []
    @Published public var recentHighlightColors: [Color] = []

    private init() {
        self.recentTextColors = loadColors(forKey: textColorsKey)
        self.recentHighlightColors = loadColors(forKey: highlightColorsKey)
    }

    public func addTextColor(_ color: Color) {
        add(color, to: &recentTextColors, key: textColorsKey)
    }

    public func addHighlightColor(_ color: Color) {
        add(color, to: &recentHighlightColors, key: highlightColorsKey)
    }

    private func add(_ color: Color, to list: inout [Color], key: String) {
        let hex = colorToHex(color)
        // Remove duplicate hex
        list.removeAll(where: { colorToHex($0) == hex })
        list.insert(color, at: 0)
        if list.count > 10 {
            list.removeLast()
        }
        saveColors(list, forKey: key)
    }

    private func loadColors(forKey key: String) -> [Color] {
        guard let hexArray = UserDefaults.standard.stringArray(forKey: key) else { return [] }
        return hexArray.compactMap { hexToColor($0) }
    }

    private func saveColors(_ colors: [Color], forKey key: String) {
        let hexArray = colors.map { colorToHex($0) }
        UserDefaults.standard.set(hexArray, forKey: key)
    }

    private func colorToHex(_ color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = Int(round(max(0, min(1, nsColor.redComponent)) * 255))
        let g = Int(round(max(0, min(1, nsColor.greenComponent)) * 255))
        let b = Int(round(max(0, min(1, nsColor.blueComponent)) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func hexToColor(_ hex: String) -> Color? {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if str.hasPrefix("#") {
            str.removeFirst()
        }
        guard str.count == 6, let rgbValue = UInt64(str, radix: 16) else { return nil }
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
