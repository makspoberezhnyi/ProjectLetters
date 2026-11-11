import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Assistant & research
//
// The AI co-writer and the citation manager were two unrelated places (an inspector tab and a left
// sidebar tab). They sit together now: [ AI Assistant | Citations & Sources ].

struct InspectorAssistantTab: View {
    @ObservedObject var document: LettersDocumentController
    @Binding var segment: AssistantSegment
    @Binding var selectedText: String

    // Assistant wiring (same closures the standalone assistant used)
    var onInsertTable: (StudioTableData) -> Void
    var onInsertSource: (Source) -> Void
    var onInsertHeading: (Int, String) -> Void
    var onSetMargins: (String) -> Void
    var onInsertPageBreak: () -> Void
    var onInsertTOC: () -> Void
    var onInsertBibliography: () -> Void
    var onInsertAtCaret: (String) -> Void
    var onToast: (String) -> Void
    var currentDocumentContext: () -> String

    // Citations wiring
    var onAddSource: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            StudioSegmentedControl(
                segments: [
                    StudioSegment(tag: AssistantSegment.assistant, title: "AI Assistant", icon: "sparkles",
                                  help: "Draft, revise and summarize with Claude"),
                    StudioSegment(tag: .citations, title: "Sources", icon: "books.vertical",
                                  badge: document.document.sources.count,
                                  help: "Citation style, sources and bibliography")
                ],
                selected: segment,
                onSelect: { segment = $0 }
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.6)

            switch segment {
            case .assistant:
                AssistantSidebarView(
                    rawText: $document.rawText,
                    selectedText: $selectedText,
                    onInsertTable: onInsertTable,
                    onInsertSource: onInsertSource,
                    onInsertHeading: onInsertHeading,
                    onSetMargins: onSetMargins,
                    onInsertPageBreak: onInsertPageBreak,
                    onInsertTOC: onInsertTOC,
                    onInsertBibliography: onInsertBibliography,
                    onToast: onToast,
                    onInsertAtCaret: onInsertAtCaret,
                    embedded: true,
                    currentDocumentContext: currentDocumentContext
                )
            case .citations:
                CitationsPanel(
                    document: document,
                    onAddSource: onAddSource,
                    onInsertAtCaret: onInsertAtCaret,
                    onInsertBibliography: onInsertBibliography
                )
            }
        }
    }
}

// MARK: - Citations & sources

private struct CitationsPanel: View {
    @ObservedObject var document: LettersDocumentController
    var onAddSource: () -> Void
    var onInsertAtCaret: (String) -> Void
    var onInsertBibliography: () -> Void

    @State private var editing: Source? = nil
    @State private var hoveredId: String? = nil

    private var sortedSources: [Source] {
        document.document.sources.values.sorted {
            let a = $0.authors.first.map(InTextCitation.surname(of:)) ?? ""
            let b = $1.authors.first.map(InTextCitation.surname(of:)) ?? ""
            if a.caseInsensitiveCompare(b) != .orderedSame { return a.caseInsensitiveCompare(b) == .orderedAscending }
            return ($0.year ?? 0) < ($1.year ?? 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StudioFormSection(title: "Citation style", icon: "text.quote") {
                    StudioFormRow(label: "Style", detail: "Used for in-text citations and the bibliography") {
                        StudioMenuValue(value: shortStyleName(document.citationStyle)) {
                            Picker("Citation style", selection: $document.citationStyle) {
                                ForEach(CitationStyle.allCases, id: \.self) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                    }
                }

                StudioFormSection(title: "Sources (\(document.document.sources.count))", icon: "books.vertical", trailing: {
                    Button(action: onAddSource) {
                        Label("Add source", systemImage: "plus")
                    }
                    .buttonStyle(StudioPillButtonStyle(prominent: true))
                    .help("Add a source to cite")
                }) {
                    if sortedSources.isEmpty {
                        StudioEmptyState(
                            icon: "books.vertical",
                            title: "No sources yet",
                            message: "Add a book, article or website, then cite it anywhere in the text."
                        )
                    } else {
                        ForEach(Array(sortedSources.enumerated()), id: \.element.id) { index, source in
                            if index > 0 { StudioRowDivider() }
                            sourceRow(source)
                        }
                    }
                }

                Button {
                    onInsertBibliography()
                } label: {
                    Label("Generate bibliography", systemImage: "list.bullet.rectangle")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(StudioHoverButtonStyle(cornerRadius: 9, isActive: true))
                .disabled(document.document.sources.isEmpty)
                .help("Insert a bibliography at the caret, formatted in \(document.citationStyle.displayName)")
            }
            .padding(14)
        }
        .sheet(item: $editing) { source in
            SourceEditSheet(source: source) { updated in
                document.document.sources[updated.id] = updated
            } onDelete: {
                document.document.sources.removeValue(forKey: source.id)
            }
        }
    }

    private func shortStyleName(_ style: CitationStyle) -> String {
        style.displayName.components(separatedBy: " (").first?.replacingOccurrences(of: " Edition", with: "") ?? style.displayName
    }

    private func sourceRow(_ source: Source) -> some View {
        let isComplete = !source.authors.isEmpty && !source.title.isEmpty && source.year != nil
        let isHovered = hoveredId == source.id
        let authors = source.authors.isEmpty ? "No author" : source.authors.joined(separator: ", ")
        let year = source.year.map(String.init) ?? "n.d."

        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(isComplete ? .green : .orange)
                .padding(.top, 2)
                .help(isComplete ? "Complete" : "Missing author, title or year")

            VStack(alignment: .leading, spacing: 2) {
                Text(source.title.isEmpty ? "Untitled source" : source.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(authors) · \(year)")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(InTextCitation.text(for: source, style: document.citationStyle))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.85))
            }

            Spacer(minLength: 4)

            VStack(spacing: 4) {
                Button {
                    onInsertAtCaret(InTextCitation.text(for: source, style: document.citationStyle))
                } label: {
                    Text("Cite")
                }
                .buttonStyle(StudioPillButtonStyle())
                .help("Insert this citation at the caret")

                Button {
                    editing = source
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(StudioHoverButtonStyle(cornerRadius: 5))
                .opacity(isHovered ? 1 : 0.55)
                .help("Edit source")
            }
        }
        .padding(10)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .onHover { inside in
            if inside { hoveredId = source.id } else if hoveredId == source.id { hoveredId = nil }
        }
    }
}

// MARK: - Edit sheet

private struct SourceEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Source
    @State private var authorsText: String
    @State private var yearText: String
    let onSave: (Source) -> Void
    let onDelete: () -> Void

    init(source: Source, onSave: @escaping (Source) -> Void, onDelete: @escaping () -> Void) {
        _draft = State(initialValue: source)
        _authorsText = State(initialValue: source.authors.joined(separator: ", "))
        _yearText = State(initialValue: source.year.map(String.init) ?? "")
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit source")
                .font(.headline)

            Form {
                TextField("Title", text: $draft.title)
                TextField("Authors", text: $authorsText, prompt: Text("Thomas Kuhn, Ian Hacking"))
                TextField("Year", text: $yearText, prompt: Text("1962"))
                Picker("Type", selection: $draft.sourceType) {
                    ForEach(SourceType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                TextField("Publication", text: optional($draft.publication))
                TextField("DOI", text: optional($draft.doi))
                TextField("URL", text: optional($draft.url))
            }
            .frame(width: 340)

            HStack {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    var result = draft
                    result.authors = authorsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    result.year = Int(yearText.trimmingCharacters(in: .whitespaces))
                    onSave(result)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    private func optional(_ binding: Binding<String?>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue ?? "" },
            set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
