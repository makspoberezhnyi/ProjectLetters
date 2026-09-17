import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct FloatingStudioHUD: View {
    @Binding var fontFamily: String
    @Binding var fontSize: CGFloat
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderline: Bool
    @Binding var textAlignment: TextAlignment
    @Binding var lineSpacing: CGFloat
    @Binding var pageSize: PageSizePreset
    @Binding var marginPreset: MarginPreset
    @Binding var margins: PageMargins
    @Binding var showMarginGuides: Bool
    @Binding var showCropMarks: Bool
    @Binding var zoomScale: Double
    @Binding var showAIDrawer: Bool
    @Binding var showOutlineDrawer: Bool

    var onToggleBold: () -> Void
    var onToggleItalic: () -> Void
    var onToggleUnderline: () -> Void
    var onSetAlignment: (TextAlignment) -> Void
    var onSetFontFamily: (String) -> Void
    var onSetFontSize: (CGFloat) -> Void
    var onInsertTable: () -> Void
    var onInsertSection: () -> Void
    var onAddSource: () -> Void

    @State private var showingPageLayoutPopover: Bool = false
    @State private var showingInsertMenu: Bool = false

    let availableFonts = ["Default Serif (Georgia)", "Modern Sans (SF Pro)", "Times New Roman", "Helvetica Neue", "Courier Prime", "Charter"]
    let availableSizes: [CGFloat] = [9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 24, 32, 48]

    public init(
        fontFamily: Binding<String>,
        fontSize: Binding<CGFloat>,
        isBold: Binding<Bool>,
        isItalic: Binding<Bool>,
        isUnderline: Binding<Bool>,
        textAlignment: Binding<TextAlignment>,
        lineSpacing: Binding<CGFloat>,
        pageSize: Binding<PageSizePreset>,
        marginPreset: Binding<MarginPreset>,
        margins: Binding<PageMargins>,
        showMarginGuides: Binding<Bool>,
        showCropMarks: Binding<Bool>,
        zoomScale: Binding<Double>,
        showAIDrawer: Binding<Bool>,
        showOutlineDrawer: Binding<Bool>,
        onToggleBold: @escaping () -> Void,
        onToggleItalic: @escaping () -> Void,
        onToggleUnderline: @escaping () -> Void,
        onSetAlignment: @escaping (TextAlignment) -> Void,
        onSetFontFamily: @escaping (String) -> Void,
        onSetFontSize: @escaping (CGFloat) -> Void,
        onInsertTable: @escaping () -> Void,
        onInsertSection: @escaping () -> Void,
        onAddSource: @escaping () -> Void
    ) {
        self._fontFamily = fontFamily
        self._fontSize = fontSize
        self._isBold = isBold
        self._isItalic = isItalic
        self._isUnderline = isUnderline
        self._textAlignment = textAlignment
        self._lineSpacing = lineSpacing
        self._pageSize = pageSize
        self._marginPreset = marginPreset
        self._margins = margins
        self._showMarginGuides = showMarginGuides
        self._showCropMarks = showCropMarks
        self._zoomScale = zoomScale
        self._showAIDrawer = showAIDrawer
        self._showOutlineDrawer = showOutlineDrawer
        self.onToggleBold = onToggleBold
        self.onToggleItalic = onToggleItalic
        self.onToggleUnderline = onToggleUnderline
        self.onSetAlignment = onSetAlignment
        self.onSetFontFamily = onSetFontFamily
        self.onSetFontSize = onSetFontSize
        self.onInsertTable = onInsertTable
        self.onInsertSection = onInsertSection
        self.onAddSource = onAddSource
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Group 1: Navigation & Outline Toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showOutlineDrawer.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Pages")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(showOutlineDrawer ? .accentColor : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(showOutlineDrawer ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Toggle Pages & Outline Navigator")

            Divider()
                .frame(height: 18)

            // Group 2: Typography & Formatting
            HStack(spacing: 4) {
                // Font Family Menu
                Menu {
                    ForEach(availableFonts, id: \.self) { font in
                        Button(font) {
                            fontFamily = font
                            onSetFontFamily(font)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(fontFamily.components(separatedBy: " ").first ?? fontFamily)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .help("Font Family")

                // Font Size Menu
                Menu {
                    ForEach(availableSizes, id: \.self) { size in
                        Button("\(Int(size)) pt") {
                            fontSize = size
                            onSetFontSize(size)
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("\(Int(fontSize))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .help("Font Size")

                // Styles: Bold, Italic, Underline
                HStack(spacing: 2) {
                    HUDIconButton(icon: "bold", isActive: isBold, shortcut: "⌘B", action: onToggleBold)
                    HUDIconButton(icon: "italic", isActive: isItalic, shortcut: "⌘I", action: onToggleItalic)
                    HUDIconButton(icon: "underline", isActive: isUnderline, shortcut: "⌘U", action: onToggleUnderline)
                }
                .padding(2)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))

                // Alignments
                HStack(spacing: 2) {
                    HUDIconButton(icon: "text.alignleft", isActive: textAlignment == .leading, shortcut: "Left Align") {
                        onSetAlignment(.leading)
                    }
                    HUDIconButton(icon: "text.aligncenter", isActive: textAlignment == .center, shortcut: "Center Align") {
                        onSetAlignment(.center)
                    }
                    HUDIconButton(icon: "text.alignright", isActive: textAlignment == .trailing, shortcut: "Right Align") {
                        onSetAlignment(.trailing)
                    }
                }
                .padding(2)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            }

            Divider()
                .frame(height: 18)

            // Group 3: Insert Menu (+ Table, + Section, + Citation)
            Menu {
                Button {
                    onInsertTable()
                } label: {
                    Label("Smart Interactive Table", systemImage: "tablecells")
                }

                Button {
                    onInsertSection()
                } label: {
                    Label("New Text Section", systemImage: "text.quote")
                }

                Button {
                    onAddSource()
                } label: {
                    Label("Linked Source Citation", systemImage: "quote.opening")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("Insert")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .help("Insert Table, Section, or Citation")

            Divider()
                .frame(height: 18)

            // Group 4: Page Layout Popover Button
            Button {
                showingPageLayoutPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 12, weight: .medium))
                    Text("Page")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(showingPageLayoutPopover ? .accentColor : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(showingPageLayoutPopover ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPageLayoutPopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Page Setup & Margins")
                        .font(.system(size: 13, weight: .bold))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Page Format")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Page Format", selection: $pageSize) {
                                ForEach(PageSizePreset.allCases, id: \.self) { size in
                                    Text("\(size.rawValue) (\(size.subtitle))").tag(size)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }

                        HStack {
                            Text("Margins")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Margins Preset", selection: $marginPreset) {
                                ForEach(MarginPreset.allCases, id: \.self) { preset in
                                    Text(preset.rawValue).tag(preset)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                            .onChange(of: marginPreset) { _, newPreset in
                                margins = newPreset.margins
                            }
                        }

                        Divider()

                        Toggle("Show Margin Guides", isOn: $showMarginGuides)
                            .font(.system(size: 12))

                        Toggle("Show Publisher Crop Marks", isOn: $showCropMarks)
                            .font(.system(size: 12))
                    }

                    Divider()

                    // Zoom Scale
                    HStack {
                        Text("Zoom")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("50%") { zoomScale = 0.5 }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        Button("100%") { zoomScale = 1.0 }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                        Button("150%") { zoomScale = 1.5 }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                    }
                }
                .padding(14)
                .frame(width: 260)
            }
            .help("Page Setup, Margins & Zoom")

            Divider()
                .frame(height: 18)

            // Group 5: AI Copilot Companion Trigger (Glow / Highlight)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAIDrawer.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.purple)
                    Text("AI Copilot")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(showAIDrawer ? Color.purple.opacity(0.2) : Color.purple.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.purple.opacity(showAIDrawer ? 0.6 : 0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Toggle AI Copilot Companion")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}

struct HUDIconButton: View {
    let icon: String
    let isActive: Bool
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .accentColor : .primary)
                .frame(width: 24, height: 22)
                .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(shortcut)
    }
}
