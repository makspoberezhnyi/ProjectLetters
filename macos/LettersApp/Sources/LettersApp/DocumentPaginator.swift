import SwiftUI
import AppKit
import Foundation

public struct DocumentPageSlice: Identifiable, Equatable {
    public var id: Int { pageIndex }
    public let pageIndex: Int
    public let text: String
    public let attributedText: NSAttributedString?
    public let range: NSRange

    public init(pageIndex: Int, text: String, range: NSRange, attributedText: NSAttributedString? = nil) {
        self.pageIndex = pageIndex
        self.text = text
        self.range = range
        self.attributedText = attributedText
    }
}

public struct DocumentPaginator {
    public static func paginate(
        rawText: String,
        richTextData: Data? = nil,
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
        
        let printableHeight = max(100, sheetHeight - margins.top - margins.bottom)
        let printableWidth = max(100, sheetWidth - margins.left - margins.right)

        var attrString: NSMutableAttributedString
        
        if let data = richTextData, let docxAttr = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) {
            attrString = NSMutableAttributedString(attributedString: docxAttr)
        } else {
            if rawText.isEmpty {
                return [DocumentPageSlice(pageIndex: 0, text: "", range: NSRange(location: 0, length: 0))]
            }
            
            let baseFont = EditorPerformanceCache.shared.resolveFont(family: fontFamily, size: fontSize, bold: isBold, italic: isItalic)
            let baseParaStyle = NSMutableParagraphStyle()
            switch alignment {
            case .leading: baseParaStyle.alignment = .left
            case .center: baseParaStyle.alignment = .center
            case .trailing: baseParaStyle.alignment = .right
            }
            baseParaStyle.lineHeightMultiple = lineSpacing
            baseParaStyle.paragraphSpacing = paragraphSpacing

            attrString = NSMutableAttributedString(string: rawText, attributes: [
                .font: baseFont,
                .paragraphStyle: baseParaStyle
            ])
            
            // Basic markdown regexes for bold/italic since we rely on it now
            let fullRange = NSRange(location: 0, length: attrString.length)
            if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*") {
                for m in boldRegex.matches(in: rawText, range: fullRange) {
                    let bFont = EditorPerformanceCache.shared.resolveFont(family: fontFamily, size: fontSize, bold: true, italic: isItalic)
                    attrString.addAttribute(.font, value: bFont, range: m.range)
                }
            }
            if let italicRegex = try? NSRegularExpression(pattern: "\\*(.*?)\\*") {
                for m in italicRegex.matches(in: rawText, range: fullRange) {
                    let iFont = EditorPerformanceCache.shared.resolveFont(family: fontFamily, size: fontSize, bold: isBold, italic: true)
                    attrString.addAttribute(.font, value: iFont, range: m.range)
                }
            }
        }

        var slices: [DocumentPageSlice] = []
        var pageIndex = 0

        let storage = NSTextStorage(attributedString: attrString)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        var hasMoreInThisSection = true
        while hasMoreInThisSection {
            let container = NSTextContainer(containerSize: NSSize(width: printableWidth, height: printableHeight))
            container.widthTracksTextView = false
            container.heightTracksTextView = false
            container.lineFragmentPadding = 4.0
            layoutManager.addTextContainer(container)

            layoutManager.ensureLayout(for: container)
            let glyphRange = layoutManager.glyphRange(for: container)
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            let pageSliceAttrText = attrString.attributedSubstring(from: charRange)
            let pageSliceText = pageSliceAttrText.string

            slices.append(DocumentPageSlice(pageIndex: pageIndex, text: pageSliceText, range: charRange, attributedText: pageSliceAttrText))
            pageIndex += 1

            let totalGlyphs = layoutManager.numberOfGlyphs
            if glyphRange.location + glyphRange.length >= totalGlyphs || glyphRange.length == 0 {
                hasMoreInThisSection = false
            }
        }

        return slices.isEmpty ? [DocumentPageSlice(pageIndex: 0, text: "", range: NSRange(location: 0, length: 0))] : slices
    }
}
