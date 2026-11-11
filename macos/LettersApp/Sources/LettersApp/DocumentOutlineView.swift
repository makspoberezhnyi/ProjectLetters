import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

/// The two panes of the left navigator. Sources and citations live in the Assistant tab of the
/// inspector, next to the writing tools that use them.
public enum OutlineDrawerTab: String, CaseIterable {
    case outline = "Outline"
    case pages = "Pages"

    var icon: String {
        switch self {
        case .outline: return "list.bullet.indent"
        case .pages: return "doc.on.doc"
        }
    }
}

public struct HeadingNode: Identifiable {
    public let id: String
    public let title: String
    public let level: Int
    public let charOffset: Int
    public let charLength: Int
    public let sectionRange: NSRange
    public let wordCount: Int
    public let columnIndex: Int
    public let pageNumber: Int
}

/// Left navigator: a searchable heading outline and a page strip, on sidebar vibrancy.
public struct DocumentOutlineView: View {
    @Binding var rawText: String
    let cursorOffset: Int
    let pageCount: Int
    let pageForOffset: (Int) -> Int
    let pageSnippet: (Int) -> String
    var onSelectOffset: ((Int) -> Void)?
    var onSelectHeading: ((Int, Int) -> Void)?
    var onSelectPage: ((Int) -> Void)?

    @State private var activeTab: OutlineDrawerTab = .outline
    @State private var searchFilter: String = ""
    @State private var hoveredHeadingId: String? = nil
    @State private var hoveredPage: Int? = nil
    @FocusState private var searchFocused: Bool
    /// Parsed once per typing pause instead of on every body evaluation (it was recomputed several times per keystroke).
    @State private var headings: [HeadingNode] = []
    /// Edit-version token to avoid re-parsing when rawText hasn't meaningfully changed.
    @State private var lastParsedTextVersion: Int = 0
    @State private var lastParsedRawText: String = ""

    public init(
        rawText: Binding<String>,
        cursorOffset: Int = 0,
        pageCount: Int = 1,
        pageForOffset: @escaping (Int) -> Int = { _ in 1 },
        pageSnippet: @escaping (Int) -> String = { _ in "" },
        onSelectOffset: ((Int) -> Void)? = nil,
        onSelectHeading: ((Int, Int) -> Void)? = nil,
        onSelectPage: ((Int) -> Void)? = nil
    ) {
        self._rawText = rawText
        self.cursorOffset = cursorOffset
        self.pageCount = max(1, pageCount)
        self.pageForOffset = pageForOffset
        self.pageSnippet = pageSnippet
        self.onSelectOffset = onSelectOffset
        self.onSelectHeading = onSelectHeading
        self.onSelectPage = onSelectPage
    }

    private func computeHeadings() -> [HeadingNode] {
        // Fast-path: if text hasn't changed since last parse, return cached headings
        if rawText == lastParsedRawText {
            return headings
        }
        
        var rawNodes: [(id: String, title: String, level: Int, offset: Int, length: Int, colIdx: Int, pageNum: Int)] = []
        let regex = EditorPerformanceCache.shared.tocHeadingRegex

        // If we have continuous rawText, parse directly from rawText to maintain perfect fidelity
        let textToParse = rawText
        let nsText = textToParse as NSString
        let lines = textToParse.components(separatedBy: "\n")
        var runningOffset = 0

        for (lineIdx, line) in lines.enumerated() {
            let lineLength = (line as NSString).length
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            var headingTitle: String? = nil
            var headingLevel: Int = 1

            if trimmed.hasPrefix("# ") {
                headingTitle = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                headingLevel = 1
            } else if trimmed.hasPrefix("## ") {
                headingTitle = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                headingLevel = 2
            } else if trimmed.hasPrefix("### ") {
                headingTitle = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                headingLevel = 3
            } else if trimmed.hasPrefix("#### ") {
                headingTitle = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                headingLevel = 4
            } else {
                let nsTrimmed = trimmed as NSString
                if let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: nsTrimmed.length)),
                   match.range.location != NSNotFound {
                    let dotCount = trimmed.prefix(while: { $0 != " " }).filter { $0 == "." }.count
                    headingTitle = trimmed
                    headingLevel = max(1, dotCount)
                }
            }

            if let title = headingTitle, !title.isEmpty {
                let estimatedPage = pageForOffset(runningOffset)
                rawNodes.append((
                    id: "h-\(lineIdx)-\(runningOffset)",
                    title: title,
                    level: headingLevel,
                    offset: runningOffset,
                    length: lineLength,
                    colIdx: 0,
                    pageNum: estimatedPage
                ))
            }

            runningOffset += lineLength + 1
        }

        // Now compute section ranges and word counts
        var result: [HeadingNode] = []
        for i in 0..<rawNodes.count {
            let curr = rawNodes[i]
            let nextOffset: Int
            if i + 1 < rawNodes.count {
                nextOffset = rawNodes[i + 1].offset
            } else {
                nextOffset = nsText.length
            }

            let sectionLength = max(0, nextOffset - curr.offset)
            let sectionRange = NSRange(location: curr.offset, length: min(sectionLength, max(0, nsText.length - curr.offset)))
            
            var wordCount = 0
            if sectionRange.location + sectionRange.length <= nsText.length {
                let sectionStr = nsText.substring(with: sectionRange)
                let words = sectionStr.split { $0.isWhitespace || $0.isNewline }
                wordCount = words.count
            }

            result.append(HeadingNode(
                id: curr.id,
                title: curr.title,
                level: curr.level,
                charOffset: curr.offset,
                charLength: curr.length,
                sectionRange: sectionRange,
                wordCount: wordCount,
                columnIndex: curr.colIdx,
                pageNumber: curr.pageNum
            ))
        }

        // Update cache
        lastParsedRawText = rawText
        lastParsedTextVersion &+= 1
        
        return result
    }

    private var activeHeadingId: String? {
        let all = headings
        guard !all.isEmpty else { return nil }
        // Find section containing cursorOffset
        for node in all.reversed() {
            if cursorOffset >= node.charOffset {
                return node.id
            }
        }
        return all.first?.id
    }

    private var filteredHeadings: [HeadingNode] {
        let all = headings
        let query = searchFilter.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty { return all }
        return all.filter { $0.title.lowercased().contains(query) }
    }

    private var totalPages: Int { pageCount }

    public var body: some View {
        VStack(spacing: 0) {
            StudioSegmentedControl(
                segments: OutlineDrawerTab.allCases.map {
                    StudioSegment(tag: $0, title: $0.rawValue, icon: $0.icon, help: "Show \($0.rawValue.lowercased())")
                },
                selected: activeTab,
                onSelect: { activeTab = $0 }
            )
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            switch activeTab {
            case .outline:
                outlineTabBody
            case .pages:
                pagesTabBody
            }
        }
        .frame(width: 250)
        .frame(maxHeight: .infinity)
        .background(VisualEffectBackground(material: .sidebar))
        .onAppear { headings = computeHeadings() }
        .task(id: rawText) {
            // Debounce: cancelled and restarted on every edit, so parsing only runs once typing pauses.
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            headings = computeHeadings()
        }
    }

    // MARK: - Outline Tab
    private var outlineTabBody: some View {
        VStack(spacing: 0) {
            // Filter field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("Filter headings", text: $searchFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
                if !searchFilter.isEmpty {
                    Button(action: { searchFilter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear filter")
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Color.primary.opacity(searchFocused ? 0.09 : 0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(searchFocused ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeOut(duration: 0.15), value: searchFocused)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider().opacity(0.6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if filteredHeadings.isEmpty {
                        StudioEmptyState(
                            icon: searchFilter.isEmpty ? "text.alignleft" : "magnifyingglass",
                            title: searchFilter.isEmpty ? "No headings yet" : "No matching headings",
                            message: searchFilter.isEmpty
                                ? "Style a line as a heading, or start it with # or ##, and it shows up here."
                                : "Try a different word, or clear the filter."
                        )
                    } else {
                        ForEach(Array(filteredHeadings.enumerated()), id: \.element.id) { index, item in
                            headingRow(item: item, index: index)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
    }

    private func headingRow(item: HeadingNode, index: Int) -> some View {
        let isActive = (item.id == activeHeadingId)
        let isHovered = (item.id == hoveredHeadingId)
        let canReorder = searchFilter.trimmingCharacters(in: .whitespaces).isEmpty

        return HStack(spacing: 4) {
            Button(action: {
                if let onSelectOffset = onSelectOffset {
                    onSelectOffset(item.charOffset)
                } else {
                    onSelectHeading?(item.columnIndex, item.charOffset)
                }
            }) {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 3, height: 14)
                        .opacity(isActive ? 1 : 0)

                    Text(item.title)
                        .font(.system(size: item.level == 1 ? 12.5 : 12, weight: item.level == 1 ? .semibold : (item.level == 2 ? .medium : .regular)))
                        .foregroundColor(isActive ? .accentColor : (item.level >= 3 ? .primary.opacity(0.7) : .primary))
                        .lineLimit(1)
                        .padding(.leading, CGFloat(max(0, item.level - 1)) * 12)

                    Spacer(minLength: 2)

                    if item.wordCount > 0 && !(isHovered && canReorder) {
                        Text("\(item.wordCount)")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundColor(.secondary.opacity(0.8))
                            .help(Copy.count(item.wordCount, "word"))
                    }
                }
                .padding(.leading, 4)
                .padding(.trailing, 6)
                .frame(minHeight: 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title)
            .accessibilityAddTraits(isActive ? .isSelected : [])
            .overlay(alignment: .trailing) {
                // Reorder affordances replace the word count while hovering, so rows never change width.
                if isHovered && canReorder {
                    HStack(spacing: 0) {
                        reorderButton(icon: "chevron.up", help: "Move section up", disabled: index == 0) {
                            moveSection(at: index, direction: -1)
                        }
                        reorderButton(icon: "chevron.down", help: "Move section down", disabled: index == filteredHeadings.count - 1) {
                            moveSection(at: index, direction: 1)
                        }
                    }
                    .padding(.trailing, 2)
                    .transition(.opacity)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            if hovering {
                hoveredHeadingId = item.id
            } else if hoveredHeadingId == item.id {
                hoveredHeadingId = nil
            }
        }
    }

    private func reorderButton(icon: String, help: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(StudioHoverButtonStyle(cornerRadius: 5))
        .disabled(disabled)
        .help(help)
    }

    // MARK: - Section Relocation
    private func moveSection(at index: Int, direction: Int) {
        let all = filteredHeadings
        let targetIndex = index + direction
        guard targetIndex >= 0 && targetIndex < all.count else { return }

        let current = all[index]
        let target = all[targetIndex]

        let ns = rawText as NSString
        guard current.sectionRange.location + current.sectionRange.length <= ns.length,
              target.sectionRange.location + target.sectionRange.length <= ns.length else { return }

        let currentSnippet = ns.substring(with: current.sectionRange)

        var newString = rawText as NSString
        if direction < 0 {
            // Moving Up: Remove current snippet, then insert before target
            newString = newString.replacingCharacters(in: current.sectionRange, with: "") as NSString
            let insertPos = target.sectionRange.location
            let mutable = NSMutableString(string: newString as String)
            mutable.insert(currentSnippet, at: insertPos)
            rawText = mutable as String
            onSelectOffset?(insertPos)
        } else {
            // Moving Down: Target comes after current
            let insertPos = target.sectionRange.location + target.sectionRange.length
            let mutable = NSMutableString(string: newString as String)
            mutable.insert(currentSnippet, at: insertPos)
            mutable.deleteCharacters(in: current.sectionRange)
            rawText = mutable as String
            onSelectOffset?(target.sectionRange.location)
        }
    }

    // MARK: - Pages Tab
    private var pagesTabBody: some View {
        let currentPage = max(1, min(totalPages, pageForOffset(cursorOffset)))

        return VStack(spacing: 0) {
            HStack {
                Text(totalPages == 1 ? "1 page" : "\(totalPages) pages")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("On page \(currentPage)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider().opacity(0.6)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(0..<totalPages, id: \.self) { pageIdx in
                        pageRow(pageIdx: pageIdx, isCurrent: pageIdx + 1 == currentPage)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
    }

    private func pageRow(pageIdx: Int, isCurrent: Bool) -> some View {
        let preview = pageSnippet(pageIdx).trimmingCharacters(in: .whitespacesAndNewlines)
        let isHovered = hoveredPage == pageIdx

        return Button(action: { onSelectPage?(pageIdx) }) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(StudioTheme.paperBackground)
                        .frame(width: 30, height: 40)
                        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(isCurrent ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: isCurrent ? 1.5 : 0.5)
                        )
                    Text("\(pageIdx + 1)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(StudioTheme.paperTextColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Page \(pageIdx + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isCurrent ? .accentColor : .primary)
                    Text(preview.isEmpty ? "Empty page" : String(preview.prefix(60)))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isCurrent ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            if hovering { hoveredPage = pageIdx } else if hoveredPage == pageIdx { hoveredPage = nil }
        }
        .accessibilityLabel("Page \(pageIdx + 1)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
