import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct StudioInspectorView: View {
    @Binding var activePersona: StudioPersona
    @Binding var rawText: String
    @Binding var selectedText: String
    @Binding var sources: [String: Source]
    @Binding var activeCitationStyle: CitationStyle
    @Binding var lintIssues: [StyleLintMatch]
    @Binding var lineSpacing: CGFloat
    @Binding var paragraphSpacing: CGFloat
    @Binding var pageSize: PageSizePreset
    @Binding var marginPreset: MarginPreset
    @Binding var margins: PageMargins
    @Binding var showMarginGuides: Bool
    @Binding var showCropMarks: Bool
    let currentDocumentContext: () -> String
    var onRunLinter: () -> Void
    var onAddSource: () -> Void
    var onToast: ((String) -> Void)?

    @State private var isPageSetupExpanded = true
    @State private var isTypographyExpanded = true
    @State private var isSourcesExpanded = true
    @State private var isLinterExpanded = true
    @State private var isCopilotExpanded = true

    public init(
        activePersona: Binding<StudioPersona>,
        rawText: Binding<String>,
        selectedText: Binding<String>,
        sources: Binding<[String: Source]>,
        activeCitationStyle: Binding<CitationStyle>,
        lintIssues: Binding<[StyleLintMatch]>,
        lineSpacing: Binding<CGFloat>,
        paragraphSpacing: Binding<CGFloat>,
        pageSize: Binding<PageSizePreset>,
        marginPreset: Binding<MarginPreset>,
        margins: Binding<PageMargins>,
        showMarginGuides: Binding<Bool>,
        showCropMarks: Binding<Bool>,
        currentDocumentContext: @escaping () -> String,
        onRunLinter: @escaping () -> Void,
        onAddSource: @escaping () -> Void,
        onToast: ((String) -> Void)? = nil
    ) {
        self._activePersona = activePersona
        self._rawText = rawText
        self._selectedText = selectedText
        self._sources = sources
        self._activeCitationStyle = activeCitationStyle
        self._lintIssues = lintIssues
        self._lineSpacing = lineSpacing
        self._paragraphSpacing = paragraphSpacing
        self._pageSize = pageSize
        self._marginPreset = marginPreset
        self._margins = margins
        self._showMarginGuides = showMarginGuides
        self._showCropMarks = showCropMarks
        self.currentDocumentContext = currentDocumentContext
        self.onRunLinter = onRunLinter
        self.onAddSource = onAddSource
        self.onToast = onToast
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Section 1: Page Setup & Margins (Affinity / InDesign Style)
                DisclosureGroup("Page Setup & Margins", isExpanded: $isPageSetupExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Page Size
                        HStack {
                            Text("Page Format")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Page Format", selection: $pageSize) {
                                ForEach(PageSizePreset.allCases, id: \.self) { size in
                                    Text("\(size.rawValue) (\(size.subtitle))").tag(size)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 145)
                        }

                        // Margins Preset
                        HStack {
                            Text("Margins")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Margins Preset", selection: $marginPreset) {
                                ForEach(MarginPreset.allCases, id: \.self) { preset in
                                    Text(preset.rawValue).tag(preset)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 145)
                            .onChange(of: marginPreset) { _, newPreset in
                                if newPreset != .custom {
                                    margins = newPreset.margins
                                }
                            }
                        }

                        // Custom Margins Insets (when Custom selected)
                        if marginPreset == .custom {
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Top: \(Int(margins.top)) pt").font(.system(size: 9)).foregroundColor(.secondary)
                                        Slider(value: $margins.top, in: 18...144, step: 6)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Bottom: \(Int(margins.bottom)) pt").font(.system(size: 9)).foregroundColor(.secondary)
                                        Slider(value: $margins.bottom, in: 18...144, step: 6)
                                    }
                                }
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Left: \(Int(margins.left)) pt").font(.system(size: 9)).foregroundColor(.secondary)
                                        Slider(value: $margins.left, in: 18...144, step: 6)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Right: \(Int(margins.right)) pt").font(.system(size: 9)).foregroundColor(.secondary)
                                        Slider(value: $margins.right, in: 18...144, step: 6)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }

                        Divider()
                            .padding(.vertical, 2)

                        // Margin Guides & Crop Marks Toggles
                        Toggle("Show Margin Guides", isOn: $showMarginGuides)
                            .font(.caption)
                        Toggle("Show Corner Crop Marks", isOn: $showCropMarks)
                            .font(.caption)
                    }
                    .padding(8)
                    .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 6))
                }
                .font(.caption.bold())

                Divider()

                // Section 2: Typography & Spacing
                DisclosureGroup("Typography & Spacing", isExpanded: $isTypographyExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Line Spacing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Line Spacing", selection: $lineSpacing) {
                                Text("1.0 (Single)").tag(CGFloat(1.0))
                                Text("1.15 (Standard)").tag(CGFloat(1.15))
                                Text("1.25 (Relaxed)").tag(CGFloat(1.25))
                                Text("1.5 (Academic)").tag(CGFloat(1.5))
                                Text("2.0 (Double)").tag(CGFloat(2.0))
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }

                        HStack {
                            Text("Paragraph Space")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Paragraph Spacing", selection: $paragraphSpacing) {
                                Text("6 pt").tag(CGFloat(6.0))
                                Text("12 pt").tag(CGFloat(12.0))
                                Text("18 pt").tag(CGFloat(18.0))
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                    }
                    .padding(8)
                    .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 6))
                }
                .font(.caption.bold())

                Divider()

                // Section 3: Linked Citations (CSL Profiles)
                DisclosureGroup("Linked Citations & Styles", isExpanded: $isSourcesExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Picker("Style", selection: $activeCitationStyle) {
                                ForEach(CitationStyle.allCases, id: \.self) { s in
                                    Text(s.displayName).tag(s)
                                }
                            }
                            .labelsHidden()

                            Spacer()

                            Button(action: onAddSource) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Add Linked Source")
                        }

                        if sources.isEmpty {
                            Text("No sources linked. Click + to add a citation.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(sources.values), id: \.id) { src in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(src.title)
                                        .font(.caption.bold())
                                        .lineLimit(1)
                                    Text(src.authors.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .padding(8)
                    .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 6))
                }
                .font(.caption.bold())

                Divider()

                // Section 4: Style Rules & Lint Warnings
                DisclosureGroup("Style Rules & Linting (\(lintIssues.count))", isExpanded: $isLinterExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Profile: Academic Standard")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Scan") {
                                onRunLinter()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }

                        if lintIssues.isEmpty {
                            Text("✓ All style rules passed!")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            ForEach(lintIssues) { issue in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption2)
                                        Text(issue.ruleId)
                                            .font(.caption2.bold())
                                    }
                                    Text(issue.message)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .padding(8)
                    .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 6))
                }
                .font(.caption.bold())

                Divider()

                // Section 5: AI Copilot Assistant Companion (Direct Sheet Manipulation)
                DisclosureGroup("AI Copilot Assistant", isExpanded: $isCopilotExpanded) {
                    AssistantSidebarView(
                        rawText: $rawText,
                        selectedText: $selectedText,
                        onToast: onToast,
                        currentDocumentContext: currentDocumentContext
                    )
                }
                .font(.caption.bold())
            }
            .padding(12)
        }
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .leading
        )
        .onChange(of: activePersona) { _, newPersona in
            switch newPersona {
            case .typography:
                isTypographyExpanded = true
            case .citations:
                isSourcesExpanded = true
            case .aiStudio:
                isCopilotExpanded = true
            case .write:
                break
            }
        }
    }
}

