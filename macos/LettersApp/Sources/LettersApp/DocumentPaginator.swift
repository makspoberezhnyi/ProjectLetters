import SwiftUI
import AppKit
import Foundation
#if canImport(LettersKit)
import LettersKit
#endif

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
        var currentIndex = 0
        let nsString = attrString.string as NSString
        let fullLength = nsString.length

        while currentIndex < fullLength {
            let remainingText = attrString.attributedSubstring(from: NSRange(location: currentIndex, length: fullLength - currentIndex))
            
            var tempStorage: NSTextContentStorage
            var lm: NSTextLayoutManager
            
            if #available(macOS 12.0, *) {
                tempStorage = NSTextContentStorage()
                tempStorage.attributedString = remainingText
                lm = NSTextLayoutManager()
                tempStorage.addTextLayoutManager(lm)
                
                let container = NSTextContainer(size: NSSize(width: printableWidth, height: printableHeight))
                container.lineFragmentPadding = 0 // Match Editor settings
                lm.textContainer = container
                
                lm.ensureLayout(for: lm.documentRange)
                
                var lastVisibleLoc = 0
                lm.enumerateTextLayoutFragments(from: lm.documentRange.location, options: [.ensuresLayout]) { fragment in
                    if fragment.layoutFragmentFrame.maxY <= printableHeight {
                        let range = fragment.rangeInElement
                        let startOffset = tempStorage.offset(from: tempStorage.documentRange.location, to: range.location)
                        let length = tempStorage.offset(from: range.location, to: range.endLocation)
                        lastVisibleLoc = max(lastVisibleLoc, startOffset + length)
                        return true
                    } else {
                        return false
                    }
                }
                
                // Safety fallback to prevent infinite loops if height is too small to fit even one line
                if lastVisibleLoc == 0 {
                    lastVisibleLoc = remainingText.length > 0 ? 1 : 0
                }
                
                let sliceRange = NSRange(location: currentIndex, length: lastVisibleLoc)
                let pageSliceAttrText = attrString.attributedSubstring(from: sliceRange)
                slices.append(DocumentPageSlice(pageIndex: pageIndex, text: pageSliceAttrText.string, range: sliceRange, attributedText: pageSliceAttrText))
                
                currentIndex += lastVisibleLoc
                pageIndex += 1
            } else {
                // Legacy TextKit 1 fallback for older macOS
                let storage = NSTextStorage(attributedString: remainingText)
                let layoutManager = NSLayoutManager()
                storage.addLayoutManager(layoutManager)
                
                let container = NSTextContainer(containerSize: NSSize(width: printableWidth, height: printableHeight))
                container.lineFragmentPadding = 0
                layoutManager.addTextContainer(container)
                
                layoutManager.ensureLayout(for: container)
                let glyphRange = layoutManager.glyphRange(for: container)
                let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                
                let sliceRange = NSRange(location: currentIndex, length: charRange.length)
                let pageSliceAttrText = attrString.attributedSubstring(from: sliceRange)
                slices.append(DocumentPageSlice(pageIndex: pageIndex, text: pageSliceAttrText.string, range: sliceRange, attributedText: pageSliceAttrText))
                
                currentIndex += charRange.length
                pageIndex += 1
                if charRange.length == 0 { break }
            }
        }

        return slices.isEmpty ? [DocumentPageSlice(pageIndex: 0, text: "", range: NSRange(location: 0, length: 0))] : slices
    }
}
