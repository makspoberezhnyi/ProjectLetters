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
    @Binding var styleProfile: String
    var lintIssues: [StyleLintMatch] = []
    var onApplyLintFix: ((StyleLintMatch) -> Void)? = nil
    var onToast: ((String) -> Void)?

    @State private var isCitationHovered: Bool = false
    @State private var isZoomMinusHovered: Bool = false
    @State private var isZoomPlusHovered: Bool = false
    @State private var isAIHovered: Bool = false
    @State private var showLintPopover: Bool = false

    public init(
        wordCount: Int,
        characterCount: Int,
        readingTimeMinutes: Int,
        citationStyle: Binding<CitationStyle>,
        zoomScale: Binding<Double>,
        showAIDrawer: Binding<Bool>,
        styleProfile: Binding<String> = .constant("none"),
        lintIssues: [StyleLintMatch] = [],
        onApplyLintFix: ((StyleLintMatch) -> Void)? = nil,
        onToast: ((String) -> Void)? = nil
    ) {
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.readingTimeMinutes = readingTimeMinutes
        self._citationStyle = citationStyle
        self._zoomScale = zoomScale
        self._showAIDrawer = showAIDrawer
        self._styleProfile = styleProfile
        self.lintIssues = lintIssues
        self.onApplyLintFix = onApplyLintFix
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
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("\(characterCount) chars")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("\(readingTimeMinutes)m read")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .fixedSize(horizontal: true, vertical: false)

            Divider()
                .frame(height: 16)

            // 2. Style & Citation Linter Pill
            Button {
                showLintPopover.toggle()
            } label: {
                HStack(spacing: 5) {
                    if styleProfile == "none" {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text("Style: Standard")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Image(systemName: lintIssues.isEmpty ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(lintIssues.isEmpty ? .green : .orange)

                        Text(lintIssues.isEmpty ? "\(styleProfile.capitalized): Clean" : "\(lintIssues.count) \(styleProfile.capitalized) Notices")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(lintIssues.isEmpty ? .secondary : .orange)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(styleProfile == "none" || lintIssues.isEmpty ? Color.primary.opacity(0.04) : Color.orange.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showLintPopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.accentColor)
                        Text("Style Profile & Quality")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        if styleProfile != "none" {
                            Text("\(lintIssues.count) notices")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Document Style Standard:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $styleProfile) {
                            Text("None (Standard)").tag("none")
                            Text("Academic").tag("academic")
                            Text("Plain English").tag("plain")
                            Text("Legal Brief").tag("legal")
                        }
                        .pickerStyle(.segmented)
                    }

                    if styleProfile == "none" {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield")
                                .foregroundColor(.secondary)
                            Text("Standard writing mode active. No prescriptive style or contraction warnings are imposed.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if lintIssues.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No \(styleProfile.capitalized) style or citation issues detected. Prose is clean!")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(lintIssues) { issue in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(issue.ruleId.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.orange)
                                            Spacer()
                                            if let sugg = issue.suggestion, !sugg.isEmpty {
                                                Button("Apply Fix") {
                                                    onApplyLintFix?(issue)
                                                    showLintPopover = false
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .controlSize(.mini)
                                            }
                                        }
                                        Text(issue.message)
                                            .font(.system(size: 11))
                                            .foregroundColor(.primary)
                                        if let sugg = issue.suggestion, !sugg.isEmpty {
                                            HStack(spacing: 4) {
                                                Text("Fix:")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.secondary)
                                                Text(sugg)
                                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .frame(maxHeight: 260)
                    }
                }
                .padding(12)
                .frame(width: 440)
            }
            .help("Academic Prose & Citation Linter")

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
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isCitationHovered ? StudioTheme.hoverHighlight : Color.primary.opacity(0.04))
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isCitationHovered = hovering
                }
            }
            .help("Citation Standard Format")

            Spacer(minLength: 8)

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
                        .frame(width: 20, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isZoomMinusHovered ? StudioTheme.hoverHighlight : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isZoomMinusHovered = hovering
                    }
                }
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(width: 38)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Canvas Zoom Presets")

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        zoomScale = min(2.5, zoomScale + 0.1)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isZoomPlusHovered ? StudioTheme.hoverHighlight : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isZoomPlusHovered = hovering
                    }
                }
                .help("Zoom In (⌘+)")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            .fixedSize()

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
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(showAIDrawer ? Color.purple.opacity(0.22) : (isAIHovered ? Color.purple.opacity(0.15) : Color.purple.opacity(0.08)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.purple.opacity(showAIDrawer ? 0.6 : 0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .onHover { hovering in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                    isAIHovered = hovering
                }
            }
            .help("Toggle AI Copilot Companion (⌘J)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .top
        )
    }
}
