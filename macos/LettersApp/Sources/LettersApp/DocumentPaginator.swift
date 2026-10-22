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
    private static let pageBreakRegex: NSRegularExpression = {
        (try? NSRegularExpression(pattern: #"(?:\r?\n)*---pagebreak---(?:\r?\n)*"#, options: [])) ?? NSRegularExpression()
    }()

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
        sideNotes: [StudioSideNote] = [],
        tables: [StudioTableData] = [],
        images: [StudioImageBlock] = [],
        videos: [StudioVideoBlock] = [],
        firstPageBannerHeight: CGFloat = 0
    ) -> [DocumentPageSlice] {
        
        let basePrintableHeight = max(100, sheetHeight - margins.top - margins.bottom)
        let totalPrintableWidth = max(100, sheetWidth - margins.left - margins.right)
        let cols = max(1, columnCount)
        
        let availableWidthForColumns = totalPrintableWidth - (CGFloat(max(0, cols - 1)) * columnGap)
        let columnWidth = max(50, availableWidthForColumns / CGFloat(cols))
        let printableWidth = columnWidth

        var attrString: NSMutableAttributedString
        
        if let data = richTextData,
           let docxAttr = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data),
           docxAttr.string == rawText {
            attrString = NSMutableAttributedString(attributedString: docxAttr)
            let fullRange = NSRange(location: 0, length: attrString.length)
            if fullRange.length > 0 {
                attrString.beginEditing()
                attrString.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, subRange, _ in
                    let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                    style.lineHeightMultiple = lineSpacing
                    style.paragraphSpacing = paragraphSpacing
                    attrString.addAttribute(.paragraphStyle, value: style, range: subRange)
                }
                attrString.endEditing()
            }
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

        let nsFullString = attrString.string as NSString
        let fullLength = nsFullString.length
        let pbMatches = pageBreakRegex.matches(in: attrString.string, options: [], range: NSRange(location: 0, length: fullLength))

        var sectionRanges: [NSRange] = []
        if pbMatches.isEmpty {
            sectionRanges = [NSRange(location: 0, length: fullLength)]
        } else {
            var lastLoc = 0
            for match in pbMatches {
                let len = max(0, match.range.location - lastLoc)
                sectionRanges.append(NSRange(location: lastLoc, length: len))
                lastLoc = match.range.location + match.range.length
            }
            sectionRanges.append(NSRange(location: lastLoc, length: max(0, fullLength - lastLoc)))
        }

        var slices: [DocumentPageSlice] = []
        var pageIndex = 0

        for sectionRange in sectionRanges {
            if sectionRange.length == 0 {
                let emptyAttr = NSAttributedString(string: "")
                slices.append(DocumentPageSlice(
                    pageIndex: pageIndex,
                    text: "",
                    range: sectionRange,
                    attributedText: emptyAttr,
                    isContinuation: false
                ))
                pageIndex += 1
                continue
            }

            var currentIndex = sectionRange.location
            let sectionEnd = sectionRange.location + sectionRange.length

            while currentIndex < sectionEnd {
                let remainingLength = sectionEnd - currentIndex
                let remainingText = attrString.attributedSubstring(from: NSRange(location: currentIndex, length: remainingLength))
                let effectiveSheetPrintableHeight: CGFloat = (pageIndex < cols && firstPageBannerHeight > 0)
                    ? max(100, basePrintableHeight - firstPageBannerHeight)
                    : basePrintableHeight

                if #available(macOS 12.0, *) {
                    let tempStorage = NSTextContentStorage()
                    tempStorage.attributedString = remainingText
                    let lm = NSTextLayoutManager()
                    tempStorage.addTextLayoutManager(lm)
                    
                    var currentPrintableHeight = effectiveSheetPrintableHeight
                    var lastVisibleLoc = 0
                    var includedFootnotes: [StudioFootnote] = []
                    var iteration = 0
                    var finalSideNotes: [DocumentPageSliceSideNote] = []
                    
                    while iteration < 5 {
                        iteration += 1
                        
                        let container = NSTextContainer(size: NSSize(width: printableWidth, height: currentPrintableHeight))
                        container.lineFragmentPadding = 0
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
                                let globalStart = currentIndex + startOffset
                                let globalEnd = globalStart + length
                                for sn in sideNotes {
                                    let isMatch: Bool
                                    if let loc = sn.rangeLocation {
                                        isMatch = (loc >= globalStart && loc < globalEnd)
                                    } else if let anchor = sn.anchorText, !anchor.isEmpty {
                                        isMatch = fragmentString.contains(anchor)
                                    } else if !sn.referenceMarker.isEmpty {
                                        isMatch = fragmentString.contains("[\(sn.referenceMarker)]")
                                    } else {
                                        isMatch = false
                                    }
                                    if isMatch && !pageSideNotes.contains(where: { $0.id == sn.id }) {
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
                                    let fragmentLength = lastVisibleLoc - startOffset
                                    let fragmentString = tempStorage.attributedString?.attributedSubstring(from: NSRange(location: startOffset, length: fragmentLength)).string ?? ""
                                    let globalStart = currentIndex + startOffset
                                    let globalEnd = globalStart + fragmentLength
                                    for sn in sideNotes {
                                        let isMatch: Bool
                                        if let loc = sn.rangeLocation {
                                            isMatch = (loc >= globalStart && loc < globalEnd)
                                        } else if let anchor = sn.anchorText, !anchor.isEmpty {
                                            isMatch = fragmentString.contains(anchor)
                                        } else if !sn.referenceMarker.isEmpty {
                                            isMatch = fragmentString.contains("[\(sn.referenceMarker)]")
                                        } else {
                                            isMatch = false
                                        }
                                        if isMatch && !pageSideNotes.contains(where: { $0.id == sn.id }) {
                                            pageSideNotes.append(DocumentPageSliceSideNote(id: sn.id, yPos: fragment.layoutFragmentFrame.minY))
                                        }
                                    }
                                }
                                if previousFragmentHadKeepWithNext, let prevStart = previousFragmentStartOffset, prevStart > 0 {
                                    lastVisibleLoc = prevStart
                                }
                                
                                return false
                            }
                        }
                        
                        if lastVisibleLoc == 0 {
                            lastVisibleLoc = remainingText.length > 0 ? 1 : 0
                        }
                        
                        let sliceString = remainingText.attributedSubstring(from: NSRange(location: 0, length: lastVisibleLoc)).string
                        let foundFootnotes = footnotes.filter { sliceString.contains("[\($0.referenceMarker)]") }
                        
                        var footnotesHeight: CGFloat = 0
                        if !foundFootnotes.isEmpty {
                            footnotesHeight += 20
                            for fn in foundFootnotes {
                                let lines = max(1, ceil(CGFloat(fn.text.count) / 50.0))
                                footnotesHeight += (lines * 15.0) + 4.0
                            }
                        }

                        let embeddedBlocksHeight = estimateEmbeddedBlocksHeight(
                            in: sliceString,
                            tables: tables,
                            images: images,
                            videos: videos
                        )
                        
                        let targetHeight = max(60, effectiveSheetPrintableHeight - footnotesHeight - embeddedBlocksHeight)
                        if abs(currentPrintableHeight - targetHeight) < 2.0 || currentPrintableHeight <= targetHeight {
                            includedFootnotes = foundFootnotes
                            finalSideNotes = pageSideNotes
                            break
                        } else {
                            currentPrintableHeight = targetHeight
                            finalSideNotes = pageSideNotes
                        }
                    }
                    
                    let sliceRange = NSRange(location: currentIndex, length: lastVisibleLoc)
                    let pageSliceAttrText = attrString.attributedSubstring(from: sliceRange)
                    
                    var isContinuation = false
                    if currentIndex > sectionRange.location {
                        let prevCharRange = NSRange(location: currentIndex - 1, length: 1)
                        let prevChar = attrString.attributedSubstring(from: prevCharRange).string
                        if prevChar != "\n" {
                            isContinuation = true
                        }
                    }
                    
                    slices.append(DocumentPageSlice(
                        pageIndex: pageIndex,
                        text: pageSliceAttrText.string,
                        range: sliceRange,
                        attributedText: pageSliceAttrText,
                        isContinuation: isContinuation,
                        footnoteIds: includedFootnotes.map { $0.id },
                        sideNotes: finalSideNotes
                    ))
                    
                    currentIndex += lastVisibleLoc
                    pageIndex += 1
                } else {
                    // Legacy TextKit 1 fallback for older macOS
                    let storage = NSTextStorage(attributedString: remainingText)
                    let layoutManager = NSLayoutManager()
                    storage.addLayoutManager(layoutManager)
                    
                    let container = NSTextContainer(containerSize: NSSize(width: printableWidth, height: effectiveSheetPrintableHeight))
                    container.lineFragmentPadding = 0
                    layoutManager.addTextContainer(container)
                    
                    layoutManager.ensureLayout(for: container)
                    let glyphRange = layoutManager.glyphRange(for: container)
                    let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                    
                    let sliceRange = NSRange(location: currentIndex, length: charRange.length)
                    let pageSliceAttrText = attrString.attributedSubstring(from: sliceRange)
                    
                    var isContinuation = false
                    if currentIndex > sectionRange.location {
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
        }

        return slices.isEmpty ? [DocumentPageSlice(pageIndex: 0, text: "", range: NSRange(location: 0, length: 0))] : slices
    }

    private static func estimateEmbeddedBlocksHeight(
        in sliceString: String,
        tables: [StudioTableData],
        images: [StudioImageBlock],
        videos: [StudioVideoBlock]
    ) -> CGFloat {
        let regex = EditorPerformanceCache.shared.canvasSegmentRegex
        let ns = sliceString as NSString
        let matches = regex.matches(in: sliceString, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return 0 }

        var totalExtraHeight: CGFloat = 0
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let kind = ns.substring(with: match.range(at: 1))
            let idStr = (match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound) ? ns.substring(with: match.range(at: 2)) : ""

            switch kind {
            case "table":
                let table = tables.first(where: { $0.id.uuidString.lowercased() == idStr.lowercased() })
                    ?? (idStr.lowercased() == "budget" ? tables.first : nil)
                let rowCount = max(1, (table?.rows.count ?? 3) + 1)
                totalExtraHeight += CGFloat(rowCount * 34) + 56
            case "image":
                let img = images.first(where: { $0.id.uuidString.lowercased() == idStr.lowercased() })
                let widthScale = (img?.scaleWidthPercent ?? 85.0) / 100.0
                totalExtraHeight += max(160, CGFloat(240.0 * widthScale)) + 48
            case "video":
                totalExtraHeight += 220
            case "toc":
                totalExtraHeight += 140
            case "bibliography":
                totalExtraHeight += 150
            default:
                break
            }
        }
        return totalExtraHeight
    }
}
