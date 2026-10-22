import XCTest
@testable import LettersKit

final class LettersKitTests: XCTestCase {
    func testDocumentModelSerialization() throws {
        var doc = DocumentModel(title: "Academic Paper")
        doc.blocks.append(.heading(level: .heading1, runs: [TextRun(text: "Introduction", bold: true)]))
        doc.blocks.append(.paragraph(runs: [
            TextRun(text: "This document engine uses TextKit 2 and Rust."),
            TextRun(text: "(Smith, 2024)", citation: CitationReference(sourceId: "smith2024", pinPoint: "p. 10"))
        ], alignment: "left"))

        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(DocumentModel.self, from: data)

        XCTAssertEqual(decoded.title, "Academic Paper")
        XCTAssertEqual(decoded.blocks.count, 2)
    }

    func testCoreBridgeCitationFormatting() {
        let source = Source(
            id: "smith2024",
            sourceType: .journalArticle,
            authors: ["Smith, J.", "Doe, A."],
            year: 2024,
            title: "Document Core Architecture"
        )
        let reference = CitationReference(sourceId: "smith2024", pinPoint: "p. 42")

        let rendered = CoreBridge.shared.renderCitation(source: source, reference: reference, style: .apa7)
        XCTAssertFalse(rendered.isEmpty)
    }

    func testStyleLinting() {
        let text = "As we all know, it is obvious that this is clearly important."
        let issues = CoreBridge.shared.lint(text: text, profile: "academic")
        XCTAssertNotNil(issues)
        XCTAssertGreaterThan(issues.count, 0)
        let first = issues[0]
        XCTAssertFalse(first.ruleId.isEmpty)
        XCTAssertFalse(first.message.isEmpty)
    }

    func testMarkdownTableDocxExport() {
        let md = """
        # Financial Summary
        Here is the quarterly breakdown:

        | Quarter | Revenue |
        | --- | --- |
        | Q1 | 1500 |
        | Q2 | 2500 |
        """
        let docxData = CoreBridge.shared.exportDocx(title: "Financial Summary", text: md)
        XCTAssertNotNil(docxData)
        XCTAssertGreaterThan(docxData?.count ?? 0, 100)
    }
}
