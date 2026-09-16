import SwiftUI
import LettersKit

public struct FloatingActionMenu: View {
    let selectedText: String
    var onBold: () -> Void
    var onItalic: () -> Void
    var onTranslate: () -> Void
    var onExplain: () -> Void
    var onCite: () -> Void

    public init(
        selectedText: String,
        onBold: @escaping () -> Void,
        onItalic: @escaping () -> Void,
        onTranslate: @escaping () -> Void,
        onExplain: @escaping () -> Void,
        onCite: @escaping () -> Void
    ) {
        self.selectedText = selectedText
        self.onBold = onBold
        self.onItalic = onItalic
        self.onTranslate = onTranslate
        self.onExplain = onExplain
        self.onCite = onCite
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button(action: onBold) {
                Image(systemName: "bold")
                    .font(.system(size: 13, weight: .semibold))
            }
            .help("Bold (Cmd+B)")

            Button(action: onItalic) {
                Image(systemName: "italic")
                    .font(.system(size: 13, weight: .semibold))
            }
            .help("Italic (Cmd+I)")

            Divider()
                .frame(height: 16)

            Button(action: onTranslate) {
                Label("Translate", systemImage: "translate")
                    .font(.system(size: 12))
            }
            .help("Offline Translation")

            Button(action: onExplain) {
                Label("Explain", systemImage: "sparkles")
                    .font(.system(size: 12))
            }
            .help("AI Contextual Explanation")

            Button(action: onCite) {
                Label("Cite", systemImage: "quote.bubble")
                    .font(.system(size: 12))
            }
            .help("Insert Linked Source Citation")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
