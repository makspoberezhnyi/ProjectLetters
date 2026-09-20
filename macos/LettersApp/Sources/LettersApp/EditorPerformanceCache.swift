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
        if family.contains("SF Pro") || family.contains("Modern Sans") || family.contains("System") {
            let weight: NSFont.Weight = bold ? .bold : .regular
            let systemFont = NSFont.systemFont(ofSize: size, weight: weight)
            if italic {
                let descriptor = systemFont.fontDescriptor.withSymbolicTraits(.italic)
                return NSFont(descriptor: descriptor, size: size) ?? systemFont
            }
            return systemFont
        }

        var baseName = "Georgia"
        if family.contains("Times") {
            baseName = bold ? (italic ? "TimesNewRomanPS-BoldItalicMT" : "TimesNewRomanPS-BoldMT") : (italic ? "TimesNewRomanPS-ItalicMT" : "TimesNewRomanPSMT")
        } else if family.contains("Helvetica") {
            baseName = bold ? (italic ? "HelveticaNeue-BoldItalic" : "HelveticaNeue-Bold") : (italic ? "HelveticaNeue-Italic" : "HelveticaNeue")
        } else if family.contains("Menlo") {
            baseName = bold ? (italic ? "Menlo-BoldItalic" : "Menlo-Bold") : (italic ? "Menlo-Italic" : "Menlo-Regular")
        } else if family.contains("Courier") {
            baseName = bold ? (italic ? "Courier-BoldOblique" : "Courier-Bold") : (italic ? "Courier-Oblique" : "Courier")
        } else if family.contains("Charter") {
            baseName = bold ? (italic ? "Charter-BoldItalic" : "Charter-Bold") : (italic ? "Charter-Italic" : "Charter-Roman")
        } else {
            baseName = bold ? (italic ? "Georgia-BoldItalic" : "Georgia-Bold") : (italic ? "Georgia-Italic" : "Georgia")
        }

        if let custom = NSFont(name: baseName, size: size) {
            return custom
        }

        let fallback = NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size)
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
