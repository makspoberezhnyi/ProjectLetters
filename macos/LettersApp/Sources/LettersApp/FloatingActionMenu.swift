import SwiftUI
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
    var onPolish: () -> Void
    var onTranslate: () -> Void
    var onExplain: () -> Void
    var onCite: () -> Void

    public init(
        selectedText: String,
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
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
        onPolish: @escaping () -> Void = {},
        onTranslate: @escaping () -> Void = {},
        onExplain: @escaping () -> Void = {},
        onCite: @escaping () -> Void = {}
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
        self.onPolish = onPolish
        self.onTranslate = onTranslate
        self.onExplain = onExplain
        self.onCite = onCite
    }

    private func shortFontName(_ name: String) -> String {
        if name.contains("Georgia") { return "Georgia" }
        if name.contains("Times") { return "Times" }
        if name.contains("SF Pro") { return "SF Pro" }
        if name.contains("Helvetica") { return "Helvetica" }
        if name.contains("Menlo") { return "Menlo" }
        if name.contains("Courier") { return "Courier" }
        if name.contains("Charter") { return "Charter" }
        return name
    }

    public var body: some View {
        HStack(spacing: 8) {
            // 1. Font Family Dropdown Menu
            Menu {
                Button("Georgia") { onSetFontFamily("Default Serif (Georgia)") }
                Button("Times New Roman") { onSetFontFamily("Times New Roman") }
                Button("SF Pro") { onSetFontFamily("SF Pro") }
                Button("Helvetica") { onSetFontFamily("Helvetica") }
                Button("Charter") { onSetFontFamily("Charter") }
                Button("Menlo (Monospace)") { onSetFontFamily("Menlo (Monospace)") }
                Button("Courier") { onSetFontFamily("Courier") }
            } label: {
                HStack(spacing: 4) {
                    Text(shortFontName(fontFamily))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Font: \(fontFamily)")

            // 2. Font Size Stepper & Quick Menu
            HStack(spacing: 1) {
                Button {
                    if fontSize > 8 { onSetFontSize(fontSize - 1) }
                } label: {
                    Text("−")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 16, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach([9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 24, 28, 32, 36, 48, 64], id: \.self) { pt in
                        Button("\(pt) pt") { onSetFontSize(CGFloat(pt)) }
                    }
                } label: {
                    Text("\(Int(fontSize))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    if fontSize < 96 { onSetFontSize(fontSize + 1) }
                } label: {
                    Text("+")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 16, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .help("Font Size (\(Int(fontSize)) pt)")

            Divider()
                .frame(height: 16)

            // 3. Bold, Italic, Underline, Strikethrough
            HStack(spacing: 2) {
                HUDToggleButton(icon: "bold", isActive: isBold, shortcut: "Bold (⌘B)") {
                    onBold()
                }
                HUDToggleButton(icon: "italic", isActive: isItalic, shortcut: "Italic (⌘I)") {
                    onItalic()
                }
                HUDToggleButton(icon: "underline", isActive: isUnderline, shortcut: "Underline (⌘U)") {
                    onUnderline()
                }
                HUDToggleButton(icon: "strikethrough", isActive: false, shortcut: "Strikethrough") {
                    onStrikethrough()
                }
            }

            Divider()
                .frame(height: 16)

            // 4. Alignment Menu
            Menu {
                Button { onSetAlignment(.leading) } label: { Label("Align Left", systemImage: "text.alignleft") }
                Button { onSetAlignment(.center) } label: { Label("Align Center", systemImage: "text.aligncenter") }
                Button { onSetAlignment(.trailing) } label: { Label("Align Right", systemImage: "text.alignright") }
            } label: {
                Image(systemName: textAlignment == .leading ? "text.alignleft" : (textAlignment == .center ? "text.aligncenter" : "text.alignright"))
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 22)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Text Alignment")

            // 5. Line Spacing / Leading Menu
            Menu {
                Button("1.0 (Single)") { onSetLineSpacing(1.0) }
                Button("1.15 (Standard)") { onSetLineSpacing(1.15) }
                Button("1.25 (Relaxed)") { onSetLineSpacing(1.25) }
                Button("1.5 (1.5x)") { onSetLineSpacing(1.5) }
                Button("2.0 (Double)") { onSetLineSpacing(2.0) }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.and.down.text.horizontal")
                        .font(.system(size: 11, weight: .medium))
                    Text(String(format: "%.2g", lineSpacing))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Line Spacing (\(String(format: "%.2g", lineSpacing)))")

            Divider()
                .frame(height: 16)

            // 6. AI & Citation Tools
            HStack(spacing: 4) {
                Button(action: onPolish) {
                    Label("Polish", systemImage: "wand.and.stars")
                        .font(.system(size: 11, weight: .medium))
                }
                .help("AI Academic & Flow Polish")

                Button(action: onTranslate) {
                    Label("Translate", systemImage: "translate")
                        .font(.system(size: 11, weight: .medium))
                }
                .help("Offline Translation")

                Button(action: onExplain) {
                    Label("Explain", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                }
                .help("AI Contextual Explanation")

                Button(action: onCite) {
                    Label("Cite", systemImage: "quote.bubble")
                        .font(.system(size: 11, weight: .medium))
                }
                .help("Insert Linked Source Citation")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 4)
    }
}

struct HUDToggleButton: View {
    let icon: String
    let isActive: Bool
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .accentColor : .primary)
                .frame(width: 22, height: 22)
                .background(isActive ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(shortcut)
    }
}
