import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct DynamicBibliographyView: View {
    public let sources: [String: Source]
    @Binding public var activeStyle: CitationStyle
    public var onDelete: () -> Void
    public var onToast: ((String) -> Void)? = nil

    public init(
        sources: [String: Source],
        activeStyle: Binding<CitationStyle>,
        onDelete: @escaping () -> Void,
        onToast: ((String) -> Void)? = nil
    ) {
        self.sources = sources
        self._activeStyle = activeStyle
        self.onDelete = onDelete
        self.onToast = onToast
    }

    private var sectionHeading: String {
        switch activeStyle {
        case .apa7:
            return "References"
        case .mla9:
            return "Works Cited"
        case .chicagoDate, .chicagoNotes:
            return "Bibliography"
        case .bluebook:
            return "Table of Authorities"
        case .plain:
            return "References & Sources"
        }
    }

    private var sortedSources: [Source] {
        sources.values.sorted { s1, s2 in
            let a1 = s1.authors.first ?? s1.title
            let a2 = s2.authors.first ?? s2.title
            return a1.localizedCaseInsensitiveCompare(a2) == .orderedAscending
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13, weight: .semibold))

                Text(sectionHeading)
                    .font(.system(size: 15, weight: .bold, design: .serif))

                Spacer()

                // Style Selector Badge
                Menu {
                    ForEach(CitationStyle.allCases, id: \.self) { style in
                        Button(style.displayName) {
                            activeStyle = style
                            onToast?("✓ Switched bibliography to \(style.displayName)")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(activeStyle.displayName)
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .foregroundColor(.accentColor)
                }
                .menuStyle(.borderlessButton)

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove Bibliography Section")
            }
            .padding(.bottom, 2)

            Divider()

            // Bibliography Entries
            if sortedSources.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Text("No linked sources yet. Insert citations via ⌥⌘C or the left rail to populate automatically.")
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sortedSources, id: \.id) { source in
                        Text(formattedEntry(for: source))
                            .font(.system(size: 12.5, design: .serif))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func formattedEntry(for source: Source) -> String {
        let authors = source.authors.isEmpty ? [source.title] : source.authors
        let yearStr = source.year != nil ? String(source.year!) : "n.d."
        let authorsStr = authors.joined(separator: ", ")

        switch activeStyle {
        case .apa7:
            return "\(authorsStr) (\(yearStr)). \(source.title). [\(source.sourceType.rawValue.capitalized)]."
        case .mla9:
            return "\(authorsStr). \"\(source.title).\" \(source.sourceType.rawValue.capitalized), \(yearStr)."
        case .chicagoDate, .chicagoNotes:
            return "\(authorsStr). \(yearStr). \(source.title)."
        case .bluebook:
            return "\(authorsStr), \(source.title) (\(yearStr))."
        case .plain:
            return "\(authorsStr) (\(yearStr)) — \(source.title)."
        }
    }
}
