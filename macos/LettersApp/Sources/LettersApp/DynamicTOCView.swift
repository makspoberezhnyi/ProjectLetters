import SwiftUI

public struct TOCItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let level: Int
    public let page: Int

    public init(title: String, level: Int, page: Int) {
        self.id = "p\(page)-l\(level)-\(title.hashValue)"
        self.title = title
        self.level = level
        self.page = page
    }
}

public struct DynamicTOCView: View {
    public let rawText: String
    public var onDelete: () -> Void
    public var onToast: ((String) -> Void)? = nil

    public init(
        rawText: String,
        onDelete: @escaping () -> Void,
        onToast: ((String) -> Void)? = nil
    ) {
        self.rawText = rawText
        self.onDelete = onDelete
        self.onToast = onToast
    }

    private var tocItems: [TOCItem] {
        var items: [TOCItem] = []
        let pages = rawText.components(separatedBy: "---pagebreak---")
        let regex = EditorPerformanceCache.shared.tocHeadingRegex

        for (pageIdx, pageText) in pages.enumerated() {
            let lines = pageText.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("# ") {
                    let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        items.append(TOCItem(title: title, level: 1, page: pageIdx + 1))
                    }
                } else if trimmed.hasPrefix("## ") {
                    let title = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        items.append(TOCItem(title: title, level: 2, page: pageIdx + 1))
                    }
                } else if trimmed.hasPrefix("### ") {
                    let title = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        items.append(TOCItem(title: title, level: 3, page: pageIdx + 1))
                    }
                } else {
                    let ns = trimmed as NSString
                    let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: ns.length))
                    if let m = match, m.range.location != NSNotFound {
                        let title = trimmed
                        let dotCount = title.prefix(while: { $0 != " " }).filter { $0 == "." }.count
                        items.append(TOCItem(title: title, level: max(1, dotCount), page: pageIdx + 1))
                    }
                }
            }
        }
        return items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "list.bullet.indent")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13, weight: .semibold))

                Text("Table of Contents")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Text("Live Outline")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .foregroundColor(.accentColor)

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove Table of Contents")
            }
            .padding(.bottom, 2)

            Divider()

            // TOC Items List
            if tocItems.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Text("No headings found. Add headings (e.g. \"# Heading\" or \"1. Section\") to populate this table.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 6) {
                    ForEach(tocItems) { item in
                        HStack(alignment: .bottom, spacing: 6) {
                            Text(item.title)
                                .font(.system(size: item.level == 1 ? 13 : 12, weight: item.level == 1 ? .semibold : .regular))
                                .padding(.leading, CGFloat((item.level - 1) * 16))

                            // Dotted leader line
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)
                                .padding(.bottom, 3)

                            Text("\(item.page)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
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
}
