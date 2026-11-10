import SwiftUI
import AppKit
import Foundation
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Sheet geometry (pure, no AppKit state)

/// Describes one physical sheet and how text flows across a stack of them.
///
/// The canvas is a single, continuous TextKit 2 text view. Pages are *not* separate views:
/// the text container simply has a full-width exclusion band over every page seam
/// (bottom margin of page N + top margin of page N+1), so lines naturally skip the seam
/// and every page keeps its margins. This struct is the single place that knows the maths.
public struct SheetGeometry: Equatable {
    public var sheetSize: CGSize
    public var margins: PageMargins

    public init(sheetSize: CGSize, margins: PageMargins) {
        self.sheetSize = sheetSize
        self.margins = margins
    }

    /// Width of the text container (the printable column).
    public var containerWidth: CGFloat {
        max(100, sheetSize.width - margins.left - margins.right)
    }

    /// Height of the printable column on one page.
    public var printableHeight: CGFloat {
        max(60, sheetSize.height - margins.top - margins.bottom)
    }

    /// Number of sheets needed for text whose bottom edge sits at `usedHeight`
    /// (measured in text-container coordinates, i.e. below the top margin).
    public func pageCount(usedHeight: CGFloat) -> Int {
        let paperBottom = max(0, usedHeight) + margins.top + margins.bottom
        return max(1, Int(ceil(paperBottom / sheetSize.height - 0.0001)))
    }

    /// Exclusion bands, in text-container coordinates, one per page seam.
    public func seamBands(pageCount: Int) -> [CGRect] {
        guard pageCount > 1 else { return [] }
        let bandHeight = margins.top + margins.bottom
        return (1..<pageCount).map { k in
            CGRect(
                x: -20,
                y: CGFloat(k) * sheetSize.height - bandHeight,
                width: containerWidth + 40,
                height: bandHeight
            )
        }
    }

    /// Zero-based page that contains a y position measured on the paper.
    public func pageIndex(atPaperY y: CGFloat) -> Int {
        max(0, Int(floor(y / sheetSize.height)))
    }

    /// Which header/footer band (if any) a point on the paper falls into.
    public func headerFooterTarget(atPaperY y: CGFloat) -> HeaderFooterTarget? {
        let local = y - CGFloat(pageIndex(atPaperY: y)) * sheetSize.height
        if local < margins.top * 0.55 { return .header }
        if local > sheetSize.height - margins.bottom * 0.55 { return .footer }
        return nil
    }
}

// MARK: - Everything the canvas needs to render, as one Equatable value

public struct CanvasConfig: Equatable {
    public var geometry: SheetGeometry
    public var fontFamily: String
    public var fontSize: CGFloat
    public var lineSpacing: CGFloat
    public var paragraphSpacing: CGFloat
    public var alignment: TextAlignment
    public var kern: CGFloat
    public var hangingIndent: CGFloat
    public var showLineNumbers: Bool
    public var showMarginGuides: Bool
    public var showCropMarks: Bool
    public var watermark: String
    public var headerFooter: HeaderFooterConfig
    public var title: String

    public init(
        geometry: SheetGeometry,
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15,
        lineSpacing: CGFloat = 1.15,
        paragraphSpacing: CGFloat = 12,
        alignment: TextAlignment = .leading,
        kern: CGFloat = 0,
        hangingIndent: CGFloat = 0,
        showLineNumbers: Bool = false,
        showMarginGuides: Bool = true,
        showCropMarks: Bool = false,
        watermark: String = "",
        headerFooter: HeaderFooterConfig = HeaderFooterConfig(),
        title: String = ""
    ) {
        self.geometry = geometry
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.alignment = alignment
        self.kern = kern
        self.hangingIndent = hangingIndent
        self.showLineNumbers = showLineNumbers
        self.showMarginGuides = showMarginGuides
        self.showCropMarks = showCropMarks
        self.watermark = watermark
        self.headerFooter = headerFooter
        self.title = title
    }
}

/// A coalesced description of the editor selection, published to SwiftUI once per run-loop turn.
public struct SelectionSnapshot {
    public var range: NSRange
    public var text: String
    public var attributes: EditorSelectionAttributes
}

// MARK: - The paper: the one and only text view

public final class PaperTextView: NSTextView {
    public weak var actionController: EditorActionController?
    public var config: CanvasConfig? {
        didSet { if config != oldValue { needsDisplay = true } }
    }
    /// Called after the paper's own frame changed (content grew or shrank by a page).
    public var onPaperResized: (() -> Void)?
    public var onRequestHeaderFooterEdit: ((HeaderFooterTarget) -> Void)?

    private var appliedBandPageCount = 1
    /// While true, editing chrome (guides, seam labels, crop marks) is not painted.
    private var isExporting = false

    /// Number of whole sheets the paper currently spans.
    public var pageCount: Int {
        guard let h = config?.geometry.sheetSize.height, h > 0 else { return 1 }
        return max(1, Int(round(bounds.height / h)))
    }

    /// 1-based page number for a character offset, from the real layout.
    public func pageNumber(forCharacterOffset offset: Int) -> Int {
        guard let config, let tlm = textLayoutManager, let cm = tlm.textContentManager,
              let start = cm.location(cm.documentRange.location, offsetBy: max(0, offset)) else { return 1 }
        let end = cm.location(start, offsetBy: 1) ?? start
        guard let range = NSTextRange(location: start, end: end) else { return 1 }
        tlm.ensureLayout(for: range)
        var y: CGFloat = 0
        tlm.enumerateTextSegments(in: range, type: .standard, options: []) { _, frame, _, _ in
            y = frame.minY
            return false
        }
        return config.geometry.pageIndex(atPaperY: y + textContainerInset.height) + 1
    }

    // MARK: Layout

    /// Re-measures the text and resizes the paper to a whole number of sheets.
    /// Page count and seam bands depend on each other, so we iterate until they agree (≤ 4 passes).
    public func relayoutPaper() {
        guard let config, let tlm = textLayoutManager else { return }
        let geometry = config.geometry
        var pages = appliedBandPageCount

        for _ in 0..<4 {
            applySeamBands(geometry.seamBands(pageCount: pages))
            tlm.ensureLayout(for: tlm.documentRange)
            let used = max(tlm.usageBoundsForTextContainer.maxY, 0)
            let needed = geometry.pageCount(usedHeight: used)
            if needed == pages { break }
            pages = needed
        }
        appliedBandPageCount = pages

        let target = NSSize(width: geometry.sheetSize.width, height: CGFloat(pages) * geometry.sheetSize.height)
        if frame.size != target {
            setFrameSize(target)
            needsDisplay = true
            onPaperResized?()
        }
    }

    private func applySeamBands(_ bands: [CGRect]) {
        let paths = bands.map { NSBezierPath(rect: $0) }
        guard let container = textContainer else { return }
        if container.exclusionPaths.count != paths.count || zip(container.exclusionPaths, paths).contains(where: { $0.bounds != $1.bounds }) {
            container.exclusionPaths = paths
        }
    }

    /// Resets cached layout state after the geometry changed.
    public func geometryDidChange() {
        appliedBandPageCount = 1
    }

    // MARK: Drawing (everything that used to be SwiftUI overlays now paints *under* the text)

    public override func drawBackground(in rect: NSRect) {
        NSColor.white.setFill()
        rect.fill()
        guard let config else { return }
        let g = config.geometry
        let pages = max(1, Int(round(bounds.height / g.sheetSize.height)))

        for page in 0..<pages {
            let top = CGFloat(page) * g.sheetSize.height
            let pageRect = NSRect(x: 0, y: top, width: g.sheetSize.width, height: g.sheetSize.height)
            guard pageRect.intersects(rect) else { continue }

            if !config.watermark.isEmpty { drawWatermark(config.watermark, in: pageRect) }
            if config.showMarginGuides && !isExporting { drawMarginGuides(in: pageRect, margins: g.margins) }
            if config.showCropMarks && !isExporting { drawCropMarks(in: pageRect) }
            drawHeaderFooter(page: page, pages: pages, in: pageRect, config: config)
            if page > 0 && !isExporting { drawSeam(at: top, geometry: g, label: "PAGE \(page + 1)") }
        }

        if config.showLineNumbers { drawLineNumbers(in: rect, margins: g.margins) }
    }

    private func drawSeam(at y: CGFloat, geometry g: SheetGeometry, label: String) {
        let color = NSColor(white: 0.55, alpha: 0.45)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: y))
        path.line(to: NSPoint(x: g.sheetSize.width, y: y))
        path.setLineDash([4, 4], count: 2, phase: 0)
        path.lineWidth = 1
        color.setStroke()
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: NSColor(white: 0.55, alpha: 0.8)
        ]
        let text = NSAttributedString(string: label, attributes: attrs)
        let size = text.size()
        text.draw(at: NSPoint(x: g.sheetSize.width - g.margins.right - size.width, y: y + 4))
    }

    private func drawMarginGuides(in page: NSRect, margins m: PageMargins) {
        let rect = NSRect(
            x: page.minX + m.left,
            y: page.minY + m.top,
            width: page.width - m.left - m.right,
            height: page.height - m.top - m.bottom
        )
        let path = NSBezierPath(rect: rect)
        path.setLineDash([2, 3], count: 2, phase: 0)
        path.lineWidth = 0.5
        NSColor.systemBlue.withAlphaComponent(0.18).setStroke()
        path.stroke()
    }

    private func drawCropMarks(in page: NSRect) {
        let inset: CGFloat = 14
        let len: CGFloat = 10
        let path = NSBezierPath()
        let corners: [(NSPoint, CGFloat, CGFloat)] = [
            (NSPoint(x: page.minX + inset, y: page.minY + inset), 1, 1),
            (NSPoint(x: page.maxX - inset, y: page.minY + inset), -1, 1),
            (NSPoint(x: page.minX + inset, y: page.maxY - inset), 1, -1),
            (NSPoint(x: page.maxX - inset, y: page.maxY - inset), -1, -1)
        ]
        for (p, dx, dy) in corners {
            path.move(to: NSPoint(x: p.x + dx * len, y: p.y))
            path.line(to: p)
            path.line(to: NSPoint(x: p.x, y: p.y + dy * len))
        }
        path.lineWidth = 0.6
        NSColor(white: 0.35, alpha: 0.5).setStroke()
        path.stroke()
    }

    private func drawWatermark(_ text: String, in page: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 120, weight: .black),
            .foregroundColor: NSColor(white: 0.5, alpha: 0.12)
        ]
        let str = NSAttributedString(string: text.uppercased(), attributes: attrs)
        let size = str.size()
        let scale = min(1, (page.width * 0.9) / max(size.width, 1))
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: page.midX, yBy: page.midY)
        t.rotate(byDegrees: -45)
        t.scaleX(by: scale, yBy: scale)
        t.concat()
        str.draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2))
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawHeaderFooter(page: Int, pages: Int, in rect: NSRect, config: CanvasConfig) {
        let g = config.geometry
        let font = resolveNSHeaderFont(fontFamily: config.fontFamily, size: 10.5, weight: .regular)
        let color = NSColor(white: 0.32, alpha: 1)
        let innerWidth = rect.width - g.margins.left - g.margins.right
        let slotWidth = innerWidth / 3
        let lineHeight: CGFloat = 14

        func draw(_ s: String, slot: Int, alignment: NSTextAlignment, y: CGFloat) {
            guard !s.isEmpty else { return }
            let style = NSMutableParagraphStyle()
            style.alignment = alignment
            style.lineBreakMode = .byTruncatingTail
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
            let r = NSRect(x: rect.minX + g.margins.left + CGFloat(slot) * slotWidth, y: y, width: slotWidth - 6, height: lineHeight)
            (s as NSString).draw(in: r, withAttributes: attrs)
        }

        let hf = config.headerFooter
        let headerY = rect.minY + max(14, g.margins.top * 0.5 - lineHeight / 2)
        let footerY = rect.maxY - max(14, g.margins.bottom * 0.5 + lineHeight / 2)
        draw(hf.evaluateHeader(slot: .left, pageIndex: page, totalPages: pages, documentTitle: config.title), slot: 0, alignment: .left, y: headerY)
        draw(hf.evaluateHeader(slot: .center, pageIndex: page, totalPages: pages, documentTitle: config.title), slot: 1, alignment: .center, y: headerY)
        draw(hf.evaluateHeader(slot: .right, pageIndex: page, totalPages: pages, documentTitle: config.title), slot: 2, alignment: .right, y: headerY)
        draw(hf.evaluateFooter(slot: .left, pageIndex: page, totalPages: pages, documentTitle: config.title), slot: 0, alignment: .left, y: footerY)
        draw(hf.evaluateFooter(slot: .center, pageIndex: page, totalPages: pages, documentTitle: config.title), slot: 1, alignment: .center, y: footerY)
        draw(hf.evaluateFooter(slot: .right, pageIndex: page, totalPages: pages, documentTitle: config.title), slot: 2, alignment: .right, y: footerY)
    }

    private func drawLineNumbers(in dirty: NSRect, margins m: PageMargins) {
        guard let tlm = textLayoutManager else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor(white: 0.6, alpha: 1)
        ]
        var number = 0
        tlm.enumerateTextLayoutFragments(from: tlm.documentRange.location, options: [.ensuresLayout]) { fragment in
            for line in fragment.textLineFragments {
                number += 1
                let y = fragment.layoutFragmentFrame.minY + line.typographicBounds.minY + m.top
                if y > dirty.maxY { return false }
                if y + line.typographicBounds.height < dirty.minY { continue }
                let s = NSAttributedString(string: "\(number)", attributes: attrs)
                s.draw(at: NSPoint(x: m.left - 10 - s.size().width, y: y + 2))
            }
            return true
        }
    }

    // MARK: Export

    /// Vector PDF of the live canvas: one page per sheet, plus bookmarks for every heading.
    public func exportPDFData() -> Data? {
        guard let config else { return nil }
        let g = config.geometry
        let savedSelection = selectedRange()
        isExporting = true
        setSelectedRange(NSRange(location: 0, length: 0))
        defer {
            isExporting = false
            setSelectedRange(savedSelection)
            needsDisplay = true
        }

        let pdf = PDFDocument()
        for index in 0..<pageCount {
            let rect = NSRect(x: 0, y: CGFloat(index) * g.sheetSize.height, width: g.sheetSize.width, height: g.sheetSize.height)
            if let page = PDFDocument(data: dataWithPDF(inside: rect))?.page(at: 0) {
                pdf.insert(page, at: pdf.pageCount)
            }
        }
        guard pdf.pageCount > 0 else { return nil }

        let root = PDFOutline()
        for heading in headingEntries() {
            let pageIndex = min(pdf.pageCount - 1, max(0, pageNumber(forCharacterOffset: heading.offset) - 1))
            guard let page = pdf.page(at: pageIndex) else { continue }
            let item = PDFOutline()
            item.label = heading.title
            item.destination = PDFDestination(page: page, at: NSPoint(x: 0, y: g.sheetSize.height))
            root.insertChild(item, at: root.numberOfChildren)
        }
        if root.numberOfChildren > 0 { pdf.outlineRoot = root }
        return pdf.dataRepresentation()
    }

    /// Markdown-style (`# Title`) and visually styled (large / bold) headings in document order.
    public func headingEntries() -> [(title: String, offset: Int)] {
        guard let storage = textStorage else { return [] }
        let ns = storage.string as NSString
        var entries: [(String, Int)] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            guard range.length > 0, range.length <= 140 else { return }
            let line = ns.substring(with: range).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("[[") else { return }
            for prefix in ["### ", "## ", "# "] where line.hasPrefix(prefix) {
                entries.append((String(line.dropFirst(prefix.count)), range.location))
                return
            }
            if let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont {
                let traits = NSFontManager.shared.traits(of: font)
                let style = DocumentParagraphStyle.infer(fontSize: font.pointSize, isBold: traits.contains(.boldFontMask), isItalic: traits.contains(.italicFontMask))
                if [.title, .heading1, .heading2, .heading3].contains(style) { entries.append((line, range.location)) }
            }
        }
        return entries
    }

    // MARK: Input

    public override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, let config {
            let p = convert(event.locationInWindow, from: nil)
            if let target = config.geometry.headerFooterTarget(atPaperY: p.y) {
                onRequestHeaderFooterEdit?(target)
                return
            }
        }
        super.mouseDown(with: event)
    }

    public override func keyDown(with event: NSEvent) {
        if handleSmartTyping(event) { return }
        super.keyDown(with: event)
    }

    /// Word / Pages style list continuation, Tab nesting and `* ` / `1. ` auto-bullets.
    /// Returns true when the event was fully handled.
    private func handleSmartTyping(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let ns = string as NSString
        let sel = selectedRange()
        let strLen = ns.length
        guard sel.length == 0, strLen > 0 else { return false }

        let isReturn = event.keyCode == 36 && !mods.contains(.shift) && !mods.contains(.command)
        let isTab = event.keyCode == 48
        let isSpace = event.charactersIgnoringModifiers == " " && !mods.contains(.command)

        if isReturn {
            let lineRange = ns.lineRange(for: NSRange(location: min(max(0, sel.location), max(0, strLen - 1)), length: 0))
            let line = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)

            if let prefixRange = line.range(of: #"^(\s*)([•◦▪]|-\s\[[ xX]\])\s+"#, options: .regularExpression) {
                let prefix = String(line[prefixRange])
                let body = String(line[prefixRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if body.isEmpty {
                    insertText("", replacementRange: NSRange(location: lineRange.location, length: min((line as NSString).length, strLen - lineRange.location)))
                } else {
                    let next = prefix.replacingOccurrences(of: "[x]", with: "[ ]").replacingOccurrences(of: "[X]", with: "[ ]")
                    insertText("\n" + next, replacementRange: sel)
                }
                return true
            }

            if let prefixRange = line.range(of: #"^(\s*)(\d+)\.\s+"#, options: .regularExpression) {
                let prefix = String(line[prefixRange])
                let body = String(line[prefixRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if body.isEmpty {
                    insertText("", replacementRange: NSRange(location: lineRange.location, length: min((line as NSString).length, strLen - lineRange.location)))
                } else {
                    let indent = String(prefix.prefix(while: { $0 == " " || $0 == "\t" }))
                    let digits = prefix.trimmingCharacters(in: .whitespaces).dropLast()
                    insertText("\n\(indent)\((Int(digits) ?? 1) + 1). ", replacementRange: sel)
                }
                return true
            }
            return false
        }

        if isTab {
            let lineRange = ns.lineRange(for: NSRange(location: min(max(0, sel.location), max(0, strLen - 1)), length: 0))
            let line = ns.substring(with: lineRange)
            guard line.range(of: #"^\s*([•◦▪]|\d+\.|-\s\[[ xX]\])\s+"#, options: .regularExpression) != nil else { return false }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if mods.contains(.shift) {
                guard line.hasPrefix("    ") else { return true }
                let updated = String(line.dropFirst(4)).replacingOccurrences(of: "▪ ", with: "◦ ").replacingOccurrences(of: "◦ ", with: "• ")
                insertText(updated, replacementRange: lineRange)
            } else if trimmed.hasPrefix("• ") {
                insertText("    " + line.replacingOccurrences(of: "• ", with: "◦ "), replacementRange: lineRange)
            } else if trimmed.hasPrefix("◦ ") {
                insertText("    " + line.replacingOccurrences(of: "◦ ", with: "▪ "), replacementRange: lineRange)
            } else {
                insertText("    " + line, replacementRange: lineRange)
            }
            return true
        }

        if isSpace {
            let loc = min(max(0, sel.location), strLen)
            let lineRange = ns.lineRange(for: NSRange(location: max(0, loc - 1), length: 0))
            let prefixLen = loc - lineRange.location
            guard prefixLen > 0 else { return false }
            let linePrefix = ns.substring(with: NSRange(location: lineRange.location, length: prefixLen))
            if linePrefix == "*" || linePrefix == "-" {
                insertText("• ", replacementRange: NSRange(location: lineRange.location, length: prefixLen))
                return true
            }
            if linePrefix.range(of: #"^\d+\.$"#, options: .regularExpression) != nil {
                insertText("\(linePrefix) ", replacementRange: NSRange(location: lineRange.location, length: prefixLen))
                return true
            }
        }
        return false
    }

    // MARK: Paste & drop

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "tiff", "heic"]

    public override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls where Self.imageExtensions.contains(url.pathExtension.lowercased()) {
                if let data = try? Data(contentsOf: url) {
                    actionController?.onInsertImageBlock?(Self.imageBlock(data: data, caption: "Figure: \(url.deletingPathExtension().lastPathComponent)"))
                    return
                }
            }
        }
        if pb.string(forType: .string) == nil,
           let img = (pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage])?.first,
           let tiff = img.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            actionController?.onInsertImageBlock?(Self.imageBlock(data: png, caption: "Pasted Figure"))
            return
        }
        super.paste(sender)
    }

    private static func imageBlock(data: Data, caption: String) -> StudioImageBlock {
        StudioImageBlock(
            base64Data: data.base64EncodedString(),
            originalByteSize: data.count,
            compressedByteSize: data.count,
            caption: caption
        )
    }

    public func pasteAndMatchStyle() {
        guard let text = NSPasteboard.general.string(forType: .string) else { super.paste(nil); return }
        insertText(text, replacementRange: selectedRange())
    }

    public func pasteWithCleanContrast() {
        let before = selectedRange()
        super.paste(nil)
        let after = selectedRange()
        if after.location > before.location {
            cleanContrast(in: NSRange(location: before.location, length: after.location - before.location))
        }
    }

    /// Fixes pasted near-white text and dark/pure-white backgrounds so pasted content stays legible on paper.
    public func cleanContrast(in range: NSRange) {
        guard let storage = textStorage, range.location + range.length <= storage.length else { return }
        func luminance(_ c: NSColor) -> CGFloat? {
            guard let rgb = c.usingColorSpace(.deviceRGB) else { return nil }
            return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        }
        storage.beginEditing()
        storage.enumerateAttributes(in: range, options: []) { attrs, sub, _ in
            var updated = attrs
            var changed = false
            if let fg = attrs[.foregroundColor] as? NSColor, let lum = luminance(fg), lum > 0.82 {
                updated[.foregroundColor] = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
                changed = true
            }
            if let bg = attrs[.backgroundColor] as? NSColor, let lum = luminance(bg), lum < 0.25 || lum > 0.98 {
                updated.removeValue(forKey: .backgroundColor)
                changed = true
            }
            if changed { storage.setAttributes(updated, range: sub) }
        }
        storage.endEditing()
        didChangeText()
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            var handled = false
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["docx", "pdf", "txt", "md"].contains(ext) {
                    actionController?.onImportFile?(url)
                    handled = true
                } else if Self.imageExtensions.contains(ext), let data = try? Data(contentsOf: url) {
                    actionController?.onInsertImageBlock?(Self.imageBlock(data: data, caption: "Figure: \(url.deletingPathExtension().lastPathComponent)"))
                    handled = true
                }
            }
            if handled { return true }
        }
        return super.performDragOperation(sender)
    }
}

// MARK: - Desk: the grey surface the paper sits on

final class CanvasDeskView: NSView {
    let paper: PaperTextView
    private let topInset: CGFloat = 28
    private let bottomInset: CGFloat = 96
    private let minGutter: CGFloat = 40

    override var isFlipped: Bool { true }

    init(paper: PaperTextView) {
        self.paper = paper
        super.init(frame: .zero)
        addSubview(paper)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Sizes the desk to the visible width (or the paper plus gutters, whichever is wider)
    /// and centres the paper on a whole-pixel origin so text stays crisp.
    func fit(clipWidth: CGFloat) {
        let width = max(clipWidth, paper.frame.width + 2 * minGutter)
        let height = topInset + paper.frame.height + bottomInset
        let size = NSSize(width: width, height: height)
        if frame.size != size { setFrameSize(size) }
        let origin = NSPoint(x: floor((width - paper.frame.width) / 2), y: topInset)
        if paper.frame.origin != origin { paper.setFrameOrigin(origin) }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.underPageBackgroundColor.setFill()
        dirtyRect.fill()

        let sheet = paper.frame
        NSGraphicsContext.saveGraphicsState()
        let ambient = NSShadow()
        ambient.shadowColor = NSColor.black.withAlphaComponent(0.20)
        ambient.shadowBlurRadius = 22
        ambient.shadowOffset = .zero
        ambient.set()
        NSColor.white.setFill()
        sheet.fill()
        let contact = NSShadow()
        contact.shadowColor = NSColor.black.withAlphaComponent(0.28)
        contact.shadowBlurRadius = 2
        contact.shadowOffset = .zero
        contact.set()
        sheet.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - Scroll container (native scrolling + native pinch/⌘± magnification)

final class CanvasScrollView: NSScrollView {
    let desk: CanvasDeskView
    var paper: PaperTextView { desk.paper }
    var onMagnificationChanged: ((CGFloat) -> Void)?
    private var didClaimInitialFocus = false

    init(paper: PaperTextView) {
        desk = CanvasDeskView(paper: paper)
        super.init(frame: .zero)
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = true
        scrollerStyle = .overlay
        borderType = .noBorder
        drawsBackground = true
        backgroundColor = .underPageBackgroundColor
        allowsMagnification = true
        minMagnification = 0.4
        maxMagnification = 3.0
        documentView = desk
        contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(clipBoundsChanged), name: NSView.boundsDidChangeNotification, object: contentView
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(liveMagnifyEnded), name: NSScrollView.didEndLiveMagnifyNotification, object: self
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func clipBoundsChanged() { desk.fit(clipWidth: contentView.bounds.width) }

    @objc private func liveMagnifyEnded() { onMagnificationChanged?(magnification) }

    override func layout() {
        super.layout()
        desk.fit(clipWidth: contentView.bounds.width)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Land with the caret on line 1 so the very first keystroke types into the page.
        guard window != nil, !didClaimInitialFocus else { return }
        didClaimInitialFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            let current = window.firstResponder
            if current == nil || current === window || !(current is NSTextView) {
                window.makeFirstResponder(self.paper)
            }
        }
    }
}

// MARK: - SwiftUI bridge

public struct SanctuaryCanvas: NSViewRepresentable {
    let document: LettersDocumentController
    let controller: EditorActionController
    let config: CanvasConfig
    @Binding var zoom: Double
    var hoveredCommentId: UUID?
    var onSelectionChange: (SelectionSnapshot) -> Void
    var onEditHeaderFooter: (HeaderFooterTarget) -> Void
    var blockContent: (BlockKind) -> AnyView

    public init(
        document: LettersDocumentController,
        controller: EditorActionController,
        config: CanvasConfig,
        zoom: Binding<Double>,
        hoveredCommentId: UUID? = nil,
        onSelectionChange: @escaping (SelectionSnapshot) -> Void,
        onEditHeaderFooter: @escaping (HeaderFooterTarget) -> Void,
        blockContent: @escaping (BlockKind) -> AnyView = { _ in AnyView(EmptyView()) }
    ) {
        self.document = document
        self.controller = controller
        self.config = config
        self._zoom = zoom
        self.hoveredCommentId = hoveredCommentId
        self.onSelectionChange = onSelectionChange
        self.onEditHeaderFooter = onEditHeaderFooter
        self.blockContent = blockContent
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeNSView(context: Context) -> NSScrollView {
        let paper = PaperTextView(usingTextLayoutManager: true)
        paper.appearance = NSAppearance(named: .aqua) // paper is always white, whatever the system theme
        paper.isRichText = true
        paper.allowsUndo = true
        paper.isEditable = true
        paper.isSelectable = true
        paper.importsGraphics = false
        paper.isContinuousSpellCheckingEnabled = true
        paper.isGrammarCheckingEnabled = true
        paper.isAutomaticQuoteSubstitutionEnabled = true
        paper.isAutomaticDashSubstitutionEnabled = true
        paper.smartInsertDeleteEnabled = true
        paper.drawsBackground = true
        paper.backgroundColor = .white
        paper.insertionPointColor = .systemBlue
        paper.focusRingType = .none
        paper.isVerticallyResizable = false
        paper.isHorizontallyResizable = false
        paper.autoresizingMask = []
        if #available(macOS 15.0, *) { paper.writingToolsBehavior = .complete }

        if let container = paper.textContainer {
            container.widthTracksTextView = false
            container.heightTracksTextView = false
            container.lineFragmentPadding = 0
        }

        paper.actionController = controller
        paper.delegate = context.coordinator
        paper.textContentStorage?.delegate = context.coordinator
        paper.onPaperResized = { [weak coordinator = context.coordinator] in coordinator?.paperDidResize() }
        paper.onRequestHeaderFooterEdit = { [weak coordinator = context.coordinator] target in
            coordinator?.parent.onEditHeaderFooter(target)
        }
        controller.textView = paper

        let scroll = CanvasScrollView(paper: paper)
        controller.onFlush = { [weak coordinator = context.coordinator] in coordinator?.flushRichText() }
        scroll.onMagnificationChanged = { [weak coordinator = context.coordinator] mag in
            coordinator?.magnificationChanged(Double(mag))
        }
        context.coordinator.scrollView = scroll
        context.coordinator.paper = paper
        context.coordinator.install(config: config, document: document)
        scroll.magnification = CGFloat(zoom)

        document.flushEditor = { [weak coordinator = context.coordinator] in coordinator?.flushRichText() }
        return scroll
    }

    public func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let paper = coordinator.paper else { return }
        paper.actionController = controller
        controller.textView = paper

        coordinator.syncModelIntoView(document: document)
        coordinator.applyConfig(config)
        coordinator.applyAnnotations(document: document, hoveredCommentId: hoveredCommentId)

        let target = CGFloat(zoom)
        if abs(scroll.magnification - target) > 0.001 { scroll.magnification = target }
    }

    // MARK: Coordinator

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SanctuaryCanvas
        weak var paper: PaperTextView?
        weak var scrollView: CanvasScrollView?

        /// The last plain string we know the model and the view agree on.
        private var syncedText: String = ""
        private var isApplyingModel = false
        private var appliedConfig: CanvasConfig?
        private var richSyncWork: DispatchWorkItem?
        private var selectionPublishPending = false
        private var lastNotesKey: [AnyHashable] = []
        private var lastRevisionCount = -1

        // Block layer (tables, figures, TOC, bibliography, page breaks)
        private var markers: [BlockMarker] = []
        private var hosts: [String: BlockHostingView] = [:]
        private var measuredHeights: [BlockKind: CGFloat] = [:]
        private var pageBreakHeights: [Int: CGFloat] = [:]
        private var blockRefreshScheduled = false
        private var isExpandingDeletion = false

        init(_ parent: SanctuaryCanvas) { self.parent = parent }

        // MARK: Install / load

        func install(config: CanvasConfig, document: LettersDocumentController) {
            guard let paper else { return }
            applyGeometry(config)
            appliedConfig = config
            paper.config = config
            load(document: document, config: config, resetUndo: true)
            paper.relayoutPaper()
            refreshBlocks()
            scrollView?.desk.fit(clipWidth: scrollView?.contentView.bounds.width ?? 0)
        }

        private func load(document: LettersDocumentController, config: CanvasConfig, resetUndo: Bool) {
            guard let paper, let storage = paper.textStorage else { return }
            isApplyingModel = true
            defer { isApplyingModel = false }
            let text = document.rawText
            if let attributed = Self.decodeRich(document.richTextData, matching: text) {
                storage.setAttributedString(attributed)
            } else {
                storage.setAttributedString(NSAttributedString(string: text, attributes: CanvasStyling.baseAttributes(config)))
            }
            paper.typingAttributes = CanvasStyling.baseAttributes(config)
            paper.defaultParagraphStyle = CanvasStyling.paragraphStyle(config)
            syncedText = text
            if resetUndo { paper.undoManager?.removeAllActions() }
        }

        private static func decodeRich(_ data: Data?, matching text: String) -> NSAttributedString? {
            guard let data,
                  let attr = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data),
                  attr.string == text else { return nil }
            return attr
        }

        // MARK: Model → view (only when something *other than the user's typing* changed the model)

        func syncModelIntoView(document: LettersDocumentController) {
            guard let paper, let storage = paper.textStorage else { return }
            let modelText = document.rawText
            guard modelText != syncedText else { return }

            isApplyingModel = true
            defer { isApplyingModel = false }

            if let rich = Self.decodeRich(document.richTextData, matching: modelText) {
                // Whole-document replacement (open, new, history restore).
                storage.setAttributedString(rich)
                paper.undoManager?.removeAllActions()
            } else {
                // Programmatic edit (insert TOC, find & replace, AI). Replace only the changed span so every
                // other run keeps its formatting, and register it with the text view's undo stack.
                let old = storage.string as NSString
                let new = modelText as NSString
                var prefix = 0
                let maxPrefix = min(old.length, new.length)
                while prefix < maxPrefix && old.character(at: prefix) == new.character(at: prefix) { prefix += 1 }
                var suffix = 0
                let maxSuffix = min(old.length, new.length) - prefix
                while suffix < maxSuffix && old.character(at: old.length - 1 - suffix) == new.character(at: new.length - 1 - suffix) { suffix += 1 }
                let oldRange = NSRange(location: prefix, length: old.length - prefix - suffix)
                let replacement = new.substring(with: NSRange(location: prefix, length: new.length - prefix - suffix))
                let caret = paper.selectedRange()
                if paper.shouldChangeText(in: oldRange, replacementString: replacement) {
                    storage.replaceCharacters(in: oldRange, with: replacement)
                    paper.didChangeText()
                }
                let end = (paper.string as NSString).length
                paper.setSelectedRange(NSRange(location: min(caret.location, end), length: 0))
            }
            syncedText = modelText
            paper.relayoutPaper()
            refreshBlocks()
        }

        // MARK: Config

        func applyConfig(_ config: CanvasConfig) {
            guard let paper, config != appliedConfig else { return }
            let old = appliedConfig
            appliedConfig = config
            paper.config = config

            if old?.geometry != config.geometry { applyGeometry(config) }

            if let storage = paper.textStorage {
                isApplyingModel = true
                CanvasStyling.restyle(storage, from: old, to: config)
                if storage.length == 0 { paper.typingAttributes = CanvasStyling.baseAttributes(config) }
                paper.defaultParagraphStyle = CanvasStyling.paragraphStyle(config)
                isApplyingModel = false
            }
            paper.relayoutPaper()
            refreshBlocks()
            scrollView?.desk.fit(clipWidth: scrollView?.contentView.bounds.width ?? 0)
            paper.needsDisplay = true
        }

        private func applyGeometry(_ config: CanvasConfig) {
            guard let paper else { return }
            let g = config.geometry
            paper.textContainerInset = NSSize(width: g.margins.left, height: g.margins.top)
            paper.textContainer?.size = NSSize(width: g.containerWidth, height: CGFloat.greatestFiniteMagnitude)
            paper.geometryDidChange()
            paper.setFrameSize(NSSize(width: g.sheetSize.width, height: max(paper.frame.height, g.sheetSize.height)))
        }

        func paperDidResize() {
            scrollView?.desk.fit(clipWidth: scrollView?.contentView.bounds.width ?? 0)
        }

        func magnificationChanged(_ value: Double) {
            if abs(parent.zoom - value) > 0.001 { parent.zoom = value }
        }

        // MARK: Comments & revisions (cheap change detection, applied only when they actually changed)

        func applyAnnotations(document: LettersDocumentController, hoveredCommentId: UUID?) {
            guard let paper, let storage = paper.textStorage else { return }
            let notesKey: [AnyHashable] = [document.sideNotes.count, document.sideNotes.filter { $0.isResolved }.count, hoveredCommentId]
            if notesKey != lastNotesKey {
                lastNotesKey = notesKey
                isApplyingModel = true
                CanvasStyling.applyCommentHighlights(to: storage, document: document, hoveredCommentId: hoveredCommentId)
                isApplyingModel = false
            }
            if document.revisions.count != lastRevisionCount {
                lastRevisionCount = document.revisions.count
                isApplyingModel = true
                CanvasStyling.applyRevisionHighlights(to: storage, document: document)
                isApplyingModel = false
            }
        }

        // MARK: View → model

        public func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
            if !isApplyingModel, !isExpandingDeletion, let hit = markers.first(where: { Self.touches($0.range, range) }) {
                // A block is atomic: deleting any part of its marker removes the block, typing inside it is ignored.
                guard (replacementString ?? "").isEmpty else { return false }
                isExpandingDeletion = true
                defer { isExpandingDeletion = false }
                textView.insertText("", replacementRange: hit.range)
                return false
            }
            guard !isApplyingModel, parent.document.isTrackChangesEnabled else { return true }
            let doc = parent.document
            let ns = textView.string as NSString
            let replacement = replacementString ?? ""
            guard range.location + range.length <= ns.length else { return true }

            if range.length > 0 && replacement.isEmpty {
                doc.recordRevision(kind: .deletion, text: "", originalText: ns.substring(with: range), rangeLocation: range.location, pageIndex: nil)
            } else if range.length == 0 && !replacement.isEmpty {
                doc.recordRevision(kind: .insertion, text: replacement, originalText: nil, rangeLocation: range.location, pageIndex: nil)
            } else if range.length > 0 {
                doc.recordRevision(kind: .insertion, text: replacement, originalText: ns.substring(with: range), rangeLocation: range.location, pageIndex: nil)
            }
            return true
        }

        public func textDidChange(_ notification: Notification) {
            guard !isApplyingModel, let paper else { return }
            // The text view is the source of truth while typing: copy the string out (cheap) and
            // defer the expensive rich-text archive until typing pauses.
            let text = paper.string
            syncedText = text
            if parent.document.rawText != text { parent.document.rawText = text }
            layoutAfterEdit()
            scheduleRichSync()
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingModel, !selectionPublishPending else { return }
            selectionPublishPending = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.selectionPublishPending = false
                guard let paper = self.paper else { return }
                let range = paper.selectedRange()
                let ns = paper.string as NSString
                let selected = range.length > 0 && range.location + range.length <= ns.length ? ns.substring(with: range) : ""
                let attrs = self.parent.controller.currentSelectionAttributes() ?? EditorSelectionAttributes()
                self.parent.onSelectionChange(SelectionSnapshot(range: range, text: selected, attributes: attrs))
            }
        }

        // MARK: Blocks

        private static func touches(_ marker: NSRange, _ edit: NSRange) -> Bool {
            if edit.length == 0 { return edit.location > marker.location && edit.location < marker.location + marker.length }
            return NSIntersectionRange(marker, edit).length > 0
        }

        fileprivate func reservedHeight(for kind: BlockKind, paragraphStart: Int) -> CGFloat {
            if kind.isPageBreak { return pageBreakHeights[paragraphStart] ?? kind.provisionalHeight }
            return (measuredHeights[kind] ?? kind.provisionalHeight) + 12
        }

        /// Rect (text-container coordinates) of the first *line* of the paragraph at `offset`.
        /// A paragraph's fragment frame also contains any seam it jumped over, so only the line is trustworthy.
        private func fragmentFrame(at offset: Int) -> CGRect? {
            guard let tlm = paper?.textLayoutManager, let cm = tlm.textContentManager,
                  let location = cm.location(cm.documentRange.location, offsetBy: offset),
                  let fragment = tlm.textLayoutFragment(for: location),
                  let line = fragment.textLineFragments.first else { return nil }
            let origin = fragment.layoutFragmentFrame.origin
            return CGRect(
                x: origin.x + line.typographicBounds.minX,
                y: origin.y + line.typographicBounds.minY,
                width: line.typographicBounds.width,
                height: line.typographicBounds.height
            )
        }

        private func invalidateParagraph(at range: NSRange) {
            guard let storage = paper?.textStorage, range.location + range.length <= storage.length else { return }
            let paragraph = (storage.string as NSString).paragraphRange(for: range)
            isApplyingModel = true
            storage.edited(.editedAttributes, range: paragraph, changeInLength: 0)
            isApplyingModel = false
        }

        func blockHeightChanged(_ kind: BlockKind, _ height: CGFloat) {
            guard abs((measuredHeights[kind] ?? 0) - height) > 1 else { return }
            measuredHeights[kind] = height
            guard !blockRefreshScheduled else { return }
            blockRefreshScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.blockRefreshScheduled = false
                self.refreshBlocks()
            }
        }

        /// Keeps one hosted view per marker, reserves exactly the space each needs, and pins the view to its line.
        func refreshBlocks(depth: Int = 0) {
            guard let paper, let config = appliedConfig else { return }
            markers = BlockMarker.scan(paper.string)
            if markers.isEmpty && hosts.isEmpty { return }

            // 1. Hosted views: create what is missing, drop what is gone.
            var occurrence: [BlockKind: Int] = [:]
            var live: [String: BlockMarker] = [:]
            for marker in markers where marker.kind.hasHostedView {
                let n = occurrence[marker.kind, default: 0]
                occurrence[marker.kind] = n + 1
                live["\(marker.kind)#\(n)"] = marker
            }
            for (key, host) in hosts where live[key] == nil {
                host.removeFromSuperview()
                hosts[key] = nil
            }
            let g = config.geometry
            for (key, marker) in live where hosts[key] == nil {
                let host = BlockHostingView(rootView: parent.blockContent(marker.kind))
                host.setFrameSize(NSSize(width: g.containerWidth, height: marker.kind.provisionalHeight))
                host.onHeightChange = { [weak self] height in self?.blockHeightChanged(marker.kind, height) }
                paper.addSubview(host)
                hosts[key] = host
                host.layoutSubtreeIfNeeded()
                host.reportHeight()
            }

            // 2. Reserve space: compare what layout gave each marker line with what it needs.
            var needsRelayout = false
            for marker in markers {
                guard let frame = fragmentFrame(at: marker.range.location) else { continue }
                let desired: CGFloat
                if marker.kind.isPageBreak {
                    let top = frame.minY + g.margins.top
                    let page = g.pageIndex(atPaperY: top)
                    let contentTop = CGFloat(page) * g.sheetSize.height + g.margins.top
                    let contentBottom = CGFloat(page + 1) * g.sheetSize.height - g.margins.bottom
                    // A break at the very top of a page must not burn a whole blank page.
                    desired = top - contentTop < 2 ? marker.kind.provisionalHeight : max(marker.kind.provisionalHeight, contentBottom - top - 4)
                    if abs((pageBreakHeights[marker.range.location] ?? -1) - desired) > 0.5 {
                        pageBreakHeights[marker.range.location] = desired
                        invalidateParagraph(at: marker.range)
                        needsRelayout = true
                    }
                } else {
                    desired = reservedHeight(for: marker.kind, paragraphStart: marker.range.location)
                    if abs(frame.height - desired) > 1.5 {
                        invalidateParagraph(at: marker.range)
                        needsRelayout = true
                    }
                }
            }
            if needsRelayout && depth < 4 {
                paper.relayoutPaper()
                refreshBlocks(depth: depth + 1)
                return
            }

            // 3. Pin each view to its reserved line.
            for (key, marker) in live {
                guard let host = hosts[key], let frame = fragmentFrame(at: marker.range.location) else { continue }
                let height = max(8, min(frame.height - 12, measuredHeights[marker.kind] ?? marker.kind.provisionalHeight))
                let target = NSRect(
                    x: paper.textContainerInset.width,
                    y: frame.minY + paper.textContainerInset.height + 6,
                    width: g.containerWidth,
                    height: height
                )
                if host.frame != target { host.frame = target }
            }
        }

        // MARK: Layout scheduling

        private var deferredLayoutWork: DispatchWorkItem?

        /// Re-measuring the paper after an edit is cheap near the end of a document and for ordinary lengths,
        /// but with page seams TextKit re-flows every later page, which grows with document length.
        /// Past ~40 pages, edits far from the end coalesce into one measure when typing pauses.
        private func layoutAfterEdit() {
            guard let paper else { return }
            let length = (paper.string as NSString).length
            let farFromEnd = length - paper.selectedRange().location > 4000
            if paper.pageCount > 40 && farFromEnd {
                deferredLayoutWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    guard let self, let paper = self.paper else { return }
                    paper.relayoutPaper()
                    self.refreshBlocks()
                }
                deferredLayoutWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
            } else {
                deferredLayoutWork?.cancel()
                paper.relayoutPaper()
                refreshBlocks()
            }
        }

        // MARK: Rich text persistence

        private func scheduleRichSync() {
            richSyncWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.flushRichText() }
            richSyncWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        }

        /// Archives the live attributed string into the model. Called on a typing pause and
        /// synchronously before anything reads the model (save, export, snapshot).
        func flushRichText() {
            richSyncWork?.cancel()
            richSyncWork = nil
            guard let storage = paper?.textStorage else { return }
            let copy = NSAttributedString(attributedString: storage)
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: copy, requiringSecureCoding: false) {
                parent.document.richTextData = data
            }
            if parent.document.rawText != copy.string { parent.document.rawText = copy.string }
        }
    }
}

// MARK: - Block paragraphs: reserve space and hide the marker text without touching the stored string

extension SanctuaryCanvas.Coordinator: @preconcurrency NSTextContentStorageDelegate {
    public func textContentStorage(_ textContentStorage: NSTextContentStorage, textParagraphWith range: NSRange) -> NSTextParagraph? {
        guard range.length > 0, let storage = textContentStorage.textStorage else { return nil }
        let source = storage.attributedSubstring(from: range)
        let text = source.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("[[") || text.hasPrefix("---"), let kind = BlockKind(marker: text) else { return nil }

        let display = NSMutableAttributedString(attributedString: source)
        let whole = NSRange(location: 0, length: display.length)
        let height = reservedHeight(for: kind, paragraphStart: range.location)
        let style = ((display.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        style.minimumLineHeight = height
        style.maximumLineHeight = height
        style.paragraphSpacing = 0
        style.paragraphSpacingBefore = 0
        display.addAttribute(.paragraphStyle, value: style, range: whole)
        display.addAttribute(.foregroundColor, value: NSColor.clear, range: whole)
        display.removeAttribute(.backgroundColor, range: whole)
        display.removeAttribute(.underlineStyle, range: whole)
        return NSTextParagraph(attributedString: display)
    }
}

// MARK: - Typography & annotation styling

@MainActor
enum CanvasStyling {
    static let defaultTextColor = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    static let commentHighlightKey = NSAttributedString.Key("StudioCommentHighlightKey")
    static let revisionHighlightKey = NSAttributedString.Key("StudioRevisionHighlightKey")

    static func nsAlignment(_ a: TextAlignment) -> NSTextAlignment {
        switch a {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        }
    }

    static func paragraphStyle(_ c: CanvasConfig) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = nsAlignment(c.alignment)
        style.lineHeightMultiple = c.lineSpacing
        style.paragraphSpacing = c.paragraphSpacing
        style.paragraphSpacingBefore = c.paragraphSpacing * 0.5
        if c.hangingIndent > 0 {
            style.headIndent = c.hangingIndent
            style.firstLineHeadIndent = 0
        }
        return style
    }

    static func baseAttributes(_ c: CanvasConfig) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: resolveFontNamed(family: c.fontFamily, size: c.fontSize, bold: false, italic: false),
            .foregroundColor: defaultTextColor,
            .paragraphStyle: paragraphStyle(c)
        ]
        if c.kern != 0 { attrs[.kern] = c.kern }
        return attrs
    }

    /// Applies only what changed between two configs, so a user's local formatting
    /// (a bold heading, a different font on one quote) is never flattened by an unrelated tweak.
    static func restyle(_ storage: NSTextStorage, from old: CanvasConfig?, to new: CanvasConfig) {
        let full = NSRange(location: 0, length: storage.length)
        guard full.length > 0, let old else { return }

        let familyChanged = old.fontFamily != new.fontFamily
        let scale: CGFloat = (old.fontSize > 0 && old.fontSize != new.fontSize) ? new.fontSize / old.fontSize : 1
        let paragraphChanged = old.lineSpacing != new.lineSpacing || old.paragraphSpacing != new.paragraphSpacing
            || old.alignment != new.alignment || old.hangingIndent != new.hangingIndent
        let kernChanged = old.kern != new.kern
        guard familyChanged || scale != 1 || paragraphChanged || kernChanged else { return }

        storage.beginEditing()
        storage.enumerateAttributes(in: full, options: []) { attrs, range, _ in
            var updated = attrs

            if familyChanged || scale != 1, let font = attrs[.font] as? NSFont {
                if familyChanged {
                    let traits = font.fontDescriptor.symbolicTraits
                    updated[.font] = resolveFontNamed(
                        family: new.fontFamily,
                        size: font.pointSize * scale,
                        bold: traits.contains(.bold),
                        italic: traits.contains(.italic)
                    )
                } else {
                    updated[.font] = NSFontManager.shared.convert(font, toSize: font.pointSize * scale)
                }
            }

            if paragraphChanged {
                let style = ((attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                style.lineHeightMultiple = new.lineSpacing
                style.paragraphSpacing = new.paragraphSpacing
                style.paragraphSpacingBefore = new.paragraphSpacing * 0.5
                if old.alignment != new.alignment { style.alignment = nsAlignment(new.alignment) }
                if old.hangingIndent != new.hangingIndent {
                    style.headIndent = new.hangingIndent
                    style.firstLineHeadIndent = 0
                }
                updated[.paragraphStyle] = style
            }

            if kernChanged {
                if new.kern != 0 { updated[.kern] = new.kern } else { updated.removeValue(forKey: .kern) }
            }
            storage.setAttributes(updated, range: range)
        }
        storage.endEditing()
    }

    static func applyRevisionHighlights(to storage: NSTextStorage, document: LettersDocumentController) {
        guard storage.length > 0 else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.enumerateAttribute(revisionHighlightKey, in: full, options: []) { value, range, _ in
            guard value != nil else { return }
            storage.removeAttribute(revisionHighlightKey, range: range)
            storage.removeAttribute(.underlineStyle, range: range)
            storage.removeAttribute(.underlineColor, range: range)
        }
        if document.isTrackChangesEnabled {
            let text = storage.string as NSString
            for rev in document.revisions where rev.kind == .insertion && !rev.text.isEmpty {
                let length = (rev.text as NSString).length
                var target: NSRange?
                if let loc = rev.rangeLocation, loc + length <= text.length {
                    target = NSRange(location: loc, length: length)
                } else {
                    let found = text.range(of: rev.text)
                    if found.location != NSNotFound { target = found }
                }
                guard let range = target, range.location + range.length <= storage.length else { continue }
                storage.addAttribute(revisionHighlightKey, value: rev.id.uuidString, range: range)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                storage.addAttribute(.underlineColor, value: NSColor.systemGreen, range: range)
            }
        }
        storage.endEditing()
    }

    static func applyCommentHighlights(to storage: NSTextStorage, document: LettersDocumentController, hoveredCommentId: UUID?) {
        guard storage.length > 0 else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.enumerateAttribute(commentHighlightKey, in: full, options: []) { value, range, _ in
            guard value != nil else { return }
            storage.removeAttribute(commentHighlightKey, range: range)
            storage.removeAttribute(.backgroundColor, range: range)
            storage.removeAttribute(.underlineStyle, range: range)
            storage.removeAttribute(.underlineColor, range: range)
        }
        let text = storage.string as NSString
        for note in document.sideNotes where !note.isResolved {
            var target: NSRange?
            if let loc = note.rangeLocation, let len = note.rangeLength, len > 0, loc + len <= text.length {
                target = NSRange(location: loc, length: len)
            } else if let anchor = note.anchorText, !anchor.isEmpty {
                let found = text.range(of: anchor)
                if found.location != NSNotFound { target = found }
            }
            guard let range = target, range.location + range.length <= storage.length else { continue }
            storage.addAttribute(commentHighlightKey, value: note.id.uuidString, range: range)
            if hoveredCommentId == note.id {
                storage.addAttribute(.backgroundColor, value: NSColor.systemOrange.withAlphaComponent(0.38), range: range)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                storage.addAttribute(.underlineColor, value: NSColor.systemOrange, range: range)
            } else {
                storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.20), range: range)
            }
        }
        storage.endEditing()
    }
}
