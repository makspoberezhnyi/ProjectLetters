import SwiftUI
import AppKit
import Foundation

public struct DocumentPageSlice: Identifiable, Equatable {
    public var id: Int { pageIndex }
    public let pageIndex: Int
    public let text: String
    public let range: NSRange

    public init(pageIndex: Int, text: String, range: NSRange) {
        self.pageIndex = pageIndex
        self.text = text
        self.range = range
    }
}

public struct DocumentPaginator {
    public static func paginate(
        rawText: String,
        sheetHeight: CGFloat,
        sheetWidth: CGFloat,
        margins: PageMargins,
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        isBold: Bool = false,
        isItalic: Bool = false,
        lineSpacing: CGFloat = 1.15,
        paragraphSpacing: CGFloat = 12.0,
        alignment: TextAlignment = .leading
    ) -> [DocumentPageSlice] {
        if rawText.isEmpty {
            return [DocumentPageSlice(pageIndex: 0, text: "", range: NSRange(location: 0, length: 0))]
        }

        let printableHeight = max(100, sheetHeight - margins.top - margins.bottom)
        let printableWidth = max(100, sheetWidth - margins.left - margins.right)

        // Split by explicit page breaks first
        let sections = rawText.components(separatedBy: "---pagebreak---")
        var slices: [DocumentPageSlice] = []
        var pageIndex = 0
        var globalCharOffset = 0

        for (secIdx, section) in sections.enumerated() {
            let secLength = (section as NSString).length

            if section.isEmpty && secIdx > 0 {
                slices.append(DocumentPageSlice(pageIndex: pageIndex, text: "", range: NSRange(location: globalCharOffset, length: 0)))
                pageIndex += 1
                globalCharOffset += 15 // "---pagebreak---".count
                continue
            }

            // Create AttributedString with the exact active typography
            let baseFont = EditorPerformanceCache.shared.resolveFont(family: fontFamily, size: fontSize, bold: isBold, italic: isItalic)
            let baseParaStyle = NSMutableParagraphStyle()
            switch alignment {
            case .leading: baseParaStyle.alignment = .left
            case .center: baseParaStyle.alignment = .center
            case .trailing: baseParaStyle.alignment = .right
            }
            baseParaStyle.lineHeightMultiple = lineSpacing
            baseParaStyle.paragraphSpacing = paragraphSpacing

            let attrString = NSMutableAttributedString(string: section, attributes: [
                .font: baseFont,
                .paragraphStyle: baseParaStyle
            ])

            // Apply Heading formatting matching applyTypographyStyling
            let fullSectionRange = NSRange(location: 0, length: secLength)
            if let h1 = try? NSRegularExpression(pattern: "^#\\s+.*$", options: [.anchorsMatchLines]) {
                let h1Font = EditorPerformanceCache.shared.resolveFont(family: fontFamily, size: fontSize * 1.5, bold: true, italic: false)
                let h1Style = baseParaStyle.mutableCopy() as! NSMutableParagraphStyle
                h1Style.paragraphSpacing = max(paragraphSpacing, 10)
                for m in h1.matches(in: section, options: [], range: fullSectionRange) {
                    attrString.addAttributes([.font: h1Font, .paragraphStyle: h1Style], range: m.range)
                }
            }
            if let h2 = try? NSRegularExpression(pattern: "^##\\s+.*$", options: [.anchorsMatchLines]) {
                let h2Font = EditorPerformanceCache.shared.resolveFont(family: fontFamily, size: fontSize * 1.3, bold: true, italic: false)
                let h2Style = baseParaStyle.mutableCopy() as! NSMutableParagraphStyle
                h2Style.paragraphSpacing = max(paragraphSpacing, 8)
                for m in h2.matches(in: section, options: [], range: fullSectionRange) {
                    attrString.addAttributes([.font: h2Font, .paragraphStyle: h2Style], range: m.range)
                }
            }
            if let h3 = try? NSRegularExpression(pattern: "^###\\s+.*$", options: [.anchorsMatchLines]) {
                let h3Font = EditorPerformanceCache.shared.resolveFont(family: fontFamily, size: fontSize * 1.15, bold: true, italic: false)
                for m in h3.matches(in: section, options: [], range: fullSectionRange) {
                    attrString.addAttribute(.font, value: h3Font, range: m.range)
                }
            }

            // Exact layout computation using Apple NSLayoutManager
            let storage = NSTextStorage(attributedString: attrString)
            let layoutManager = NSLayoutManager()
            storage.addLayoutManager(layoutManager)

            var hasMoreInThisSection = true
            while hasMoreInThisSection {
                let container = NSTextContainer(containerSize: NSSize(width: printableWidth, height: printableHeight))
                container.widthTracksTextView = false
                container.heightTracksTextView = false
                container.lineFragmentPadding = 0
                layoutManager.addTextContainer(container)

                layoutManager.ensureLayout(for: container)
                let glyphRange = layoutManager.glyphRange(for: container)
                let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

                let pageSliceText = (section as NSString).substring(with: charRange)
                let globalRange = NSRange(location: globalCharOffset + charRange.location, length: charRange.length)

                slices.append(DocumentPageSlice(pageIndex: pageIndex, text: pageSliceText, range: globalRange))
                pageIndex += 1

                let totalGlyphs = layoutManager.numberOfGlyphs
                if glyphRange.location + glyphRange.length >= totalGlyphs || glyphRange.length == 0 {
                    hasMoreInThisSection = false
                }
            }

            globalCharOffset += secLength + 15
        }

        return slices.isEmpty ? [DocumentPageSlice(pageIndex: 0, text: "", range: NSRange(location: 0, length: 0))] : slices
    }
}
