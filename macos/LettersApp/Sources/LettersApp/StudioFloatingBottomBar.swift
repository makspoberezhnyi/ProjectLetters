import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct StudioFloatingBottomBar: View {
    let wordCount: Int
    let characterCount: Int
    let readingTimeMinutes: Int
    @Binding var citationStyle: CitationStyle
    @Binding var zoomScale: Double
    @Binding var showAIDrawer: Bool
    var onToast: ((String) -> Void)?

    public init(
        wordCount: Int,
        characterCount: Int,
        readingTimeMinutes: Int,
        citationStyle: Binding<CitationStyle>,
        zoomScale: Binding<Double>,
        showAIDrawer: Binding<Bool>,
        onToast: ((String) -> Void)? = nil
    ) {
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.readingTimeMinutes = readingTimeMinutes
        self._citationStyle = citationStyle
        self._zoomScale = zoomScale
        self._showAIDrawer = showAIDrawer
        self.onToast = onToast
    }

    public var body: some View {
        HStack(spacing: 12) {
            // 1. Word & Character Stats
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("\(wordCount) words")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("\(characterCount) chars")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("\(readingTimeMinutes)m read")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)

            Divider()
                .frame(height: 16)

            // 2. Citation Style Selector (Can be Plain / Off)
            Menu {
                ForEach(CitationStyle.allCases, id: \.self) { style in
                    Button {
                        citationStyle = style
                        onToast?("✓ Citation Style: \(style.displayName)")
                    } label: {
                        HStack {
                            Text(style.displayName)
                            if citationStyle == style {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 10))
                        .foregroundColor(citationStyle == .plain ? .secondary : .accentColor)

                    Text(citationStyle == .plain ? "Citations: Off" : citationStyle.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .help("Citation Standard Format")

            Divider()
                .frame(height: 16)

            // 3. Canvas Zoom / Scale Controls
            HStack(spacing: 2) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        zoomScale = max(0.4, zoomScale - 0.1)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 22)
                }
                .buttonStyle(.plain)
                .help("Zoom Out (⌘-)")

                Menu {
                    ForEach([0.5, 0.75, 0.9, 1.0, 1.15, 1.25, 1.5, 1.75, 2.0], id: \.self) { z in
                        Button("\(Int(z * 100))%") {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                zoomScale = z
                            }
                        }
                    }
                } label: {
                    Text("\(Int(zoomScale * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 38)
                }
                .menuStyle(.borderlessButton)
                .help("Canvas Zoom Presets")

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        zoomScale = min(2.5, zoomScale + 0.1)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 22)
                }
                .buttonStyle(.plain)
                .help("Zoom In (⌘+)")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))

            Divider()
                .frame(height: 16)

            // 4. AI Copilot Companion Button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAIDrawer.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)
                    Text("AI Copilot")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
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
            .help("Toggle AI Copilot Companion (⌘J)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}
