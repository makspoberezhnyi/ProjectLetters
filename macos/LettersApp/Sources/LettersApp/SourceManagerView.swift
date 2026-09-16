import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct SourceManagerView: View {
    @Binding var sources: [String: Source]
    @Binding var activeStyle: CitationStyle
    @State private var showingAddSheet = false
    @State private var newSourceTitle = ""
    @State private var newSourceAuthor = ""
    @State private var newSourceYear = ""
    @State private var newSourceType: SourceType = .journalArticle

    public init(sources: Binding<[String: Source]>, activeStyle: Binding<CitationStyle>) {
        self._sources = sources
        self._activeStyle = activeStyle
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Style Profile Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Active Citation Style")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Picker("Style", selection: $activeStyle) {
                    ForEach(CitationStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .labelsHidden()
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Source list
            List {
                Section(header: HStack {
                    Text("Linked Sources (\(sources.count))")
                    Spacer()
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }) {
                    if sources.isEmpty {
                        Text("No sources added yet. Click + to link a source.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(sources.values), id: \.id) { source in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.title.isEmpty ? "Untitled Source" : source.title)
                                    .font(.system(size: 13, weight: .medium))
                                HStack(spacing: 6) {
                                    Text(source.authors.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let year = source.year {
                                        Text("(\(String(year)))")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indices in
                            let keys = Array(sources.keys)
                            for idx in indices {
                                sources.removeValue(forKey: keys[idx])
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            VStack(spacing: 16) {
                Text("Add Linked Source")
                    .font(.headline)

                Form {
                    TextField("Title", text: $newSourceTitle)
                    TextField("Author(s) (comma separated)", text: $newSourceAuthor)
                    TextField("Year", text: $newSourceYear)
                    Picker("Source Type", selection: $newSourceType) {
                        ForEach(SourceType.allCases, id: \.self) { st in
                            Text(st.rawValue.capitalized).tag(st)
                        }
                    }
                }
                .frame(width: 320)

                HStack {
                    Button("Cancel") {
                        showingAddSheet = false
                    }
                    Button("Add Source") {
                        let id = UUID().uuidString.prefix(8).lowercased()
                        let authors = newSourceAuthor.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        let yearInt = Int(newSourceYear)
                        let source = Source(
                            id: String(id),
                            sourceType: newSourceType,
                            authors: authors,
                            year: yearInt,
                            title: newSourceTitle
                        )
                        sources[String(id)] = source
                        showingAddSheet = false
                        newSourceTitle = ""
                        newSourceAuthor = ""
                        newSourceYear = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newSourceTitle.isEmpty)
                }
            }
            .padding(20)
        }
    }
}
