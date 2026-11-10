import XCTest
import Combine
import LettersKit
@testable import LettersApp

/// Guards the "typing must not re-render the editor shell" contract of `EditorStateModels.swift`.
@MainActor
final class EditorObservationTests: XCTestCase {
    private var bag = Set<AnyCancellable>()

    override func tearDown() {
        bag.removeAll()
        super.tearDown()
    }

    func testEditorContextNeverPublishesWhenDocumentChanges() {
        let context = EditorContext()
        var fired = 0
        context.objectWillChange.sink { _ in fired += 1 }.store(in: &bag)

        context.document.rawText = "typing…"
        context.document.title = "Renamed"
        context.caret.range = NSRange(location: 3, length: 0)
        context.format.isBold = true
        context.lintIssues = []

        XCTAssertEqual(fired, 0, "The shell's StateObject must stay silent; regions observe their own state.")
    }

    func testToolbarSliceIgnoresTypingButTracksFormatting() async {
        let doc = LettersDocumentController()
        let slice = DocumentSlice(doc) { StudioToolbarSlice($0) }
        var changes = 0
        slice.objectWillChange.sink { _ in changes += 1 }.store(in: &bag)

        for i in 0..<20 { doc.rawText += "word\(i) " }
        await drainMainQueue()
        XCTAssertEqual(changes, 0, "Body text edits must not invalidate the toolbar.")

        doc.fontSize = doc.fontSize + 2
        await drainMainQueue()
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(slice.value.fontSize, doc.fontSize)

        doc.isTrackChangesEnabled.toggle()
        await drainMainQueue()
        XCTAssertEqual(changes, 2)
        XCTAssertEqual(slice.value.isTrackChangesEnabled, doc.isTrackChangesEnabled)
    }

    func testRightPaneToggleClosesOpenPaneAndReplacesOthers() {
        XCTAssertEqual(EditorRightPane.inspector.toggled(.inspector), .none)
        XCTAssertEqual(EditorRightPane.inspector.toggled(.assistant), .assistant)
        XCTAssertEqual(EditorRightPane.none.toggled(.comments), .comments)
    }

    func testDocumentBindingReadsAndWritesThroughController() {
        let doc = LettersDocumentController()
        let binding = doc.binding(\.rawText)
        binding.wrappedValue = "hello"
        XCTAssertEqual(doc.rawText, "hello")
        doc.rawText = "world"
        XCTAssertEqual(binding.wrappedValue, "world")
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { cont in
            DispatchQueue.main.async { DispatchQueue.main.async { cont.resume() } }
        }
    }
}
