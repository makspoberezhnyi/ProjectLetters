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

        // Exact printable bounds inside physical page margins
        let printableHeight = max(150, sheetHeight - margins.top - margins.bottom)
        let printableWidth = max(150, sheetWidth - margins.left - margins.right)

        // Font metric estimation for average line capacity
        let avgCharWidth = max(5.0, fontSize * 0.48)
        let charsPerLine = max(20, Int(printableWidth / avgCharWidth))
        let singleLineHeight = fontSize * lineSpacing * 1.35

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
                lineHeight = 180
            } else if trimmedLine.starts(with: "# ") {
                lineHeight = CGFloat(lineCount) * (fontSize * 1.5 * 1.35) + 14
            } else if trimmedLine.starts(with: "## ") {
                lineHeight = CGFloat(lineCount) * (fontSize * 1.3 * 1.35) + 10
            } else if trimmedLine.starts(with: "### ") {
                lineHeight = CGFloat(lineCount) * (fontSize * 1.15 * 1.35) + 8
            } else {
                lineHeight = CGFloat(lineCount) * singleLineHeight
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
