import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

public struct FloatingActionMenu: View {
    let selectedText: String
    var fontFamily: String
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var isKeepLinesTogether: Bool
    var isKeepWithNext: Bool
    var textAlignment: TextAlignment
    var lineSpacing: CGFloat

    var onBold: () -> Void
    var onItalic: () -> Void
    var onUnderline: () -> Void
    var onStrikethrough: () -> Void
    var onSetFontFamily: (String) -> Void
    var onSetFontSize: (CGFloat) -> Void
    var onSetAlignment: (TextAlignment) -> Void
    var onSetLineSpacing: (CGFloat) -> Void
    var onSetParagraphSpacing: (CGFloat) -> Void
    var onSetTextColor: (NSColor) -> Void
    var onSetTextHighlight: (NSColor?) -> Void
    var onClearFormatting: () -> Void
    var onAskAI: () -> Void
    var onPolish: () -> Void
    var onTranslate: () -> Void
    var onExplain: () -> Void
    var onCite: () -> Void
    var onCommandPalette: () -> Void
    var onAddFootnote: () -> Void
    var onAddSideNote: () -> Void
    var onAddCrossReference: () -> Void
    var onToggleKeepLinesTogether: () -> Void
    var onToggleKeepWithNext: () -> Void

    @State private var customTextColor: Color = Color(red: 0.10, green: 0.10, blue: 0.12)
    @State private var customHighlightColor: Color = .yellow
    @State private var showTextColorPopover: Bool = false
    @State private var showHighlightColorPopover: Bool = false
    @State private var recentTextColors: [Color] = []
    @State private var recentHighlightColors: [Color] = []

    public init(
        selectedText: String,
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isKeepLinesTogether: Bool = false,
        isKeepWithNext: Bool = false,
        textAlignment: TextAlignment = .leading,
        lineSpacing: CGFloat = 1.15,
        onBold: @escaping () -> Void,
        onItalic: @escaping () -> Void,
        onUnderline: @escaping () -> Void = {},
        onStrikethrough: @escaping () -> Void = {},
        onSetFontFamily: @escaping (String) -> Void = { _ in },
        onSetFontSize: @escaping (CGFloat) -> Void = { _ in },
        onSetAlignment: @escaping (TextAlignment) -> Void = { _ in },
        onSetLineSpacing: @escaping (CGFloat) -> Void = { _ in },
        onSetParagraphSpacing: @escaping (CGFloat) -> Void = { _ in },
        onSetTextColor: @escaping (NSColor) -> Void = { _ in },
        onSetTextHighlight: @escaping (NSColor?) -> Void = { _ in },
        onClearFormatting: @escaping () -> Void = {},
        onAskAI: @escaping () -> Void = {},
        onPolish: @escaping () -> Void = {},
        onTranslate: @escaping () -> Void = {},
        onExplain: @escaping () -> Void = {},
        onCite: @escaping () -> Void = {},
        onCommandPalette: @escaping () -> Void = {},
        onAddFootnote: @escaping () -> Void = {},
        onAddSideNote: @escaping () -> Void = {},
        onAddCrossReference: @escaping () -> Void = {},
        onToggleKeepLinesTogether: @escaping () -> Void = {},
        onToggleKeepWithNext: @escaping () -> Void = {}
    ) {
        self.selectedText = selectedText
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.textAlignment = textAlignment
        self.lineSpacing = lineSpacing
        self.onBold = onBold
        self.onItalic = onItalic
        self.onUnderline = onUnderline
        self.onStrikethrough = onStrikethrough
        self.onSetFontFamily = onSetFontFamily
        self.onSetFontSize = onSetFontSize
        self.onSetAlignment = onSetAlignment
        self.onSetLineSpacing = onSetLineSpacing
        self.onSetParagraphSpacing = onSetParagraphSpacing
        self.onSetTextColor = onSetTextColor
        self.onSetTextHighlight = onSetTextHighlight
        self.onClearFormatting = onClearFormatting
        self.onAskAI = onAskAI
        self.onPolish = onPolish
        self.onTranslate = onTranslate
        self.onExplain = onExplain
        self.onCite = onCite
        self.onCommandPalette = onCommandPalette
        self.onAddFootnote = onAddFootnote
        self.onAddSideNote = onAddSideNote
        self.onAddCrossReference = onAddCrossReference
        self.isKeepLinesTogether = isKeepLinesTogether
        self.isKeepWithNext = isKeepWithNext
        self.onToggleKeepLinesTogether = onToggleKeepLinesTogether
        self.onToggleKeepWithNext = onToggleKeepWithNext
    }

    private func shortFontName(_ name: String) -> String {
        if name.contains("Georgia") { return "Georgia" }
        if name.contains("Times") { return "Times" }
        if name.contains("SF Pro") || name == "System" { return "SF Pro" }
        if name.contains("New York") { return "New York" }
        if name.contains("Helvetica") { return "Helvetica" }
        if name.contains("Avenir") { return "Avenir" }
        if name.contains("Baskerville") { return "Baskerville" }
        if name.contains("Palatino") { return "Palatino" }
        if name.contains("Menlo") || name.contains("SF Mono") { return "Menlo" }
        if name.contains("Courier") { return "Courier" }
        if name.contains("Charter") { return "Charter" }
        return name
    }

    public var body: some View {
        HStack(spacing: 6) {
            // 1. AI & Intelligent Tools (Inline Canvas Ask AI + Quick Tools)
            HStack(spacing: 4) {
                Button(action: onAskAI) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text("Ask AI")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .foregroundColor(.white)
                    .shadow(color: Color.purple.opacity(0.25), radius: 4, x: 0, y: 1.5)
                }
                .buttonStyle(.plain)
                .help("Ask AI to edit, rewrite or transform selection (⌘J)")

                HUDActionButton(icon: "wand.and.stars", color: .purple, help: "AI Polish & Academic Flow") {
                    onPolish()
                }
                HUDActionButton(icon: "translate", color: .blue, help: "Instant Translate") {
                    onTranslate()
                }
            }

            Divider()
                .frame(height: 14)

            // 2. Academic & Editorial Annotations
            HStack(spacing: 3) {
                HUDActionButton(icon: "quote.bubble", color: .teal, help: "Insert Linked Citation") {
                    onCite()
                }
                HUDActionButton(icon: "text.insert", color: .orange, help: "Insert Footnote") {
                    onAddFootnote()
                }
                HUDActionButton(icon: "note.text", color: .yellow, help: "Insert Side Note") {
                    onAddSideNote()
                }
                HUDActionButton(icon: "link", color: .green, help: "Insert Cross Reference") {
                    onAddCrossReference()
                }
            }

            Divider()
                .frame(height: 14)

            // 3. Text Color, Highlight & Formatting
            HStack(spacing: 3) {
                Button(action: { showTextColorPopover.toggle() }) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Text Color & Palette (Word-Style)")
                .popover(isPresented: $showTextColorPopover, arrowEdge: .bottom) {
                    WordStyleColorPaletteView(
                        title: "Text Color",
                        selectedColor: $customTextColor,
                        isHighlight: false,
                        allowNoColor: true,
                        clearTitle: "Default Color",
                        onSelectColor: { newColor in
                            customTextColor = newColor
                            onSetTextColor(NSColor(newColor))
                        },
                        onClearColor: {
                            let defaultColor = Color(red: 0.10, green: 0.10, blue: 0.12)
                            customTextColor = defaultColor
                            onSetTextColor(NSColor(defaultColor))
                            showTextColorPopover = false
                        },
                        onDismiss: {
                            showTextColorPopover = false
                        }
                    )
                }

                Button(action: { showHighlightColorPopover.toggle() }) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Text Highlight & Palette (Word-Style)")
                .popover(isPresented: $showHighlightColorPopover, arrowEdge: .bottom) {
                    WordStyleColorPaletteView(
                        title: "Highlight Color",
                        selectedColor: $customHighlightColor,
                        isHighlight: true,
                        allowNoColor: true,
                        clearTitle: "No Highlight",
                        onSelectColor: { newColor in
                            customHighlightColor = newColor
                            onSetTextHighlight(NSColor(newColor).withAlphaComponent(0.42))
                        },
                        onClearColor: {
                            onSetTextHighlight(nil)
                            showHighlightColorPopover = false
                        },
                        onDismiss: {
                            showHighlightColorPopover = false
                        }
                    )
                }

                HUDActionButton(icon: "eraser", color: .secondary, help: "Clear Formatting (Return to Default)") {
                    onClearFormatting()
                }
            }

            Divider()
                .frame(height: 14)

            // 4. Keep Rules & Strikethrough
            HStack(spacing: 2) {
                HUDToggleButton(icon: "strikethrough", isActive: false, shortcut: "Strikethrough (⇧⌘X)") {
                    onStrikethrough()
                }
                HUDToggleButton(icon: "rectangle.arrowtriangle.2.inward", isActive: isKeepLinesTogether, shortcut: "Keep Lines Together") {
                    onToggleKeepLinesTogether()
                }
                HUDToggleButton(icon: "arrow.down.to.line.compact", isActive: isKeepWithNext, shortcut: "Keep With Next") {
                    onToggleKeepWithNext()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .fixedSize()
        .background(.ultraThickMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 6)
    }
}

struct HUDToggleButton: View {
    let icon: String
    let isActive: Bool
    let shortcut: String
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .accentColor : (isHovered ? .primary : .secondary))
                .frame(width: 22, height: 22)
                .background(
                    isActive
                        ? Color.accentColor.opacity(0.18)
                        : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(shortcut)
    }
}

struct HUDActionButton: View {
    let icon: String
    var color: Color = .primary
    let help: String
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHovered ? color : .secondary)
                .frame(width: 22, height: 22)
                .background(
                    isHovered ? color.opacity(0.14) : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}
