import SwiftUI
import LettersKit

public struct DocumentOutlineView: View {
    @Binding var document: DocumentModel
    @Binding var selectedBlockIndex: Int?

    public init(document: Binding<DocumentModel>, selectedBlockIndex: Binding<Int?>) {
        self._document = document
        self._selectedBlockIndex = selectedBlockIndex
    }

    public var body: some View {
        List(selection: $selectedBlockIndex) {
            Section("Document Structure") {
                ForEach(Array(document.blocks.enumerated()), id: \.offset) { index, block in
                    switch block {
                    case .heading(let level, let runs):
                        HStack(spacing: 8) {
                            Image(systemName: "number")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(runs.map(\.text).joined())
                                .font(fontForHeading(level))
                                .lineLimit(1)
                        }
                        .tag(index)
                    case .paragraph(let runs, _):
                        HStack(spacing: 8) {
                            Image(systemName: "paragraphsign")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(runs.map(\.text).joined().prefix(40) + "...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .tag(index)
                    case .bulletItem(let runs, _):
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(runs.map(\.text).joined())
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .tag(index)
                    case .numberedItem(let runs, let num):
                        HStack(spacing: 8) {
                            Text("\(num).")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                            Text(runs.map(\.text).joined())
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .tag(index)
                    case .blockquote(let runs):
                        HStack(spacing: 8) {
                            Image(systemName: "quote.opening")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(runs.map(\.text).joined())
                                .font(.caption.italic())
                                .lineLimit(1)
                        }
                        .tag(index)
                    case .pageBreak:
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(.caption2)
                            Text("Page Break")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .tag(index)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Outline")
    }

    private func fontForHeading(_ level: HeadingLevel) -> Font {
        switch level {
        case .title: return .headline.bold()
        case .subtitle: return .subheadline.bold()
        case .heading1: return .subheadline.bold()
        case .heading2: return .callout.bold()
        case .heading3: return .caption.bold()
        case .heading4: return .caption2.bold()
        }
    }
}
