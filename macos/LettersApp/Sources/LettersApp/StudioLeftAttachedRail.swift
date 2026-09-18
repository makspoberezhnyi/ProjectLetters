import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct StudioLeftAttachedRail: View {
    @Binding var activeTool: StudioTool
    @Binding var pageSize: PageSizePreset
    @Binding var marginPreset: MarginPreset
    @Binding var margins: PageMargins
    @Binding var showMarginGuides: Bool
    @Binding var showCropMarks: Bool
    @Binding var showOutlineDrawer: Bool
    @Binding var showFindReplace: Bool

    var onInsertTable: () -> Void
    var onInsertSection: () -> Void
    var onAddSource: () -> Void
    var onInsertImage: () -> Void
    var onInsertVideo: () -> Void
    var onInsertPageBreak: () -> Void
    var onInsertTOC: () -> Void
    var onInsertBibliography: () -> Void
    var onInsertBulletList: () -> Void
    var onInsertNumberedList: () -> Void

    @State private var showingPageLayoutPopover: Bool = false
    @State private var showingListsPopover: Bool = false

    public init(
        activeTool: Binding<StudioTool>,
        pageSize: Binding<PageSizePreset>,
        marginPreset: Binding<MarginPreset>,
        margins: Binding<PageMargins>,
        showMarginGuides: Binding<Bool>,
        showCropMarks: Binding<Bool>,
        showOutlineDrawer: Binding<Bool>,
        showFindReplace: Binding<Bool>,
        onInsertTable: @escaping () -> Void,
        onInsertSection: @escaping () -> Void,
        onAddSource: @escaping () -> Void,
        onInsertImage: @escaping () -> Void,
        onInsertVideo: @escaping () -> Void,
        onInsertPageBreak: @escaping () -> Void,
        onInsertTOC: @escaping () -> Void,
        onInsertBibliography: @escaping () -> Void,
        onInsertBulletList: @escaping () -> Void = {},
        onInsertNumberedList: @escaping () -> Void = {}
    ) {
        self._activeTool = activeTool
        self._pageSize = pageSize
        self._marginPreset = marginPreset
        self._margins = margins
        self._showMarginGuides = showMarginGuides
        self._showCropMarks = showCropMarks
        self._showOutlineDrawer = showOutlineDrawer
        self._showFindReplace = showFindReplace
        self.onInsertTable = onInsertTable
        self.onInsertSection = onInsertSection
        self.onAddSource = onAddSource
        self.onInsertImage = onInsertImage
        self.onInsertVideo = onInsertVideo
        self.onInsertPageBreak = onInsertPageBreak
        self.onInsertTOC = onInsertTOC
        self.onInsertBibliography = onInsertBibliography
        self.onInsertBulletList = onInsertBulletList
        self.onInsertNumberedList = onInsertNumberedList
    }

    public var body: some View {
        VStack(spacing: 8) {
            // 1. Outline & Pages Navigator Toggle
            RailIconButton(
                icon: "sidebar.left",
                isActive: showOutlineDrawer,
                shortcut: "Outline & Pages (⌥⌘1)"
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showOutlineDrawer.toggle()
                }
            }

            Divider()
                .frame(width: 24)

            // 2. Primary Insert & Content Creation Tools
            VStack(spacing: 4) {
                RailIconButton(icon: "textformat", isActive: false, shortcut: "Insert Text Section") {
                    onInsertSection()
                }

                RailIconButton(icon: "list.bullet.indent", isActive: false, shortcut: "Insert Table of Contents") {
                    onInsertTOC()
                }

                RailIconButton(icon: "tablecells", isActive: false, shortcut: "Insert Smart Table (⌘T)") {
                    onInsertTable()
                }

                RailIconButton(icon: "photo", isActive: false, shortcut: "Insert Figure Image") {
                    onInsertImage()
                }

                RailIconButton(icon: "play.rectangle", isActive: false, shortcut: "Embed Video Card") {
                    onInsertVideo()
                }

                RailIconButton(icon: "quote.bubble", isActive: false, shortcut: "Add Citation (⌥⌘C)") {
                    onAddSource()
                }

                RailIconButton(icon: "books.vertical", isActive: false, shortcut: "Insert Bibliography / Works Cited") {
                    onInsertBibliography()
                }

                RailIconButton(icon: "pagebreak", isActive: false, shortcut: "Insert Page Break (⌘↵)") {
                    onInsertPageBreak()
                }

                // Quick Lists Popover
                Button {
                    showingListsPopover.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(showingListsPopover ? .accentColor : .primary)
                        .frame(width: 32, height: 28)
                        .background(showingListsPopover ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Insert Lists (Bullet, Numbered)")
                .popover(isPresented: $showingListsPopover, arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("List Structures")
                            .font(.system(size: 12, weight: .bold))

                        Divider()

                        Button {
                            onInsertBulletList()
                            showingListsPopover = false
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Bullet List (•)")
                                Spacer()
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onInsertNumberedList()
                            showingListsPopover = false
                        } label: {
                            HStack {
                                Image(systemName: "list.number")
                                Text("Numbered List (1.)")
                                Spacer()
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .frame(width: 170)
                }
            }

            Divider()
                .frame(width: 24)

            // 3. Page Setup, Margins & Publishing Guides Popover
            Button {
                showingPageLayoutPopover.toggle()
            } label: {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(showingPageLayoutPopover ? .accentColor : .primary)
                    .frame(width: 32, height: 28)
                    .background(showingPageLayoutPopover ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Page Setup & Margins")
            .popover(isPresented: $showingPageLayoutPopover, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Page Setup & Margins")
                        .font(.system(size: 13, weight: .bold))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Page Format")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Format", selection: $pageSize) {
                                ForEach(PageSizePreset.allCases, id: \.self) { size in
                                    Text("\(size.rawValue)").tag(size)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }

                        HStack {
                            Text("Margins")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Margins", selection: $marginPreset) {
                                ForEach(MarginPreset.allCases, id: \.self) { preset in
                                    Text(preset.rawValue).tag(preset)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            .onChange(of: marginPreset) { _, newPreset in
                                margins = newPreset.margins
                            }
                        }

                        Divider()

                        Toggle("Margin Guides", isOn: $showMarginGuides)
                            .font(.system(size: 12))

                        Toggle("Publisher Crop Marks", isOn: $showCropMarks)
                            .font(.system(size: 12))
                    }
                }
                .padding(14)
                .frame(width: 240)
            }

            // 4. Find & Replace Overlay Toggle
            RailIconButton(icon: "magnifyingglass", isActive: showFindReplace, shortcut: "Find & Replace (⌘F)") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showFindReplace.toggle()
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(width: 46)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .trailing
        )
    }
}

struct RailIconButton: View {
    let icon: String
    let isActive: Bool
    let shortcut: String
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .accentColor : (isHovered ? .primary : .secondary))
                .frame(width: 32, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? StudioTheme.activeHighlight : (isHovered ? StudioTheme.hoverHighlight : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
                .scaleEffect(isHovered ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
        .help(shortcut)
    }
}
