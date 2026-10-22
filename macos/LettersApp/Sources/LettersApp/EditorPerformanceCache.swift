import Foundation
import AppKit

/// High-performance shared caching layer for Project Letters to eliminate
/// repetitive regex compilations, font descriptor lookups, and heap allocations during live editing.
public final class EditorPerformanceCache: @unchecked Sendable {
    public static let shared = EditorPerformanceCache()

    // MARK: - Pre-Compiled Regular Expressions
    public let canvasSegmentRegex: NSRegularExpression
    public let canvasChunkMarkerRegex: NSRegularExpression
    public let tocHeadingRegex: NSRegularExpression

    // MARK: - Font Resolution Cache (Thread-Safe)
    private let fontLock = NSLock()
    private var fontCache: [String: NSFont] = [:]

    private init() {
        // Pre-compile regular expressions once at launch
        let segmentPattern = #"(?:^|\n)?\[\[(table|image|video|bibliography|toc)(?::([a-zA-Z0-9\-]+))?\]\](?:\n)?"#
        self.canvasSegmentRegex = (try? NSRegularExpression(pattern: segmentPattern, options: [])) ?? NSRegularExpression()

        let markerPattern = #"(?:^|\n)?\[\[(?:table|image|video|bibliography|toc)(?::[a-zA-Z0-9\-]+)?\]\](?:\n)?"#
        self.canvasChunkMarkerRegex = (try? NSRegularExpression(pattern: markerPattern, options: [])) ?? NSRegularExpression()

        let tocPattern = #"^[0-9]+(?:\.[0-9]+)*\.\s+(.+)$"#
        self.tocHeadingRegex = (try? NSRegularExpression(pattern: tocPattern, options: [])) ?? NSRegularExpression()
    }

    public func resolveFont(family: String, size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        let cacheKey = "\(family)_\(size)_\(bold)_\(italic)"
        
        fontLock.lock()
        defer { fontLock.unlock() }

        if let cached = fontCache[cacheKey] {
            return cached
        }

        let resolved = computeFont(family: family, size: size, bold: bold, italic: italic)
        fontCache[cacheKey] = resolved
        return resolved
    }

    private func computeFont(family: String, size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        let lower = family.lowercased()
        let weight: NSFont.Weight = bold ? .bold : .regular

        if lower.contains("sf pro") || lower.contains("modern sans") || lower == "system" {
            let systemFont = NSFont.systemFont(ofSize: size, weight: weight)
            if italic {
                let descriptor = systemFont.fontDescriptor.withSymbolicTraits(.italic)
                return NSFont(descriptor: descriptor, size: size) ?? systemFont
            }
            return systemFont
        }

        if lower.contains("new york") || lower.contains("editorial") {
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            if let nyDesc = base.fontDescriptor.withDesign(.serif) {
                let finalDesc = italic ? nyDesc.withSymbolicTraits(nyDesc.symbolicTraits.union(.italic)) : nyDesc
                if let nyFont = NSFont(descriptor: finalDesc, size: size) {
                    return nyFont
                }
            }
        }

        if lower.contains("sf mono") {
            let monoFont = NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            if italic {
                let descriptor = monoFont.fontDescriptor.withSymbolicTraits(monoFont.fontDescriptor.symbolicTraits.union(.italic))
                return NSFont(descriptor: descriptor, size: size) ?? monoFont
            }
            return monoFont
        }

        var baseName = "Georgia"
        if lower.contains("times") {
            baseName = bold ? (italic ? "TimesNewRomanPS-BoldItalicMT" : "TimesNewRomanPS-BoldMT") : (italic ? "TimesNewRomanPS-ItalicMT" : "TimesNewRomanPSMT")
        } else if lower.contains("helvetica") {
            baseName = bold ? (italic ? "HelveticaNeue-BoldItalic" : "HelveticaNeue-Bold") : (italic ? "HelveticaNeue-Italic" : "HelveticaNeue")
        } else if lower.contains("avenir") {
            baseName = bold ? (italic ? "AvenirNext-BoldItalic" : "AvenirNext-Bold") : (italic ? "AvenirNext-Italic" : "AvenirNext-Regular")
        } else if lower.contains("baskerville") {
            baseName = bold ? (italic ? "Baskerville-BoldItalic" : "Baskerville-Bold") : (italic ? "Baskerville-Italic" : "Baskerville")
        } else if lower.contains("palatino") {
            baseName = bold ? (italic ? "Palatino-BoldItalic" : "Palatino-Bold") : (italic ? "Palatino-Italic" : "Palatino-Roman")
        } else if lower.contains("menlo") {
            baseName = bold ? (italic ? "Menlo-BoldItalic" : "Menlo-Bold") : (italic ? "Menlo-Italic" : "Menlo-Regular")
        } else if lower.contains("courier") {
            baseName = bold ? (italic ? "CourierNewPS-BoldItalicMT" : "CourierNewPS-BoldMT") : (italic ? "CourierNewPS-ItalicMT" : "CourierNewPSMT")
        } else if lower.contains("charter") {
            baseName = bold ? (italic ? "Charter-BoldItalic" : "Charter-Bold") : (italic ? "Charter-Italic" : "Charter-Roman")
        } else {
            baseName = bold ? (italic ? "Georgia-BoldItalic" : "Georgia-Bold") : (italic ? "Georgia-Italic" : "Georgia")
        }

        if let custom = NSFont(name: baseName, size: size) {
            return custom
        }

        let fallback = NSFont(name: family, size: size) ?? NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size)
        var traits: NSFontTraitMask = []
        if bold { traits.insert(.boldFontMask) }
        if italic { traits.insert(.italicFontMask) }
        if !traits.isEmpty {
            return NSFontManager.shared.convert(fallback, toHaveTrait: traits)
        }
        return fallback
    }

    // MARK: - Fast Single-Pass Word Counter (Zero Heap Allocations)
    public static func countWords(in text: String) -> Int {
        var count = 0
        var inWord = false

        for char in text.utf8 {
            // Check for space (32), tab (9), newline (10), carriage return (13)
            let isWhitespace = (char == 32 || char == 9 || char == 10 || char == 13)
            if isWhitespace {
                if inWord {
                    count += 1
                    inWord = false
                }
            } else {
                inWord = true
            }
        }

        if inWord {
            count += 1
        }

        return count
    }
}
