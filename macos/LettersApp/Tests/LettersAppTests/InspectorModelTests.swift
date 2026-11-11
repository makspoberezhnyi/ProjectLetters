import XCTest
import LettersKit
@testable import LettersApp

// MARK: - Unified inspector: pure logic

final class DocumentAnalyticsTests: XCTestCase {
    func testEmptyTextHasNoMetrics() {
        let a = DocumentAnalytics.compute("")
        XCTAssertEqual(a.words, 0)
        XCTAssertNil(a.gradeLevel)
        XCTAssertEqual(a.readingTimeLabel, "—")
        XCTAssertEqual(a.gradeLabel, "—")
    }

    func testCountsIgnoreLayoutMarkers() {
        let a = DocumentAnalytics.compute("Hello brave world.\n\n[[table:ABC-123]]\n\n---pagebreak---\n\nAgain.")
        XCTAssertEqual(a.words, 4)
        XCTAssertEqual(a.sentences, 2)
    }

    func testShortTextGetsNoGradeLevel() {
        XCTAssertNil(DocumentAnalytics.compute("A short note.").gradeLevel)
    }

    func testSimpleProseScoresLowerThanDenseProse() {
        let simple = String(repeating: "The cat sat on the mat. It was a big red cat. ", count: 6)
        let dense = String(repeating: "Epistemological considerations notwithstanding, institutional methodologies necessitate comprehensive reconsideration of administrative responsibilities. ", count: 4)
        let easy = DocumentAnalytics.compute(simple).gradeLevel
        let hard = DocumentAnalytics.compute(dense).gradeLevel
        XCTAssertNotNil(easy)
        XCTAssertNotNil(hard)
        XCTAssertLessThan(easy!, hard!)
    }

    func testReadingTimeLabels() {
        XCTAssertEqual(DocumentAnalytics(words: 100).readingTimeLabel, "< 1 min")
        XCTAssertEqual(DocumentAnalytics(words: 2300).readingTimeLabel, "10 min")
        XCTAssertEqual(DocumentAnalytics(words: 23_000).readingTimeLabel, "1 hr 40 min")
    }

    func testSyllableHeuristic() {
        XCTAssertEqual(DocumentAnalytics.syllableCount(of: "cat"), 1)
        XCTAssertEqual(DocumentAnalytics.syllableCount(of: "make"), 1)
        XCTAssertEqual(DocumentAnalytics.syllableCount(of: "table"), 2)
        XCTAssertEqual(DocumentAnalytics.syllableCount(of: "reading"), 2)
        XCTAssertGreaterThanOrEqual(DocumentAnalytics.syllableCount(of: "the"), 1)
    }
}

final class InTextCitationTests: XCTestCase {
    private let kuhn = Source(id: "k", sourceType: .book, authors: ["Thomas Kuhn"], year: 1962, title: "Structure")

    func testSurnameHandlesBothNameOrders() {
        XCTAssertEqual(InTextCitation.surname(of: "Thomas Kuhn"), "Kuhn")
        XCTAssertEqual(InTextCitation.surname(of: "Kuhn, Thomas"), "Kuhn")
        XCTAssertEqual(InTextCitation.surname(of: "Plato"), "Plato")
    }

    func testStyleSpecificInTextForms() {
        XCTAssertEqual(InTextCitation.text(for: kuhn, style: .apa7), "(Kuhn, 1962)")
        XCTAssertEqual(InTextCitation.text(for: kuhn, style: .chicagoDate), "(Kuhn 1962)")
        XCTAssertEqual(InTextCitation.text(for: kuhn, style: .mla9), "(Kuhn)")
    }

    func testMissingFieldsFallBackGracefully() {
        let anon = Source(id: "a", title: "Untitled")
        XCTAssertEqual(InTextCitation.text(for: anon, style: .apa7), "(Author, n.d.)")
        let team = Source(id: "t", authors: ["Ada Lovelace", "Charles Babbage"], year: 1843, title: "Notes")
        XCTAssertEqual(InTextCitation.text(for: team, style: .apa7), "(Lovelace et al., 1843)")
    }
}

@MainActor
final class InspectorStateTests: XCTestCase {
    func testPaneMapsToTabsAndBack() {
        for tab in InspectorTab.allCases {
            XCTAssertEqual(EditorRightPane(tab).tab, tab)
        }
        XCTAssertNil(EditorRightPane.none.tab)
        XCTAssertEqual(InspectorTab.allCases.count, 3)
    }

    func testBundleRoundTripsLandscapeAndCommentReplies() throws {
        let doc = LettersDocumentController()
        doc.isLandscape = true
        var note = StudioSideNote(text: "Check this", anchorText: "claim")
        note.replies = [StudioNoteReply(author: "Sam", text: "Done")]
        doc.sideNotes = [note]

        let data = try doc.createBundle().encodeToData()
        let restored = try LettersDocumentBundle.decode(from: data)
        XCTAssertTrue(restored.isLandscape)
        XCTAssertEqual(restored.sideNotes.first?.replies.first?.text, "Done")

        let other = LettersDocumentController()
        other.loadBundle(restored)
        XCTAssertTrue(other.isLandscape)
    }

    func testOldBundlesWithoutNewKeysStillDecode() throws {
        let json = #"{"title":"Old","rawText":"x","sideNotes":[{"id":"7C7A5B4E-62D2-4F57-8C51-0E38C1E2B9D0","text":"hi"}]}"#
        let bundle = try LettersDocumentBundle.decode(from: Data(json.utf8))
        XCTAssertFalse(bundle.isLandscape)
        XCTAssertEqual(bundle.sideNotes.first?.replies.count, 0)
    }

    func testMarginPresetResizesMarginsEverywhere() {
        let doc = LettersDocumentController()
        doc.marginPreset = .narrow
        XCTAssertEqual(doc.margins.left, 36)
        doc.marginPreset = .wide
        XCTAssertEqual(doc.margins.top, 108)
        // Custom keeps whatever was dragged.
        doc.margins.left = 50
        doc.marginPreset = .custom
        XCTAssertEqual(doc.margins.left, 50)
    }

    func testSaveMilestonePinsAndNeverDuplicatesIdenticalState() async {
        let doc = LettersDocumentController()
        await Task.yield()
        doc.rawText = "First draft"
        doc.commitSnapshot(actionName: "Typing")
        let before = doc.historyNodes.count
        doc.saveMilestone()
        // Nothing changed since the last snapshot, so that snapshot is promoted instead of duplicated.
        XCTAssertEqual(doc.historyNodes.count, before)
        let current = doc.currentSnapshotId.flatMap { doc.historyNodes[$0] }
        XCTAssertEqual(current?.isMilestone, true)
        XCTAssertEqual(current?.isPinned, true)
    }
}
