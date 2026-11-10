import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public enum OutlineDrawerTab: String, CaseIterable {
    case outline = "Outline"
    case pages = "Pages"
    case sources = "Sources"
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

public struct DocumentOutlineView: View {
    @Binding var isPresented: Bool
    @Binding var rawText: String
    let cursorOffset: Int
    let pageCount: Int
    let pageForOffset: (Int) -> Int
    let pageSnippet: (Int) -> String
    @Binding var sources: [String: Source]
    @Binding var activeCitationStyle: CitationStyle
    var onSelectOffset: ((Int) -> Void)?
    var onSelectHeading: ((Int, Int) -> Void)?
    var onSelectPage: ((Int) -> Void)?

    @State private var activeTab: OutlineDrawerTab = .outline
    @State private var searchFilter: String = ""
    @State private var collapsedNodes: Set<String> = []
    @State private var hoveredHeadingId: String? = nil
    /// Parsed once per typing pause instead of on every body evaluation (it was recomputed several times per keystroke).
    @State private var headings: [HeadingNode] = []

    public init(
        isPresented: Binding<Bool>,
        rawText: Binding<String>,
        cursorOffset: Int = 0,
        pageCount: Int = 1,
        pageForOffset: @escaping (Int) -> Int = { _ in 1 },
        pageSnippet: @escaping (Int) -> String = { _ in "" },
        sources: Binding<[String: Source]>,
        activeCitationStyle: Binding<CitationStyle>,
        onSelectOffset: ((Int) -> Void)? = nil,
        onSelectHeading: ((Int, Int) -> Void)? = nil,
        onSelectPage: ((Int) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._rawText = rawText
        self.cursorOffset = cursorOffset
        self.pageCount = max(1, pageCount)
        self.pageForOffset = pageForOffset
        self.pageSnippet = pageSnippet
        self._sources = sources
        self._activeCitationStyle = activeCitationStyle
        self.onSelectOffset = onSelectOffset
        self.onSelectHeading = onSelectHeading
        self.onSelectPage = onSelectPage
    }

    private func computeHeadings() -> [HeadingNode] {
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
            // Header
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.indent")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13, weight: .semibold))
                Text("Outline")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Close the outline")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Picker("", selection: $activeTab) {
                ForEach(OutlineDrawerTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider()

            switch activeTab {
            case .outline:
                outlineTabBody

            case .pages:
                pagesTabBody

            case .sources:
                SourceManagerView(
                    sources: $sources,
                    activeStyle: $activeCitationStyle
                )
            }
        }
        .frame(width: 250)
        .background(Color(NSColor.windowBackgroundColor))
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
            // Filter Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Filter headings…", text: $searchFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                if !searchFilter.isEmpty {
                    Button(action: { searchFilter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if filteredHeadings.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text(searchFilter.isEmpty ? "No headings yet" : "No matching headings")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text(searchFilter.isEmpty
                                 ? "Style text as a heading, or start a line with # or ## to build an outline you can navigate."
                                 : "Try a different word, or clear the filter.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    } else {
                        ForEach(Array(filteredHeadings.enumerated()), id: \.element.id) { index, item in
                            headingRow(item: item, index: index)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
        }
    }

    private func headingRow(item: HeadingNode, index: Int) -> some View {
        let isActive = (item.id == activeHeadingId)
        let isHovered = (item.id == hoveredHeadingId)

        return HStack(spacing: 0) {
            // Scroll-Spy Beacon Indicator (Capsule pill)
            ZStack {
                if isActive {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 3, height: 16)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 6)

            Button(action: {
                if let onSelectOffset = onSelectOffset {
                    onSelectOffset(item.charOffset)
                } else {
                    onSelectHeading?(item.columnIndex, item.charOffset)
                }
            }) {
                HStack(spacing: 6) {
                    // Indentation based on level
                    if item.level > 1 {
                        Spacer()
                            .frame(width: CGFloat(item.level - 1) * 12)
                    }

                    // Level bullet
                    Image(systemName: item.level == 1 ? "number" : "chevron.right")
                        .font(.system(size: item.level == 1 ? 10 : 8, weight: .bold))
                        .foregroundColor(isActive ? .accentColor : .secondary.opacity(0.8))

                    Text(item.title)
                        .font(.system(size: item.level == 1 ? 12 : 11.5, weight: item.level == 1 ? .semibold : .regular))
                        .foregroundColor(isActive ? .primary : .primary.opacity(0.85))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Section word count badge
                    if item.wordCount > 0 {
                        Text("\(item.wordCount)")
                            .help(Copy.count(item.wordCount, "word"))
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 3))
                    }

                    // Section reorder affordances on hover
                    if isHovered {
                        HStack(spacing: 2) {
                            Button(action: { moveSection(at: index, direction: -1) }) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            .help("Move section up")

                            Button(action: { moveSection(at: index, direction: 1) }) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == filteredHeadings.count - 1)
                            .help("Move section down")
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    isActive
                        ? Color.accentColor.opacity(0.10)
                        : (isHovered ? Color.primary.opacity(0.05) : Color.clear),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .onHover { hovering in
            if hovering {
                hoveredHeadingId = item.id
            } else if hoveredHeadingId == item.id {
                hoveredHeadingId = nil
            }
        }
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
        ScrollView {
            VStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { pageIdx in
                    let colIdx = pageIdx
                    let preview = pageSnippet(pageIdx).trimmingCharacters(in: .whitespacesAndNewlines)

                    Button(action: {
                        if let onSelectPage = onSelectPage {
                            onSelectPage(colIdx)
                        }
                    }) {
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white)
                                    .frame(width: 28, height: 36)
                                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                Text("\(pageIdx + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Page \(pageIdx + 1)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(preview.isEmpty ? "Empty page" : String(preview.prefix(60)))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }
}
