import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public enum SidebarNavSection: String, CaseIterable, Identifiable {
    case pages = "Pages & Spreads"
    case outline = "Headings Outline"
    case sources = "Linked Sources"
    case tables = "Smart Tables"
    case assets = "Media Figures"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .pages: return "doc.on.doc.fill"
        case .outline: return "list.bullet.indent"
        case .sources: return "quote.bubble.fill"
        case .tables: return "tablecells.fill"
        case .assets: return "photo.fill"
        }
    }

    public var color: Color {
        switch self {
        case .pages: return StudioTheme.luminousCyan
        case .outline: return StudioTheme.luminousBlue
        case .sources: return StudioTheme.luminousAmber
        case .tables: return StudioTheme.luminousEmerald
        case .assets: return StudioTheme.luminousPurple
        }
    }
}

public struct StudioFloatingSidebar: View {
    @Binding var isPresented: Bool
    @Binding var rawText: String
    @Binding var selectedPage: Int
    @Binding var sources: [String: Source]
    @Binding var tables: [StudioTableData]
    @Binding var images: [StudioImageBlock]
    @Binding var videos: [StudioVideoBlock]
    @Binding var showAIDrawer: Bool
    @Binding var showCommandPalette: Bool

    var documentPages: [String]
    var onInsertSection: () -> Void
    var onInsertTable: () -> Void
    var onAddSource: () -> Void
    var onInsertPageBreak: () -> Void
    var onToast: ((String) -> Void)? = nil

    @State private var activeSection: SidebarNavSection = .pages
    @State private var hoveredSection: SidebarNavSection? = nil

    public init(
        isPresented: Binding<Bool>,
        rawText: Binding<String>,
        documentPages: [String] = [],
        selectedPage: Binding<Int>,
        sources: Binding<[String: Source]>,
        tables: Binding<[StudioTableData]>,
        images: Binding<[StudioImageBlock]>,
        videos: Binding<[StudioVideoBlock]>,
        showAIDrawer: Binding<Bool>,
        showCommandPalette: Binding<Bool>,
        onInsertSection: @escaping () -> Void,
        onInsertTable: @escaping () -> Void,
        onAddSource: @escaping () -> Void,
        onInsertPageBreak: @escaping () -> Void,
        onToast: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._rawText = rawText
        self.documentPages = documentPages
        self._selectedPage = selectedPage
        self._sources = sources
        self._tables = tables
        self._images = images
        self._videos = videos
        self._showAIDrawer = showAIDrawer
        self._showCommandPalette = showCommandPalette
        self.onInsertSection = onInsertSection
        self.onInsertTable = onInsertTable
        self.onAddSource = onAddSource
        self.onInsertPageBreak = onInsertPageBreak
        self.onToast = onToast
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Workspace / App Identity & Collapse Button
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Color.accentColor, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 26, height: 26)

                    Image(systemName: "feather")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Letters Studio")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Pro Desktop Studio")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Hide Sidebar (⌥⌘1)")
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            Divider()
                .padding(.horizontal, 8)

            // 2. Navigation Categories (Floating Island Tabs)
            VStack(spacing: 3) {
                ForEach(SidebarNavSection.allCases) { sec in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            activeSection = sec
                        }
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(sec.color.opacity(0.18))
                                    .frame(width: 22, height: 22)

                                Image(systemName: sec.icon)
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(sec.color)
                            }

                            Text(sec.rawValue)
                                .font(.system(size: 11.5, weight: activeSection == sec ? .semibold : .medium))
                                .foregroundColor(activeSection == sec ? .primary : .secondary)

                            Spacer()

                            // Count Badges
                            badgeForSection(sec)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(activeSection == sec ? Color.primary.opacity(0.08) : (hoveredSection == sec ? Color.primary.opacity(0.04) : Color.clear))
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHover in
                        hoveredSection = isHover ? sec : nil
                    }
                }
            }
            .padding(.horizontal, 6)

            Divider()
                .padding(.horizontal, 8)

            // 3. Dynamic Section Panel Content
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    switch activeSection {
                    case .pages:
                        pagesSpreadListView
                    case .outline:
                        headingsOutlineListView
                    case .sources:
                        sourcesListView
                    case .tables:
                        tablesListView
                    case .assets:
                        assetsListView
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)

            Divider()
                .padding(.horizontal, 8)

            // 4. Quick Action Micro-Buttons (Bottom of Island)
            HStack(spacing: 6) {
                Button {
                    onInsertPageBreak()
                    onToast?("✓ Page break inserted")
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text("Page")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Insert Page Break (⌘↵)")

                Button {
                    onInsertTable()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "tablecells.badge.ellipsis")
                        Text("Table")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Insert Smart Table")

                Spacer()

                Button {
                    showCommandPalette = true
                } label: {
                    Image(systemName: "command")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Open Command Palette (⌘K)")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(StudioTheme.islandBackground)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 10)
        .padding(.leading, 12)
        .padding(.vertical, 12)
    }

    // MARK: - Section Badges
    @ViewBuilder
    private func badgeForSection(_ sec: SidebarNavSection) -> some View {
        switch sec {
        case .pages:
            Text("\(documentPages.count)")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.06), in: Capsule())
        case .outline:
            EmptyView()
        case .sources:
            if !sources.isEmpty {
                Text("\(sources.count)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(StudioTheme.luminousAmber)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(StudioTheme.luminousAmber.opacity(0.15), in: Capsule())
            }
        case .tables:
            if !tables.isEmpty {
                Text("\(tables.count)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(StudioTheme.luminousEmerald)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(StudioTheme.luminousEmerald.opacity(0.15), in: Capsule())
            }
        case .assets:
            let total = images.count + videos.count
            if total > 0 {
                Text("\(total)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(StudioTheme.luminousPurple)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(StudioTheme.luminousPurple.opacity(0.15), in: Capsule())
            }
        }
    }

    // MARK: - Page Spreads List
    private var pagesSpreadListView: some View {
        VStack(spacing: 8) {
            ForEach(0..<documentPages.count, id: \.self) { idx in
                let pageNum = idx + 1
                Button {
                    selectedPage = pageNum
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white)
                                .frame(width: 24, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(selectedPage == pageNum ? Color.accentColor : Color.black.opacity(0.15), lineWidth: selectedPage == pageNum ? 1.5 : 0.8)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

                            Text("\(pageNum)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.black.opacity(0.7))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Page \(pageNum)")
                                .font(.system(size: 11, weight: selectedPage == pageNum ? .bold : .medium))
                                .foregroundColor(selectedPage == pageNum ? .primary : .secondary)

                            let wordCount = EditorPerformanceCache.countWords(in: documentPages[idx])
                            Text("\(wordCount) words")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        selectedPage == pageNum
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Headings Outline List
    private var headingsOutlineListView: some View {
        let headings = parseHeadings(from: rawText)
        return VStack(alignment: .leading, spacing: 4) {
            if headings.isEmpty {
                Text("No headings found.\nType # Heading 1 to structure.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(8)
            } else {
                ForEach(headings, id: \.title) { h in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(h.level == 1 ? StudioTheme.luminousCyan : (h.level == 2 ? StudioTheme.luminousBlue : StudioTheme.luminousPurple))
                            .frame(width: 5, height: 5)
                            .padding(.leading, CGFloat((h.level - 1) * 8))

                        Text(h.title)
                            .font(.system(size: 10.5, weight: h.level == 1 ? .semibold : .regular))
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    // MARK: - Sources List
    private var sourcesListView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Citations (\(sources.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button("+ Add") { onAddSource() }
                    .font(.system(size: 9.5, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }

            if sources.isEmpty {
                Text("No linked sources.\nClick + Add to attach citations.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(4)
            } else {
                ForEach(Array(sources.values), id: \.id) { src in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(src.title)
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                            Text(src.authors.joined(separator: ", ") + (src.year != nil ? " (\(src.year!))" : ""))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(action: {
                            sources.removeValue(forKey: src.id)
                            onToast?("✓ Removed citation '\(src.title)'")
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Delete citation")
                    }
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }

    // MARK: - Tables List
    private var tablesListView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Smart Tables (\(tables.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button("+ New") { onInsertTable() }
                    .font(.system(size: 9.5, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundColor(StudioTheme.luminousEmerald)
            }

            if tables.isEmpty {
                Text("No smart tables.\nClick + New or Canvas > Table to create.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(4)
            } else {
                ForEach(tables) { tbl in
                    HStack {
                        Image(systemName: "tablecells")
                            .font(.system(size: 10))
                            .foregroundColor(StudioTheme.luminousEmerald)
                        Text(tbl.title)
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(tbl.rows.count)r × \(tbl.headers.count)c")
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundColor(.secondary)
                        Button(action: {
                            deleteTable(tbl)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Delete smart table")
                    }
                    .padding(5)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }

    private func deleteTable(_ tbl: StudioTableData) {
        if let idx = tables.firstIndex(where: { $0.id == tbl.id }) {
            tables.remove(at: idx)
            rawText = rawText.replacingOccurrences(of: "[[table:\(tbl.id.uuidString)]]", with: "")
            rawText = rawText.replacingOccurrences(of: "[[table:budget]]", with: "")
            onToast?("✓ Deleted table '\(tbl.title)'")
        }
    }

    // MARK: - Assets List
    private var assetsListView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Figures & Media (\(images.count + videos.count))")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            if images.isEmpty && videos.isEmpty {
                Text("No media figures.\nDrag and drop or insert images/videos.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(4)
            } else {
                ForEach(images) { img in
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 10))
                            .foregroundColor(StudioTheme.luminousPurple)
                        Text(img.caption)
                            .font(.system(size: 10.5))
                            .lineLimit(1)
                        Spacer()
                        Button(action: {
                            if let idx = images.firstIndex(where: { $0.id == img.id }) {
                                images.remove(at: idx)
                                rawText = rawText.replacingOccurrences(of: "[[image:\(img.id.uuidString)]]", with: "")
                                onToast?("✓ Deleted image figure")
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Delete image")
                    }
                    .padding(5)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                }

                ForEach(videos) { vid in
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(StudioTheme.luminousAmber)
                        Text(vid.title)
                            .font(.system(size: 10.5))
                            .lineLimit(1)
                        Spacer()
                        Button(action: {
                            if let idx = videos.firstIndex(where: { $0.id == vid.id }) {
                                videos.remove(at: idx)
                                rawText = rawText.replacingOccurrences(of: "[[video:\(vid.id.uuidString)]]", with: "")
                                onToast?("✓ Deleted video card")
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Delete video")
                    }
                    .padding(5)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }

    private struct OutlineItem {
        let level: Int
        let title: String
    }

    private func parseHeadings(from text: String) -> [OutlineItem] {
        var result: [OutlineItem] = []
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("### ") {
                result.append(OutlineItem(level: 3, title: String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") {
                result.append(OutlineItem(level: 2, title: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") {
                result.append(OutlineItem(level: 1, title: String(trimmed.dropFirst(2))))
            }
        }
        return result
    }
}
