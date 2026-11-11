import XCTest
import SwiftUI
import AppKit
import PDFKit
import LettersKit
@testable import LettersApp

// MARK: - Pure geometry

final class SheetGeometryTests: XCTestCase {
    private let letter = SheetGeometry(sheetSize: CGSize(width: 612, height: 792), margins: PageMargins())

    func testPrintableColumnExcludesMargins() {
        XCTAssertEqual(letter.containerWidth, 612 - 144)
        XCTAssertEqual(letter.printableHeight, 792 - 144)
    }

    func testPageCountGrowsOnlyWhenTextCrossesBottomMargin() {
        XCTAssertEqual(letter.pageCount(usedHeight: 0), 1)
        XCTAssertEqual(letter.pageCount(usedHeight: letter.printableHeight), 1)
        XCTAssertEqual(letter.pageCount(usedHeight: letter.printableHeight + 1), 2)
    }

    func testOneSeamBandPerPageBoundary() {
        XCTAssertTrue(letter.seamBands(pageCount: 1).isEmpty)
        let bands = letter.seamBands(pageCount: 3)
        XCTAssertEqual(bands.count, 2)
        // Band k covers bottom margin of page k and top margin of page k+1, in container coordinates.
        XCTAssertEqual(bands[0].minY, 792 - 144)
        XCTAssertEqual(bands[0].height, 144)
        XCTAssertEqual(bands[1].minY, 2 * 792 - 144)
    }

    func testHeaderFooterHitBands() {
        XCTAssertEqual(letter.headerFooterTarget(atPaperY: 10), .header)
        XCTAssertNil(letter.headerFooterTarget(atPaperY: 400))
        XCTAssertEqual(letter.headerFooterTarget(atPaperY: 792 - 10), .footer)
        XCTAssertEqual(letter.headerFooterTarget(atPaperY: 792 + 10), .header)
    }
}

// MARK: - The live canvas, hosted in a real window

@MainActor
private final class Harness {
    let window: NSWindow
    let host: NSHostingView<AnyView>
    let document: LettersDocumentController
    let controller = EditorActionController()
    var zoom: Double = 1.0
    var config: CanvasConfig
    var requestedHeaderFooterEdits: [HeaderFooterTarget] = []

    var paper: PaperTextView { controller.textView! }
    var scroll: NSScrollView { paper.enclosingScrollView! }

    init(text: String = "", size: CGSize = CGSize(width: 1000, height: 1000)) {
        document = LettersDocumentController(rawText: text)
        config = CanvasConfig(
            geometry: SheetGeometry(sheetSize: CGSize(width: 612, height: 792), margins: PageMargins()),
            showMarginGuides: false
        )
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        host = NSHostingView(rootView: AnyView(EmptyView()))
        window.contentView = host
        render()
        window.makeKeyAndOrderFront(nil)
        pump()
    }

    func render() {
        let binding = Binding<Double>(get: { self.zoom }, set: { self.zoom = $0 })
        host.rootView = AnyView(
            SanctuaryCanvas(
                document: document,
                controller: controller,
                config: config,
                zoom: binding,
                onSelectionChange: { _ in },
                onEditHeaderFooter: { [unowned self] in self.requestedHeaderFooterEdits.append($0) },
                blockContent: { [document] kind in AnyView(DocumentBlockView(kind: kind, document: document, onToast: { _ in })) }
            )
            .frame(width: window.contentRect(forFrameRect: window.frame).width, height: window.contentRect(forFrameRect: window.frame).height)
        )
        host.layoutSubtreeIfNeeded()
    }

    func pump(_ seconds: TimeInterval = 0.25) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        host.layoutSubtreeIfNeeded()
    }

    /// Window-space point for a location on the paper.
    func windowPoint(paperX x: CGFloat, paperY y: CGFloat) -> NSPoint {
        paper.convert(NSPoint(x: x, y: y), to: nil)
    }

    /// What AppKit would deliver a click at that paper location to (window base coordinates → deepest view).
    func viewReceivingClick(paperX x: CGFloat, paperY y: CGFloat) -> NSView? {
        window.contentView?.superview?.hitTest(windowPoint(paperX: x, paperY: y))
    }

    /// Performs a real click through `NSTextView.mouseDown` (its tracking loop needs the mouse-up queued first).
    @discardableResult
    func click(paperX x: CGFloat, paperY y: CGFloat, count: Int = 1) -> Int {
        let p = windowPoint(paperX: x, paperY: y)
        let t = ProcessInfo.processInfo.systemUptime
        let down = NSEvent.mouseEvent(with: .leftMouseDown, location: p, modifierFlags: [], timestamp: t, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: count, pressure: 1)!
        let up = NSEvent.mouseEvent(with: .leftMouseUp, location: p, modifierFlags: [], timestamp: t, windowNumber: window.windowNumber, context: nil, eventNumber: 2, clickCount: count, pressure: 0)!
        window.postEvent(up, atStart: false)
        (viewReceivingClick(paperX: x, paperY: y) ?? paper).mouseDown(with: down)
        return paper.selectedRange().location
    }

    func scrollToTop() {
        let clip = scroll.contentView
        clip.scroll(to: .zero)
        scroll.reflectScrolledClipView(clip)
        pump(0.05)
    }
}

@MainActor
final class SanctuaryCanvasTests: XCTestCase {

    func testLaunchPutsCaretOnThePageWithoutAClick() {
        let h = Harness()
        XCTAssertTrue(h.window.firstResponder === h.paper, "The first keystroke must land in the document.")
    }

    func testEverySpotOnTheSheetHitTestsToTheTextView() {
        let h = Harness(text: "First line")
        let probes: [(String, CGFloat, CGFloat)] = [
            ("line 1", 100, 90), ("top margin", 300, 20), ("left margin", 10, 300),
            ("right margin", 600, 300), ("empty area below text", 300, 600), ("bottom margin", 300, 770)
        ]
        for (name, x, y) in probes {
            let hit = h.viewReceivingClick(paperX: x, paperY: y)
            XCTAssertTrue(hit === h.paper || hit?.isDescendant(of: h.paper) == true, "\(name) is not owned by the text view (hit: \(String(describing: hit)))")
        }
    }

    func testClickingAnywhereOnThePagePlacesTheCaretNearestTheClick() {
        let h = Harness(text: "Hello world\nSecond line")
        let length = ("Hello world\nSecond line" as NSString).length
        XCTAssertEqual(h.click(paperX: 300, paperY: 10), 11, "Top margin → end of line 1 (the nearest line).")
        XCTAssertEqual(h.click(paperX: 10, paperY: 90), 0, "Left margin → start of line 1.")
        XCTAssertEqual(h.click(paperX: 100, paperY: 80), 4, "Directly on line 1 → the character under the pointer.")
        XCTAssertEqual(h.click(paperX: 300, paperY: 600), length, "Blank paper below the text → end of document.")
        XCTAssertEqual(h.click(paperX: 300, paperY: 780), length, "Bottom margin → end of document.")
        XCTAssertTrue(h.window.firstResponder === h.paper)
    }

    func testTypingReachesTheModelImmediately() {
        let h = Harness()
        h.paper.insertText("Hello", replacementRange: h.paper.selectedRange())
        XCTAssertEqual(h.document.rawText, "Hello")
        h.paper.insertText(" world", replacementRange: h.paper.selectedRange())
        XCTAssertEqual(h.document.rawText, "Hello world")
    }

    func testRerenderDuringTypingDoesNotClobberText() {
        let h = Harness()
        h.paper.insertText("typed but not yet archived", replacementRange: h.paper.selectedRange())
        for _ in 0..<5 { h.render() }
        XCTAssertEqual(h.paper.string, "typed but not yet archived")
        XCTAssertEqual(h.document.rawText, h.paper.string)
    }

    func testExternalModelChangeUpdatesTheTextAndKeepsFormatting() {
        let h = Harness(text: "Alpha beta gamma")
        h.paper.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemRed, range: NSRange(location: 0, length: 5))
        h.document.rawText = "Alpha BETA gamma"
        h.render(); h.pump(0.1)
        XCTAssertEqual(h.paper.string, "Alpha BETA gamma")
        let color = h.paper.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, NSColor.systemRed, "Only the changed span may be touched.")
    }

    func testFlushArchivesTheLiveTextIntoTheModel() throws {
        let h = Harness()
        h.paper.insertText("Rich", replacementRange: h.paper.selectedRange())
        h.paper.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemPink, range: NSRange(location: 0, length: 4))
        let bundle = h.document.createBundle()
        let archived = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: XCTUnwrap(bundle.richTextData))
        XCTAssertEqual(archived?.string, "Rich", "Saving must archive the live text, not a stale copy.")
        XCTAssertEqual(archived?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, NSColor.systemPink)
    }

    func testLongTextFlowsOntoNewSheetsAndSkipsEverySeam() {
        let paragraph = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 6)
        let text = Array(repeating: paragraph, count: 40).joined(separator: "\n")
        let h = Harness(text: text)
        h.paper.relayoutPaper(); h.pump()

        let g = h.config.geometry
        XCTAssertGreaterThan(h.paper.pageCount, 2)
        XCTAssertEqual(h.paper.frame.height, CGFloat(h.paper.pageCount) * g.sheetSize.height, "The paper is always a whole number of sheets.")

        let bands = g.seamBands(pageCount: h.paper.pageCount)
        guard let tlm = h.paper.textLayoutManager else { return XCTFail("TextKit 2 layout manager expected") }
        tlm.ensureLayout(for: tlm.documentRange)
        var worst: CGFloat = 0
        var lines = 0
        tlm.enumerateTextLayoutFragments(from: tlm.documentRange.location, options: [.ensuresLayout]) { fragment in
            for line in fragment.textLineFragments {
                let top = fragment.layoutFragmentFrame.minY + line.typographicBounds.minY
                let bottom = top + line.typographicBounds.height
                lines += 1
                for band in bands where bottom > band.minY + 0.5 && top < band.maxY - 0.5 {
                    worst = max(worst, min(bottom, band.maxY) - max(top, band.minY))
                }
            }
            return true
        }
        XCTAssertGreaterThan(lines, 100)
        XCTAssertEqual(worst, 0, accuracy: 0.5, "No text line may sit inside a page seam (margins would be violated).")
    }

    func testEditingEarlyTextReflowsLaterPagesWithoutOverlap() {
        let paragraph = String(repeating: "Lorem ipsum dolor sit amet. ", count: 12)
        let h = Harness(text: Array(repeating: paragraph, count: 30).joined(separator: "\n"))
        h.paper.relayoutPaper(); h.pump()
        // Insert several paragraphs at the very top, as a writer would.
        h.paper.setSelectedRange(NSRange(location: 0, length: 0))
        h.paper.insertText(String(repeating: "New opening paragraph.\n", count: 15), replacementRange: NSRange(location: 0, length: 0))
        h.pump()

        let g = h.config.geometry
        let bands = g.seamBands(pageCount: h.paper.pageCount)
        let tlm = h.paper.textLayoutManager!
        tlm.ensureLayout(for: tlm.documentRange)
        var overlaps = 0
        tlm.enumerateTextLayoutFragments(from: tlm.documentRange.location, options: [.ensuresLayout]) { fragment in
            for line in fragment.textLineFragments {
                let top = fragment.layoutFragmentFrame.minY + line.typographicBounds.minY
                let bottom = top + line.typographicBounds.height
                if bands.contains(where: { bottom > $0.minY + 0.5 && top < $0.maxY - 0.5 }) { overlaps += 1 }
            }
            return true
        }
        XCTAssertEqual(overlaps, 0)
    }

    func testZoomUsesNativeMagnificationAndKeepsClicksAccurate() {
        let h = Harness(text: "Hello world\nSecond line")
        h.zoom = 1.5
        h.render(); h.pump(0.1)
        XCTAssertEqual(h.scroll.magnification, 1.5, accuracy: 0.001)
        h.scrollToTop()
        // Hit-testing and caret placement stay exact while magnified: AppKit, not a SwiftUI transform, does the scaling.
        let hit = h.viewReceivingClick(paperX: 100, paperY: 80)
        XCTAssertTrue(hit === h.paper || hit?.isDescendant(of: h.paper) == true, "hit: \(String(describing: hit))")
        XCTAssertEqual(h.click(paperX: 100, paperY: 80), 4)
    }

    func testPDFExportContainsTheTypedText() throws {
        let h = Harness(text: "Exported sentence on page one.")
        h.pump()
        let data = try XCTUnwrap(h.paper.exportPDFData())
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(pdf.pageCount, 1)
        XCTAssertTrue(pdf.string?.contains("Exported sentence") == true, "PDF text: \(pdf.string ?? "nil")")
    }

    func testDoubleClickingHeaderOrFooterBandOpensTheEditorWithoutMovingTheCaret() {
        let h = Harness(text: "Body text")
        h.click(paperX: 300, paperY: 100)
        let caret = h.paper.selectedRange().location
        h.click(paperX: 300, paperY: 14, count: 2)
        h.click(paperX: 300, paperY: 792 - 14, count: 2)
        XCTAssertEqual(h.requestedHeaderFooterEdits, [.header, .footer])
        XCTAssertEqual(h.paper.selectedRange().location, caret)
        // A double-click in the body still selects a word, as in any editor.
        h.click(paperX: 100, paperY: 90, count: 2)
        XCTAssertEqual(h.requestedHeaderFooterEdits.count, 2)
    }

    func testListContinuationOnReturn() {
        let h = Harness(text: "• first")
        h.paper.setSelectedRange(NSRange(location: 7, length: 0))
        let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: h.window.windowNumber,
            context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
        )!
        h.paper.keyDown(with: event)
        XCTAssertEqual(h.paper.string, "• first\n• ")
    }
}

// MARK: - Blocks (tables, figures, page breaks) live inside the one text flow

final class BlockMarkerTests: XCTestCase {
    func testMarkerParsing() {
        let id = UUID()
        XCTAssertEqual(BlockKind(marker: "[[table:\(id.uuidString)]]"), .table(id))
        XCTAssertEqual(BlockKind(marker: "[[image:\(id.uuidString)]]"), .image(id))
        XCTAssertEqual(BlockKind(marker: "[[toc]]"), .tableOfContents)
        XCTAssertEqual(BlockKind(marker: "[[bibliography]]"), .bibliography)
        XCTAssertEqual(BlockKind(marker: "---pagebreak---"), .pageBreak)
        XCTAssertNil(BlockKind(marker: "see [[toc]] above"))
        XCTAssertNil(BlockKind(marker: "[[table:not-a-uuid]]"))
    }

    func testScanOnlyMatchesMarkersThatSitOnTheirOwnLine() {
        let id = UUID()
        let text = "Intro mentions [[toc]] inline.\n\n[[table:\(id.uuidString)]]\n\nMid\n---pagebreak---\nEnd"
        let found = BlockMarker.scan(text)
        XCTAssertEqual(found.map(\.kind), [.table(id), .pageBreak])
    }
}

@MainActor
final class BlockLayerTests: XCTestCase {
    private func table() -> StudioTableData {
        StudioTableData(title: "", headers: ["A", "B"], rows: [["1", "2"], ["3", "4"]])
    }

    private func frame(of needle: String, in h: Harness) -> CGRect? {
        let ns = h.paper.string as NSString
        let r = ns.range(of: needle)
        guard r.location != NSNotFound, let tlm = h.paper.textLayoutManager, let cm = tlm.textContentManager,
              let loc = cm.location(cm.documentRange.location, offsetBy: r.location),
              let frag = tlm.textLayoutFragment(for: loc), let line = frag.textLineFragments.first else { return nil }
        // First *line*: a fragment's own frame also spans any page seam the line jumped over.
        return CGRect(x: frag.layoutFragmentFrame.minX, y: frag.layoutFragmentFrame.minY + line.typographicBounds.minY, width: line.typographicBounds.width, height: line.typographicBounds.height)
    }

    func testTableBlockReservesSpaceAndIsPinnedBetweenTheSurroundingParagraphs() throws {
        let t = table()
        let text = "Before the table\n\n[[table:\(t.id.uuidString)]]\n\nAfter the table"
        let h = Harness()
        h.document.tables = [t]
        h.document.rawText = text
        h.render(); h.pump(0.5)

        let hosted = h.paper.subviews.compactMap { $0 as? BlockHostingView }
        XCTAssertEqual(hosted.count, 1, "One hosted view per table marker.")
        let host = try XCTUnwrap(hosted.first)
        let before = try XCTUnwrap(frame(of: "Before the table", in: h))
        let after = try XCTUnwrap(frame(of: "After the table", in: h))
        let inset = h.paper.textContainerInset.height
        XCTAssertGreaterThan(host.frame.minY, before.maxY + inset - 1, "Block starts below the paragraph above it.")
        XCTAssertLessThanOrEqual(host.frame.maxY, after.minY + inset + 1, "Following text is pushed below the block, never under it.")
        XCTAssertGreaterThan(host.frame.height, 30)
    }

    func testBlockIsClickableAndOwnedByItsHostedView() throws {
        let t = table()
        let h = Harness()
        h.document.tables = [t]
        h.document.rawText = "Intro\n\n[[table:\(t.id.uuidString)]]\n\nOutro"
        h.render(); h.pump(0.5)
        let host = try XCTUnwrap(h.paper.subviews.compactMap { $0 as? BlockHostingView }.first)
        let center = NSPoint(x: host.frame.midX, y: host.frame.midY)
        let hit = h.window.contentView?.superview?.hitTest(h.paper.convert(center, to: nil))
        XCTAssertTrue(hit === host || hit?.isDescendant(of: host) == true, "Clicks inside a block must reach the block, got \(String(describing: hit))")
    }

    func testDeletingAnyPartOfAMarkerRemovesTheWholeBlock() {
        let t = table()
        let marker = "[[table:\(t.id.uuidString)]]"
        let h = Harness()
        h.document.tables = [t]
        h.document.rawText = "Intro\n\n\(marker)\n\nOutro"
        h.render(); h.pump(0.3)
        let markerRange = (h.paper.string as NSString).range(of: marker)
        // Backspace one character off the end of the marker.
        h.paper.insertText("", replacementRange: NSRange(location: markerRange.location + markerRange.length - 1, length: 1))
        XCTAssertFalse(h.paper.string.contains("[[table"), "Text: \(h.paper.string)")
        XCTAssertTrue(h.paper.string.contains("Intro") && h.paper.string.contains("Outro"))
        XCTAssertEqual(h.document.rawText, h.paper.string)
    }

    func testTypingInsideAMarkerIsIgnored() {
        let t = table()
        let marker = "[[table:\(t.id.uuidString)]]"
        let h = Harness()
        h.document.tables = [t]
        h.document.rawText = "Intro\n\n\(marker)\n\nOutro"
        h.render(); h.pump(0.3)
        let r = (h.paper.string as NSString).range(of: marker)
        h.paper.insertText("X", replacementRange: NSRange(location: r.location + 4, length: 0))
        XCTAssertTrue(h.paper.string.contains(marker), "The marker must stay intact.")
    }

    func testPageBreakPushesFollowingTextToTheNextSheet() {
        let h = Harness(text: "Page one text\n\n---pagebreak---\n\nPage two text")
        h.pump(0.5)
        h.paper.relayoutPaper(); h.pump(0.2)
        let g = h.config.geometry
        let two = frame(of: "Page two text", in: h)
        let one = frame(of: "Page one text", in: h)
        XCTAssertNotNil(two)
        let twoPaperY = (two?.minY ?? 0) + g.margins.top
        XCTAssertEqual(g.pageIndex(atPaperY: (one?.minY ?? 0) + g.margins.top), 0)
        XCTAssertEqual(g.pageIndex(atPaperY: twoPaperY), 1, "Text after a page break starts on page 2 (y=\(twoPaperY)).")
        XCTAssertEqual(h.paper.pageCount, 2)
    }

    func testPageBreakAtTopOfPageDoesNotAddABlankSheet() {
        let h = Harness(text: "---pagebreak---\n\nOnly text")
        h.pump(0.5)
        h.paper.relayoutPaper(); h.pump(0.2)
        XCTAssertEqual(h.paper.pageCount, 1)
    }

    func testBlockNeverOverlapsAPageSeamWhereverItLands() throws {
        let t = table()
        for lines in stride(from: 14, through: 34, by: 2) {
            let filler = Array(repeating: "Filler line of body text.", count: lines).joined(separator: "\n")
            let h = Harness()
            h.document.tables = [t]
            h.document.rawText = "\(filler)\n\n[[table:\(t.id.uuidString)]]\n\nTail"
            h.render(); h.pump(0.4)
            let host = try XCTUnwrap(h.paper.subviews.compactMap { $0 as? BlockHostingView }.first, "lines=\(lines)")
            let g = h.config.geometry
            for band in g.seamBands(pageCount: h.paper.pageCount) {
                let paperBand = band.offsetBy(dx: 0, dy: g.margins.top)
                XCTAssertFalse(host.frame.maxY > paperBand.minY + 1 && host.frame.minY < paperBand.maxY - 1,
                               "table block overlaps a seam with \(lines) filler lines: host \(host.frame) band \(paperBand)")
            }
        }
    }
}

@MainActor
final class TypingPerformanceTests: XCTestCase {
    private func averageKeystrokeMilliseconds(paragraphs: Int, typeAtFraction: Double) -> (ms: Double, pages: Int) {
        let paragraph = String(repeating: "Writing should feel immediate, whatever the length of the manuscript. ", count: 8)
        let h = Harness(text: Array(repeating: paragraph, count: paragraphs).joined(separator: "\n\n"))
        h.pump(0.5)
        h.paper.relayoutPaper()
        let at = Int(Double((h.paper.string as NSString).length) * typeAtFraction)
        h.paper.setSelectedRange(NSRange(location: at, length: 0))
        let strokes = 60
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<strokes { h.paper.insertText("x", replacementRange: h.paper.selectedRange()) }
        let ms = (CFAbsoluteTimeGetCurrent() - start) / Double(strokes) * 1000
        h.pump(0.4) // let the coalesced layout land, then make sure nothing was lost or left stale
        XCTAssertEqual(h.document.rawText, h.paper.string)
        XCTAssertEqual(h.paper.frame.height, CGFloat(h.paper.pageCount) * 792)
        return (ms, h.paper.pageCount)
    }

    /// Debug build, so numbers are pessimistic; the bound is one 60 Hz frame.
    func testKeystrokeLatencyOnATypicalManuscript() {
        let r = averageKeystrokeMilliseconds(paragraphs: 120, typeAtFraction: 0.5)   // ~40 pages, edit mid-document
        print("PERF \(r.pages) pages, mid-document edit: \(String(format: "%.2f", r.ms)) ms/key")
        XCTAssertLessThan(r.ms, 16)
    }

    func testKeystrokeLatencyOnAVeryLongManuscriptEditedInTheMiddle() {
        let r = averageKeystrokeMilliseconds(paragraphs: 400, typeAtFraction: 0.5)   // ~130 pages
        print("PERF \(r.pages) pages, mid-document edit: \(String(format: "%.2f", r.ms)) ms/key")
        XCTAssertLessThan(r.ms, 16)
    }

    func testKeystrokeLatencyWhenAppendingToAVeryLongManuscript() {
        let r = averageKeystrokeMilliseconds(paragraphs: 400, typeAtFraction: 1.0)
        print("PERF \(r.pages) pages, typing at the end: \(String(format: "%.2f", r.ms)) ms/key")
        XCTAssertLessThan(r.ms, 16)
    }
}
