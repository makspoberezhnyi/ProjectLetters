import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Command Category

public enum CommandCategory: String, CaseIterable, Identifiable {
    case navigation = "Navigation"
    case formatting = "Formatting"
    case ai = "AI Actions"
    case document = "Document Tools"
    case insert = "Insert"
    case layout = "Page Layout"
    case view = "View & Canvas"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .navigation: return "arrow.up.left.and.arrow.down.right"
        case .formatting: return "textformat"
        case .ai: return "sparkles"
        case .document: return "folder"
        case .insert: return "plus.rectangle.on.rectangle"
        case .layout: return "doc.viewfinder"
        case .view: return "eye"
        }
    }

    public var order: Int {
        switch self {
        case .navigation: return 0
        case .formatting: return 1
        case .ai: return 2
        case .document: return 3
        case .insert: return 4
        case .layout: return 5
        case .view: return 6
        }
    }
}

// MARK: - Command Item

public struct CommandItem: Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let icon: String
    public let category: CommandCategory
    public let shortcut: String?
    public let keywords: [String]
    public let action: @MainActor () -> Void

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        icon: String,
        category: CommandCategory = .navigation,
        shortcut: String? = nil,
        keywords: [String] = [],
        action: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.shortcut = shortcut
        self.keywords = keywords
        self.action = action
    }

    public static func == (lhs: CommandItem, rhs: CommandItem) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Fuzzy Match Result

private struct FuzzyMatch {
    let item: CommandItem
    let score: Int
    let matchedRanges: [Range<String.Index>] // For highlighting
}

// MARK: - Command Palette View (cmdk-quality)

public struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    let commands: [CommandItem]
    var onExecuteDirectCLI: ((String) -> Bool)? = nil

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var showCategoryFilter: Bool = false
    @FocusState private var isSearchFocused: Bool

    // Search debounce
    @State private var searchTask: Task<Void, Never>?
    @State private var filteredCommands: [FuzzyMatch] = []

    public init(
        isPresented: Binding<Bool>,
        commands: [CommandItem],
        onExecuteDirectCLI: ((String) -> Bool)? = nil
    ) {
        self._isPresented = isPresented
        self.commands = commands
        self.onExecuteDirectCLI = onExecuteDirectCLI
    }

    // MARK: - Direct CLI Commands (Dynamic)

    private var directCLIMatch: CommandItem? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()

        // Font Size (e.g. "size 24", "font 18", "pt 16")
        if lower.hasPrefix("size ") || lower.hasPrefix("font ") || lower.hasPrefix("pt ") {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let pt = Double(parts[1]), pt >= 6 && pt <= 144 {
                return CommandItem(
                    title: "Set Font Size to \(Int(pt)) pt",
                    subtitle: "Direct CLI Command",
                    icon: "textformat.size",
                    category: .formatting,
                    shortcut: "↵"
                ) {
                    _ = onExecuteDirectCLI?(trimmed)
                }
            }
        }

        // Zoom (e.g. "zoom 150", "zoom 100", "zoom 75")
        if lower.hasPrefix("zoom ") {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let z = Double(parts[1]), z >= 25 && z <= 500 {
                return CommandItem(
                    title: "Set Canvas Zoom to \(Int(z))%",
                    subtitle: "Direct CLI Command",
                    icon: "magnifyingglass",
                    category: .view,
                    shortcut: "↵"
                ) {
                    _ = onExecuteDirectCLI?(trimmed)
                }
            }
        }

        // Headings (e.g. "h1 Title", "h2 Heading", "h3 Section", "title My Title")
        if lower.hasPrefix("h1 ") || lower.hasPrefix("h2 ") || lower.hasPrefix("h3 ") || lower.hasPrefix("title ") {
            let prefixLen = lower.hasPrefix("title ") ? 6 : 3
            let headingText = String(trimmed.dropFirst(prefixLen))
            return CommandItem(
                title: "Insert Heading: \"\(headingText)\"",
                subtitle: "Direct CLI Command",
                icon: "character.textbox",
                category: .insert,
                shortcut: "↵"
            ) {
                _ = onExecuteDirectCLI?(trimmed)
            }
        }

        // AI Prompt ("ai ...", "ask ...", "write ...", "explain ...")
        if lower.hasPrefix("ai ") || lower.hasPrefix("ask ") || lower.hasPrefix("write ") || lower.hasPrefix("explain ") {
            return CommandItem(
                title: "Ask AI: \"\(trimmed)\"",
                subtitle: "Run prompt with AI Copilot",
                icon: "sparkles",
                category: .ai,
                shortcut: "↵"
            ) {
                _ = onExecuteDirectCLI?(trimmed)
            }
        }

        // Default Fallback Dynamic Prompt if no exact match found
        if filteredCommands.isEmpty {
            return CommandItem(
                title: "Execute / Ask Copilot: \"\(trimmed)\"",
                subtitle: "Natural language instruction or search",
                icon: "arrow.right.circle.fill",
                category: .ai,
                shortcut: "↵"
            ) {
                _ = onExecuteDirectCLI?(trimmed)
            }
        }

        return nil
    }

    // MARK: - Fuzzy Search

    private func performSearch(_ searchQuery: String) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000) // 30ms debounce
            guard !Task.isCancelled else { return }

            let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            var results: [FuzzyMatch] = []

            if trimmed.isEmpty {
                // Show all commands grouped by category
                for cmd in commands {
                    results.append(FuzzyMatch(item: cmd, score: 100, matchedRanges: []))
                }
            } else {
                let queryLower = trimmed.lowercased()
                let queryWords = queryLower.split(separator: " ").map(String.init)

                for cmd in commands {
                    let titleLower = cmd.title.lowercased()
                    let subtitleLower = cmd.subtitle.lowercased()
                    let keywordsLower = cmd.keywords.map { $0.lowercased() }

                    var score = 0
                    var matchedRanges: [Range<String.Index>] = []

                    // Exact prefix match on title (highest priority)
                    if titleLower.hasPrefix(queryLower) {
                        score += 1000
                        matchedRanges.append(titleLower.startIndex..<titleLower.index(titleLower.startIndex, offsetBy: queryLower.count))
                    }
                    // Word boundary match in title
                    else if titleLower.contains(" " + queryLower) || titleLower.hasPrefix(queryLower + " ") {
                        score += 500
                        if let range = titleLower.range(of: queryLower) {
                            matchedRanges.append(range)
                        }
                    }
                    // Substring match in title
                    else if titleLower.contains(queryLower) {
                        score += 200
                        if let range = titleLower.range(of: queryLower) {
                            matchedRanges.append(range)
                        }
                    }
                    // Subtitle match
                    else if subtitleLower.contains(queryLower) {
                        score += 100
                        if let range = subtitleLower.range(of: queryLower) {
                            matchedRanges.append(range)
                        }
                    }
                    // Keyword match
                    else if keywordsLower.contains(where: { $0.contains(queryLower) }) {
                        score += 50
                    }
                    // Fuzzy match (character sequence)
                    else if fuzzyMatch(queryLower, titleLower) {
                        score += 20
                    }
                    // Multi-word query matching
                    else if queryWords.count > 1 {
                        let allWordsMatch = queryWords.allSatisfy { word in
                            titleLower.contains(word) || subtitleLower.contains(word) || keywordsLower.contains(where: { $0.contains(word) })
                        }
                        if allWordsMatch {
                            score += 30
                        }
                    }

                    if score > 0 {
                        results.append(FuzzyMatch(item: cmd, score: score, matchedRanges: matchedRanges))
                    }
                }

                // Sort by score descending, then by category order
                results.sort { lhs, rhs in
                    if lhs.score != rhs.score { return lhs.score > rhs.score }
                    return lhs.item.category.order < rhs.item.category.order
                }
            }

            filteredCommands = results
            selectedIndex = 0
        }
    }

    private func fuzzyMatch(_ query: String, _ target: String) -> Bool {
        var targetIndex = target.startIndex
        for queryChar in query {
            guard let foundIndex = target[targetIndex...].firstIndex(of: queryChar) else { return false }
            targetIndex = target.index(after: foundIndex)
        }
        return true
    }

    // MARK: - Grouped Commands for Display

    private var displayGroups: [(category: CommandCategory, items: [FuzzyMatch])] {
        var groups: [(CommandCategory, [FuzzyMatch])] = []

        // Add direct CLI match first if exists
        if let direct = directCLIMatch {
            groups.append((direct.category, [FuzzyMatch(item: direct, score: 2000, matchedRanges: [])]))
        }

        // Group filtered commands by category
        let categorized = Dictionary(grouping: filteredCommands) { $0.item.category }
        let sortedCategories = CommandCategory.allCases.sorted { $0.order < $1.order }

        for cat in sortedCategories {
            if let items = categorized[cat], !items.isEmpty {
                // Don't duplicate the direct CLI item
                let uniqueItems = items.filter { directCLIMatch == nil || $0.item.id != directCLIMatch!.id }
                if !uniqueItems.isEmpty {
                    groups.append((cat, uniqueItems))
                }
            }
        }

        return groups
    }

    private var allDisplayItems: [FuzzyMatch] {
        displayGroups.flatMap { $0.items }
    }

    private var selectedItem: FuzzyMatch? {
        guard selectedIndex < allDisplayItems.count else { return nil }
        return allDisplayItems[selectedIndex]
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header / Omnibar Input
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolEffect(.pulse, options: .repeating, value: isPresented)

                TextField("Type a command, format, element, or prompt…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .regular))
                    .focused($isSearchFocused)
                    .onChange(of: query) { _, newValue in
                        performSearch(newValue)
                    }
                    .onSubmit {
                        executeCurrentSelection()
                    }
                    .onKeyPress(.downArrow) {
                        moveSelection(delta: 1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        moveSelection(delta: -1)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        closePalette()
                        return .handled
                    }
                    .onKeyPress(.return) {
                        executeCurrentSelection()
                        return .handled
                    }
                    .onKeyPress(.tab) {
                        // Tab cycles through categories
                        cycleCategory()
                        return .handled
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                        selectedIndex = 0
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                            .symbolEffect(.bounce, value: query.isEmpty)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                // Category filter toggle
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showCategoryFilter.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showCategoryFilter ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Filter by Category (Tab)")

                Button {
                    closePalette()
                } label: {
                    Text("esc")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Category Filter Pills (collapsible)
            if showCategoryFilter {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        CategoryPill(
                            category: nil,
                            isSelected: filteredCommands.isEmpty || query.isEmpty,
                            count: allDisplayItems.count
                        ) {
                            // All category - no filter
                        }

                        ForEach(CommandCategory.allCases) { cat in
                            let count = displayGroups.first { $0.category == cat }?.items.count ?? 0
                            if count > 0 {
                                CategoryPill(category: cat, isSelected: false, count: count) {
                                    // Could add category filtering here
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            // Results List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if allDisplayItems.isEmpty {
                            EmptyStateView(query: query)
                                .padding(.vertical, 32)
                                .id("empty")
                        } else {
                            ForEach(Array(displayGroups.enumerated()), id: \.element.category) { groupIndex, group in
                                // Category Section Header
                                SectionHeader(category: group.category, count: group.items.count)
                                    .id("header-\(group.category.rawValue)")

                                ForEach(Array(group.items.enumerated()), id: \.element.item.id) { itemIndex, match in
                                    let globalIndex = allDisplayItems.firstIndex(where: { $0.item.id == match.item.id }) ?? 0
                                    CommandRow(
                                        match: match,
                                        isSelected: globalIndex == selectedIndex,
                                        query: query
                                    )
                                    .id(globalIndex)
                                    .onTapGesture {
                                        selectedIndex = globalIndex
                                        executeCurrentSelection()
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 380)
                .onChange(of: selectedIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            Divider()

            // Footer Bar with Keyboard Shortcuts
            FooterBar(
                itemCount: allDisplayItems.count,
                selectedItem: selectedItem,
                query: query
            )
        }
        .frame(width: 620)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThickMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.3), radius: 32, x: 0, y: 16)
        .onAppear {
            isSearchFocused = true
            performSearch(query)
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    // MARK: - Actions

    private func moveSelection(delta: Int) {
        let count = allDisplayItems.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
    }

    private func cycleCategory() {
        let categories = CommandCategory.allCases.sorted { $0.order < $1.order }
        guard let currentCat = selectedItem?.item.category,
              let currentIndex = categories.firstIndex(of: currentCat) else { return }
        let nextIndex = (currentIndex + 1) % categories.count
        let nextCat = categories[nextIndex]

        // Find first item in next category
        if let nextItemIndex = allDisplayItems.firstIndex(where: { $0.item.category == nextCat }) {
            selectedIndex = nextItemIndex
        }
    }

    private func executeCurrentSelection() {
        if let item = selectedItem {
            item.item.action()
            closePalette()
        }
    }

    private func closePalette() {
        isPresented = false
        query = ""
        selectedIndex = 0
        searchTask?.cancel()
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let category: CommandCategory?
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let cat = category {
                    Image(systemName: cat.icon)
                        .font(.system(size: 9))
                } else {
                    Image(systemName: "command")
                        .font(.system(size: 9))
                }
                Text(category?.rawValue ?? "All")
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                Text("\(count)")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
            )
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let category: CommandCategory
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.accentColor)

            Text(category.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.5)

            Text("\(count)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.06), in: Capsule())

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Command Row

private struct CommandRow: View {
    let match: FuzzyMatch
    let isSelected: Bool
    let query: String

    @State private var isHovered: Bool = false

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.16)
        } else if isHovered {
            return Color.primary.opacity(0.04)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: match.item.icon)
                .frame(width: 22)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .accentColor : .secondary)

            // Title & Subtitle with highlighting
            VStack(alignment: .leading, spacing: 2) {
                HighlightedText(text: match.item.title, query: query, matchedRanges: match.matchedRanges)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.primary)

                Text(match.item.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Category Badge
            if match.item.category != .navigation {
                Text(match.item.category.rawValue)
                    .font(.system(size: 8, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 3))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            // Shortcut Badge
            if let shortcut = match.item.shortcut {
                ShortcutBadge(shortcut: shortcut)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isSelected ? 1.0 : (isHovered ? 1.005 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
    }
}

// MARK: - Highlighted Text (for search query highlighting)

private struct HighlightedText: View {
    let text: String
    let query: String
    let matchedRanges: [Range<String.Index>]

    private var highlightRanges: [Range<String.Index>] {
        if query.isEmpty || matchedRanges.isEmpty {
            return []
        }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let textLower = text.lowercased()

        var ranges: [Range<String.Index>] = []
        var searchStart = textLower.startIndex
        while let range = textLower[searchStart...].range(of: trimmedQuery) {
            let actualRange = text.index(text.startIndex, offsetBy: textLower.distance(from: textLower.startIndex, to: range.lowerBound))..<text.index(text.startIndex, offsetBy: textLower.distance(from: textLower.startIndex, to: range.upperBound))
            ranges.append(actualRange)
            searchStart = range.upperBound
        }
        return ranges
    }

    var body: some View {
        let ranges = highlightRanges
        if ranges.isEmpty {
            Text(text)
        } else {
            buildHighlightedText(ranges: ranges)
        }
    }

    private func buildHighlightedText(ranges: [Range<String.Index>]) -> Text {
        var result = Text("")
        var lastEnd = text.startIndex

        for range in ranges {
            // Text before match
            if range.lowerBound > lastEnd {
                let before = String(text[lastEnd..<range.lowerBound])
                result = result + Text(before).foregroundColor(.primary)
            }

            // Matched text
            let matched = String(text[range])
            result = result + Text(matched)
                .foregroundColor(.accentColor)
                .fontWeight(.bold)

            lastEnd = range.upperBound
        }

        // Remaining text
        if lastEnd < text.endIndex {
            let after = String(text[lastEnd..<text.endIndex])
            result = result + Text(after).foregroundColor(.primary)
        }

        return result
    }
}

// MARK: - Shortcut Badge (cmdk-style)

private struct ShortcutBadge: View {
    let shortcut: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(parseShortcut(shortcut), id: \.self) { key in
                Text(key)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                            )
                    )
                    .foregroundColor(.secondary)
            }
        }
    }

    private func parseShortcut(_ shortcut: String) -> [String] {
        // Parse shortcuts like "⌘B", "⌘⇧K", "⌥⌘1" into individual keys
        var keys: [String] = []
        var current = ""

        for char in shortcut {
            if char == "⌘" || char == "⇧" || char == "⌥" || char == "⌃" {
                if !current.isEmpty {
                    keys.append(current)
                    current = ""
                }
                keys.append(String(char))
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            keys.append(current)
        }

        return keys.isEmpty ? [shortcut] : keys
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    let query: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: query.isEmpty ? "command" : "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolEffect(.pulse, options: .repeating, value: query.isEmpty)

            Text(query.isEmpty ? "No commands available" : "No matches for \"\(query)\"")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            if !query.isEmpty {
                Text("Try a different search or press ↵ to execute as AI prompt")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Footer Bar

private struct FooterBar: View {
    let itemCount: Int
    let selectedItem: FuzzyMatch?
    let query: String

    var body: some View {
        HStack {
            HStack(spacing: 14) {
                ShortcutHint(key: "↑↓", label: "Navigate")
                ShortcutHint(key: "↵", label: "Execute")
                ShortcutHint(key: "Tab", label: "Next Category")
                ShortcutHint(key: "Esc", label: "Close")
            }
            .foregroundColor(.secondary)

            Spacer()

            if let item = selectedItem {
                HStack(spacing: 6) {
                    Image(systemName: item.item.category.icon)
                        .font(.system(size: 9))
                    Text(item.item.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.04), in: Capsule())
            }

            Text("\(itemCount) command\(itemCount == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
}

private struct ShortcutHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 10))
        }
    }
}

// MARK: - Preview

#Preview("Command Palette") {
    @State var isPresented = true
    return CommandPaletteView(
        isPresented: $isPresented,
        commands: [
            CommandItem(title: "Bold", subtitle: "Make text bold", icon: "bold", category: .formatting, shortcut: "⌘B", keywords: ["bold", "strong"]) {},
            CommandItem(title: "Italic", subtitle: "Make text italic", icon: "italic", category: .formatting, shortcut: "⌘I", keywords: ["italic", "emphasis"]) {},
            CommandItem(title: "Heading 1", subtitle: "Insert heading level 1", icon: "textformat.size", category: .formatting, shortcut: "⌘1", keywords: ["heading", "h1"]) {},
            CommandItem(title: "Save Document", subtitle: "Save current document", icon: "square.and.arrow.down", category: .document, shortcut: "⌘S", keywords: ["save", "export"]) {},
            CommandItem(title: "Ask AI", subtitle: "Ask the AI copilot a question", icon: "sparkles", category: .ai, shortcut: "⌘J", keywords: ["ai", "copilot", "ask"]) {},
        ]
    )
    .frame(width: 620, height: 500)
    .background(Color(NSColor.windowBackgroundColor))
}