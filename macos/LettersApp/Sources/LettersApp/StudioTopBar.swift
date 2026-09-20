import SwiftUI

public enum StudioPersona: String, CaseIterable, Identifiable {
    case write = "Write"
    case typography = "Typography"
    case citations = "Citations"
    case aiStudio = "AI Studio"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .write: return "square.and.pencil"
        case .typography: return "textformat"
        case .citations: return "quote.opening"
        case .aiStudio: return "sparkles"
        }
    }
}

public struct StudioTopBar: View {
    @Binding var activePersona: StudioPersona
    @Binding var fontFamily: String
    @Binding var fontSize: CGFloat
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderline: Bool
    @Binding var alignment: TextAlignment
    @Binding var lineSpacing: CGFloat
    var onSelectPersona: ((StudioPersona) -> Void)? = nil
    var onToggleBold: (() -> Void)? = nil
    var onToggleItalic: (() -> Void)? = nil
    var onToggleUnderline: (() -> Void)? = nil
    var onSetAlignment: ((TextAlignment) -> Void)? = nil
    var onSetFontFamily: ((String) -> Void)? = nil
    var onSetFontSize: ((CGFloat) -> Void)? = nil
    var onExportDocx: () -> Void
    var onSaveMarkdown: () -> Void
    var onToggleInspector: () -> Void

    let availableFonts = ["Default Serif (Georgia)", "Modern Sans (SF Pro)", "Times New Roman", "Helvetica Neue", "Courier Prime", "Charter"]
    let availableSizes: [CGFloat] = [9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 24, 32, 48]

    public var body: some View {
        HStack(spacing: 12) {
            // App Brand + Persona Switcher
            HStack(spacing: 2) {
                ForEach(StudioPersona.allCases) { persona in
                    Button {
                        activePersona = persona
                        onSelectPersona?(persona)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: persona.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(persona.rawValue)
                                .font(.system(size: 11, weight: activePersona == persona ? .bold : .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(activePersona == persona ? StudioTheme.surfaceHighlight : Color.clear)
                        )
                        .foregroundColor(activePersona == persona ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Divider()
                .frame(height: 18)

            // Contextual Typography Strip
            HStack(spacing: 8) {
                // Font Family Menu
                Menu {
                    ForEach(availableFonts, id: \.self) { font in
                        Button(font) {
                            fontFamily = font
                            onSetFontFamily?(font)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(fontFamily)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .frame(maxWidth: 130, alignment: .leading)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 5))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 145)

                // Font Size Menu
                Menu {
                    ForEach(availableSizes, id: \.self) { size in
                        Button("\(Int(size)) pt") {
                            fontSize = size
                            onSetFontSize?(size)
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("\(Int(fontSize)) pt")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 5))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 65)

                // Styles: Bold, Italic, Underline
                HStack(spacing: 2) {
                    ToggleStyleButton(icon: "bold", isActive: $isBold, shortcut: "⌘B", onTrigger: onToggleBold)
                    ToggleStyleButton(icon: "italic", isActive: $isItalic, shortcut: "⌘I", onTrigger: onToggleItalic)
                    ToggleStyleButton(icon: "underline", isActive: $isUnderline, shortcut: "⌘U", onTrigger: onToggleUnderline)
                }
                .padding(2)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))

                // Alignments: Left, Center, Right
                HStack(spacing: 2) {
                    Button {
                        alignment = .leading
                        onSetAlignment?(.leading)
                    } label: {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 12))
                            .foregroundColor(alignment == .leading ? .accentColor : .secondary)
                            .frame(width: 24, height: 22)
                            .background(alignment == .leading ? StudioTheme.surfaceHighlight : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button {
                        alignment = .center
                        onSetAlignment?(.center)
                    } label: {
                        Image(systemName: "text.aligncenter")
                            .font(.system(size: 12))
                            .foregroundColor(alignment == .center ? .accentColor : .secondary)
                            .frame(width: 24, height: 22)
                            .background(alignment == .center ? StudioTheme.surfaceHighlight : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button {
                        alignment = .trailing
                        onSetAlignment?(.trailing)
                    } label: {
                        Image(systemName: "text.alignright")
                            .font(.system(size: 12))
                            .foregroundColor(alignment == .trailing ? .accentColor : .secondary)
                            .frame(width: 24, height: 22)
                            .background(alignment == .trailing ? StudioTheme.surfaceHighlight : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(2)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
            }

            Spacer()

            // Pro Export & Action Strip
            HStack(spacing: 8) {
                Button(action: onExportDocx) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 11))
                        Text("Export Word (.docx)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Export native Word .docx file (Cmd+S)")

                Button(action: onToggleInspector) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 26)
                        .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Toggle Studio Inspector")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .bottom
        )
    }
}

struct ToggleStyleButton: View {
    let icon: String
    @Binding var isActive: Bool
    let shortcut: String
    var onTrigger: (() -> Void)? = nil

    var body: some View {
        Button {
            isActive.toggle()
            onTrigger?()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActive ? .accentColor : .secondary)
                .frame(width: 24, height: 22)
                .background(isActive ? StudioTheme.surfaceHighlight : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(shortcut)
    }
}

