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
        fontSize: CGFloat,
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat
    ) -> [DocumentPageSlice] {
        if rawText.isEmpty {
            return [DocumentPageSlice(pageIndex: 0, text: "", range: NSRange(location: 0, length: 0))]
        }

        // Exact printable bounds inside physical page margins (with a 4pt safety buffer so bottom line is never cut off)
        let printableHeight = max(150, sheetHeight - margins.top - margins.bottom - 4)
        let printableWidth = max(150, sheetWidth - margins.left - margins.right)

        // Font metric estimation for average line capacity
        let avgCharWidth = max(5.0, fontSize * 0.48)
        let charsPerLine = max(20, Int(printableWidth / avgCharWidth))

        let baseFont = EditorPerformanceCache.shared.resolveFont(family: "Default Serif (Georgia)", size: fontSize, bold: false, italic: false)
        let baseLineHeight = (baseFont.ascender - baseFont.descender + baseFont.leading) * lineSpacing

        let nsText = rawText as NSString
        let fullLength = nsText.length

        var slices: [DocumentPageSlice] = []
        var currentPageStart = 0
        var currentHeight: CGFloat = 0
        var pageIndex = 0

        var lineStart = 0
        while lineStart < fullLength {
            var lineEnd = 0
            var contentsEnd = 0
            nsText.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))

            let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
            let lineString = nsText.substring(with: lineRange)
            let trimmedLine = lineString.trimmingCharacters(in: .whitespacesAndNewlines)

            // 1. Explicit Hard Page Break Marker
            if trimmedLine == "---pagebreak---" {
                let pageRange = NSRange(location: currentPageStart, length: max(0, lineStart - currentPageStart))
                let pageText = nsText.substring(with: pageRange)
                slices.append(DocumentPageSlice(pageIndex: pageIndex, text: pageText, range: pageRange))
                pageIndex += 1

                currentPageStart = lineEnd
                currentHeight = 0
                lineStart = lineEnd
                continue
            }

            // 2. Line height estimation based on block type / typography
            let lineCount: Int
            if trimmedLine.isEmpty {
                lineCount = 1
            } else {
                lineCount = max(1, Int(ceil(Double(trimmedLine.count) / Double(charsPerLine))))
            }

            let lineHeight: CGFloat
            if trimmedLine.starts(with: "[[table:") || trimmedLine.starts(with: "[[image:") || trimmedLine.starts(with: "[[video:") || trimmedLine.starts(with: "[[toc]]") || trimmedLine.starts(with: "[[bibliography]]") {
                lineHeight = 180 + paragraphSpacing
            } else if trimmedLine.starts(with: "# ") {
                let h1Font = EditorPerformanceCache.shared.resolveFont(family: "Default Serif (Georgia)", size: fontSize * 1.5, bold: true, italic: false)
                let h1Line = (h1Font.ascender - h1Font.descender + h1Font.leading) * lineSpacing
                lineHeight = (CGFloat(lineCount) * h1Line) + max(paragraphSpacing, 10)
            } else if trimmedLine.starts(with: "## ") {
                let h2Font = EditorPerformanceCache.shared.resolveFont(family: "Default Serif (Georgia)", size: fontSize * 1.3, bold: true, italic: false)
                let h2Line = (h2Font.ascender - h2Font.descender + h2Font.leading) * lineSpacing
                lineHeight = (CGFloat(lineCount) * h2Line) + max(paragraphSpacing, 8)
            } else if trimmedLine.starts(with: "### ") {
                let h3Font = EditorPerformanceCache.shared.resolveFont(family: "Default Serif (Georgia)", size: fontSize * 1.15, bold: true, italic: false)
                let h3Line = (h3Font.ascender - h3Font.descender + h3Font.leading) * lineSpacing
                lineHeight = (CGFloat(lineCount) * h3Line) + paragraphSpacing
            } else {
                lineHeight = (CGFloat(lineCount) * baseLineHeight) + paragraphSpacing
            }

            // 3. Check for vertical page overflow
            if currentHeight + lineHeight > printableHeight && lineStart > currentPageStart {
                let pageRange = NSRange(location: currentPageStart, length: lineStart - currentPageStart)
                let pageText = nsText.substring(with: pageRange)
                slices.append(DocumentPageSlice(pageIndex: pageIndex, text: pageText, range: pageRange))
                pageIndex += 1

                currentPageStart = lineStart
                currentHeight = lineHeight
            } else {
                currentHeight += lineHeight
            }

            lineStart = lineEnd
        }

        // Flush remaining text into the last page slice
        if currentPageStart <= fullLength {
            let pageRange = NSRange(location: currentPageStart, length: fullLength - currentPageStart)
            let pageText = nsText.substring(with: pageRange)
            slices.append(DocumentPageSlice(pageIndex: pageIndex, text: pageText, range: pageRange))
        }

        return slices.isEmpty ? [DocumentPageSlice(pageIndex: 0, text: "", range: NSRange(location: 0, length: 0))] : slices
    }
}
