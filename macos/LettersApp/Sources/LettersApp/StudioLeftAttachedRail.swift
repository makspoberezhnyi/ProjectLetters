import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct StudioLeftAttachedRail: View {
    @Binding var activeTool: StudioTool
    @Binding var fontFamily: String
    @Binding var fontSize: CGFloat
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderline: Bool
    @Binding var textAlignment: TextAlignment
    @Binding var pageSize: PageSizePreset
    @Binding var marginPreset: MarginPreset
    @Binding var margins: PageMargins
    @Binding var showMarginGuides: Bool
    @Binding var showCropMarks: Bool
    @Binding var showOutlineDrawer: Bool
    @Binding var showFindReplace: Bool

    var onToggleBold: () -> Void
    var onToggleItalic: () -> Void
    var onToggleUnderline: () -> Void
    var onSetAlignment: (TextAlignment) -> Void
    var onSetFontFamily: (String) -> Void
    var onSetFontSize: (CGFloat) -> Void
    var onInsertTable: () -> Void
    var onInsertSection: () -> Void
    var onAddSource: () -> Void
    var onInsertImage: () -> Void
    var onInsertVideo: () -> Void
    var onInsertPageBreak: () -> Void
    var onInsertTOC: () -> Void
    var onInsertBibliography: () -> Void
    var onToggleStrikethrough: () -> Void
    var onInsertBulletList: () -> Void
    var onInsertNumberedList: () -> Void

    @State private var showingFontMenu: Bool = false
    @State private var showingPageLayoutPopover: Bool = false
    @State private var showingTypographyPopover: Bool = false

    public init(
        activeTool: Binding<StudioTool>,
        fontFamily: Binding<String>,
        fontSize: Binding<CGFloat>,
        isBold: Binding<Bool>,
        isItalic: Binding<Bool>,
        isUnderline: Binding<Bool>,
        textAlignment: Binding<TextAlignment>,
        pageSize: Binding<PageSizePreset>,
        marginPreset: Binding<MarginPreset>,
        margins: Binding<PageMargins>,
        showMarginGuides: Binding<Bool>,
        showCropMarks: Binding<Bool>,
        showOutlineDrawer: Binding<Bool>,
        showFindReplace: Binding<Bool>,
        onToggleBold: @escaping () -> Void,
        onToggleItalic: @escaping () -> Void,
        onToggleUnderline: @escaping () -> Void,
        onSetAlignment: @escaping (TextAlignment) -> Void,
        onSetFontFamily: @escaping (String) -> Void,
        onSetFontSize: @escaping (CGFloat) -> Void,
        onInsertTable: @escaping () -> Void,
        onInsertSection: @escaping () -> Void,
        onAddSource: @escaping () -> Void,
        onInsertImage: @escaping () -> Void,
        onInsertVideo: @escaping () -> Void,
        onInsertPageBreak: @escaping () -> Void,
        onInsertTOC: @escaping () -> Void,
        onInsertBibliography: @escaping () -> Void,
        onToggleStrikethrough: @escaping () -> Void,
        onInsertBulletList: @escaping () -> Void,
        onInsertNumberedList: @escaping () -> Void
    ) {
        self._activeTool = activeTool
        self._fontFamily = fontFamily
        self._fontSize = fontSize
        self._isBold = isBold
        self._isItalic = isItalic
        self._isUnderline = isUnderline
        self._textAlignment = textAlignment
        self._pageSize = pageSize
        self._marginPreset = marginPreset
        self._margins = margins
        self._showMarginGuides = showMarginGuides
        self._showCropMarks = showCropMarks
        self._showOutlineDrawer = showOutlineDrawer
        self._showFindReplace = showFindReplace
        self.onToggleBold = onToggleBold
        self.onToggleItalic = onToggleItalic
        self.onToggleUnderline = onToggleUnderline
        self.onSetAlignment = onSetAlignment
        self.onSetFontFamily = onSetFontFamily
        self.onSetFontSize = onSetFontSize
        self.onInsertTable = onInsertTable
        self.onInsertSection = onInsertSection
        self.onAddSource = onAddSource
        self.onInsertImage = onInsertImage
        self.onInsertVideo = onInsertVideo
        self.onInsertPageBreak = onInsertPageBreak
        self.onInsertTOC = onInsertTOC
        self.onInsertBibliography = onInsertBibliography
        self.onToggleStrikethrough = onToggleStrikethrough
        self.onInsertBulletList = onInsertBulletList
        self.onInsertNumberedList = onInsertNumberedList
    }

    public var body: some View {
        VStack(spacing: 8) {
            // 1. Outline & Pages Toggle
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

            // 2. Primary Insert & Content Tools
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
            }

            Divider()
                .frame(width: 24)

            // 3. Typography & Styling Tools
            VStack(spacing: 4) {
                // Font Family Menu
                Menu {
                    Button("Default Serif (Georgia)") { onSetFontFamily("Default Serif (Georgia)") }
                    Button("Helvetica") { onSetFontFamily("Helvetica") }
                    Button("Times New Roman") { onSetFontFamily("Times New Roman") }
                    Button("SF Pro") { onSetFontFamily("SF Pro") }
                    Button("Menlo (Monospace)") { onSetFontFamily("Menlo (Monospace)") }
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 28)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .help("Font Family: \(fontFamily)")

                // Font Size Stepper
                HStack(spacing: 2) {
                    Button {
                        if fontSize > 9 { onSetFontSize(fontSize - 1) }
                    } label: {
                        Text("-")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 14, height: 22)
                    }
                    .buttonStyle(.plain)

                    Text("\(Int(fontSize))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .frame(width: 16)

                    Button {
                        if fontSize < 48 { onSetFontSize(fontSize + 1) }
                    } label: {
                        Text("+")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 14, height: 22)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                .help("Font Size (pt)")

                // Bold / Italic / Underline
                RailIconButton(icon: "bold", isActive: isBold, shortcut: "Bold (⌘B)") {
                    onToggleBold()
                }

                RailIconButton(icon: "italic", isActive: isItalic, shortcut: "Italic (⌘I)") {
                    onToggleItalic()
                }

                RailIconButton(icon: "underline", isActive: isUnderline, shortcut: "Underline (⌘U)") {
                    onToggleUnderline()
                }

                // Text Alignment Menu
                Menu {
                    Button("Align Left") { onSetAlignment(.leading) }
                    Button("Align Center") { onSetAlignment(.center) }
                    Button("Align Right") { onSetAlignment(.trailing) }
                } label: {
                    Image(systemName: textAlignment == .leading ? "text.alignleft" : textAlignment == .center ? "text.aligncenter" : "text.alignright")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 28)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .help("Text Alignment")

                // Advanced Typography & Lists Popover
                Button {
                    showingTypographyPopover.toggle()
                } label: {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(showingTypographyPopover ? .accentColor : .primary)
                        .frame(width: 32, height: 28)
                        .background(showingTypographyPopover ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Advanced Typography & Lists")
                .popover(isPresented: $showingTypographyPopover, arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Fine Typography & Lists")
                            .font(.system(size: 13, weight: .bold))

                        Divider()

                        // Strikethrough
                        Button {
                            onToggleStrikethrough()
                        } label: {
                            HStack {
                                Image(systemName: "strikethrough")
                                Text("Strikethrough")
                                Spacer()
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)

                        // Bullet List
                        Button {
                            onInsertBulletList()
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Bullet List (•)")
                                Spacer()
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)

                        // Numbered List
                        Button {
                            onInsertNumberedList()
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
                    .padding(14)
                    .frame(width: 200)
                }
            }

            Divider()
                .frame(width: 24)

            // 4. Page Setup & Guides Popover
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

            // 5. Find & Replace
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

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .accentColor : .primary)
                .frame(width: 32, height: 28)
                .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(shortcut)
    }
}
