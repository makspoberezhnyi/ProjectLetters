import SwiftUI
import AppKit
import Foundation
#if canImport(LettersKit)
import LettersKit
#endif

public struct DocumentPageSliceSideNote: Equatable {
    public let id: UUID
    public let yPos: CGFloat
}

public struct DocumentPageSlice: Identifiable, Equatable {
    public var id: Int { pageIndex }
    public let pageIndex: Int
    public let text: String
    public let attributedText: NSAttributedString?
    public let range: NSRange
    public let isContinuation: Bool
    public let footnoteIds: [UUID]
    public let sideNotes: [DocumentPageSliceSideNote]

    public init(pageIndex: Int, text: String, range: NSRange, attributedText: NSAttributedString? = nil, isContinuation: Bool = false, footnoteIds: [UUID] = [], sideNotes: [DocumentPageSliceSideNote] = []) {
        self.pageIndex = pageIndex
        self.text = text
        self.range = range
        self.attributedText = attributedText
        self.isContinuation = isContinuation
        self.footnoteIds = footnoteIds
        self.sideNotes = sideNotes
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
        alignment: TextAlignment = .leading,
        columnCount: Int = 1,
        columnGap: CGFloat = 24.0,
        footnotes: [StudioFootnote] = [],
        sideNotes: [StudioSideNote] = []
    ) -> [DocumentPageSlice] {
        
        let printableHeight = max(100, sheetHeight - margins.top - margins.bottom)
        let totalPrintableWidth = max(100, sheetWidth - margins.left - margins.right)
        
        let availableWidthForColumns = totalPrintableWidth - (CGFloat(max(0, columnCount - 1)) * columnGap)
        let columnWidth = max(50, availableWidthForColumns / CGFloat(max(1, columnCount)))
        let printableWidth = columnWidth

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
                
                var currentPrintableHeight = printableHeight
                var lastVisibleLoc = 0
                var includedFootnotes: [StudioFootnote] = []
                var iteration = 0
                var finalSideNotes: [DocumentPageSliceSideNote] = []
                
                while iteration < 5 {
                    iteration += 1
                    
                    let container = NSTextContainer(size: NSSize(width: printableWidth, height: currentPrintableHeight))
                    container.lineFragmentPadding = 0 // Match Editor settings
                    lm.textContainer = container
                    lm.ensureLayout(for: lm.documentRange)
                    
                    lastVisibleLoc = 0
                    var pageSideNotes: [DocumentPageSliceSideNote] = []
                    
                    var previousFragmentStartOffset: Int? = nil
                    var previousFragmentHadKeepWithNext = false
                    
                    lm.enumerateTextLayoutFragments(from: lm.documentRange.location, options: [.ensuresLayout]) { fragment in
                        if fragment.layoutFragmentFrame.maxY <= currentPrintableHeight {
                            let range = fragment.rangeInElement
                            let startOffset = tempStorage.offset(from: tempStorage.documentRange.location, to: range.location)
                            let length = tempStorage.offset(from: range.location, to: range.endLocation)
                            lastVisibleLoc = max(lastVisibleLoc, startOffset + length)
                            
                            let isKeepWithNext = remainingText.attribute(.keepWithNext, at: startOffset, effectiveRange: nil) as? Bool ?? false
                            previousFragmentHadKeepWithNext = isKeepWithNext
                            previousFragmentStartOffset = startOffset
                            
                            let fragmentString = tempStorage.attributedString?.attributedSubstring(from: NSRange(location: startOffset, length: length)).string ?? ""
                            for sn in sideNotes {
                                if fragmentString.contains("[\(sn.referenceMarker)]") {
                                    pageSideNotes.append(DocumentPageSliceSideNote(id: sn.id, yPos: fragment.layoutFragmentFrame.minY))
                                }
                            }
                            
                            return true
                        } else {
                            let range = fragment.rangeInElement
                            let startOffset = tempStorage.offset(from: tempStorage.documentRange.location, to: range.location)
                            let isKeepLinesTogether = remainingText.attribute(.keepLinesTogether, at: startOffset, effectiveRange: nil) as? Bool ?? false
                            
                            var linesThatFit = 0
                            var charsThatFit = 0
                            let totalLines = fragment.textLineFragments.count
                            
                            for line in fragment.textLineFragments {
                                let lineMaxY = fragment.layoutFragmentFrame.minY + line.typographicBounds.maxY
                                if lineMaxY <= currentPrintableHeight {
                                    linesThatFit += 1
                                    charsThatFit += line.characterRange.length
                                } else {
                                    break
                                }
                            }
                            
                            if isKeepLinesTogether && startOffset > 0 {
                                // Push the entire paragraph to the next page. 
                                // (lastVisibleLoc remains at startOffset)
                            } else {
                                if linesThatFit > 0 {
                                    if linesThatFit == 1 && totalLines > 1 {
                                    } else if (totalLines - linesThatFit) == 1 && totalLines > 2 {
                                        var adjustedChars = 0
                                        for (idx, line) in fragment.textLineFragments.enumerated() {
                                            if idx < linesThatFit - 1 {
                                                adjustedChars += line.characterRange.length
                                            }
                                        }
                                        lastVisibleLoc = max(lastVisibleLoc, startOffset + adjustedChars)
                                    } else {
                                        lastVisibleLoc = max(lastVisibleLoc, startOffset + charsThatFit)
                                    }
                                }
                            }
                            
                            if lastVisibleLoc > startOffset {
                                let fragmentString = tempStorage.attributedString?.attributedSubstring(from: NSRange(location: startOffset, length: lastVisibleLoc - startOffset)).string ?? ""
                                for sn in sideNotes {
                                    if fragmentString.contains("[\(sn.referenceMarker)]") {
                                        pageSideNotes.append(DocumentPageSliceSideNote(id: sn.id, yPos: fragment.layoutFragmentFrame.minY))
                                    }
                                }
                            }
                            // Keep with Next Rollback
                            if previousFragmentHadKeepWithNext, let prevStart = previousFragmentStartOffset, prevStart > 0 {
                                // Push the previous paragraph to the next page too!
                                lastVisibleLoc = prevStart
                            }
                            
                            return false
                        }
                    }
                    
                    if lastVisibleLoc == 0 {
                        lastVisibleLoc = remainingText.length > 0 ? 1 : 0
                    }
                    
                    if footnotes.isEmpty { break }
                    
                    let sliceString = remainingText.attributedSubstring(from: NSRange(location: 0, length: lastVisibleLoc)).string
                    let foundFootnotes = footnotes.filter { sliceString.contains("[\($0.referenceMarker)]") }
                    
                    var footnotesHeight: CGFloat = 0
                    if !foundFootnotes.isEmpty {
                        footnotesHeight += 20 // Top separator padding
                        for fn in foundFootnotes {
                            // Rough estimate: 15pt per line, ~50 chars per line
                            let lines = max(1, ceil(CGFloat(fn.text.count) / 50.0))
                            footnotesHeight += (lines * 15.0) + 4.0
                        }
                    }
                    
                    let targetHeight = printableHeight - footnotesHeight
                    if abs(currentPrintableHeight - targetHeight) < 2.0 || currentPrintableHeight <= targetHeight {
                        includedFootnotes = foundFootnotes
                        finalSideNotes = pageSideNotes
                        break
                    } else {
                        currentPrintableHeight = max(50, targetHeight)
                        finalSideNotes = pageSideNotes
                    }
                }
                
                let sliceRange = NSRange(location: currentIndex, length: lastVisibleLoc)
                let pageSliceAttrText = attrString.attributedSubstring(from: sliceRange)
                
                var isContinuation = false
                if currentIndex > 0 {
                    let prevCharRange = NSRange(location: currentIndex - 1, length: 1)
                    let prevChar = attrString.attributedSubstring(from: prevCharRange).string
                    if prevChar != "\n" {
                        isContinuation = true
                    }
                }
                
                slices.append(DocumentPageSlice(pageIndex: pageIndex, text: pageSliceAttrText.string, range: sliceRange, attributedText: pageSliceAttrText, isContinuation: isContinuation, footnoteIds: includedFootnotes.map { $0.id }, sideNotes: finalSideNotes))
                
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
                
                var isContinuation = false
                if currentIndex > 0 {
                    let prevCharRange = NSRange(location: currentIndex - 1, length: 1)
                    let prevChar = attrString.attributedSubstring(from: prevCharRange).string
                    if prevChar != "\n" {
                        isContinuation = true
                    }
                }
                
                slices.append(DocumentPageSlice(pageIndex: pageIndex, text: pageSliceAttrText.string, range: sliceRange, attributedText: pageSliceAttrText, isContinuation: isContinuation))
                
                currentIndex += charRange.length
                pageIndex += 1
                if charRange.length == 0 { break }
            }
        }

        return slices.isEmpty ? [DocumentPageSlice(pageIndex: 0, text: "", range: NSRange(location: 0, length: 0))] : slices
    }
}
