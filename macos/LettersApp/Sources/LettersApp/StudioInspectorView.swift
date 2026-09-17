import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct StudioInspectorView: View {
    @Binding var sources: [String: Source]
    @Binding var activeCitationStyle: CitationStyle
    @Binding var lintIssues: [StyleLintMatch]
    @Binding var lineSpacing: CGFloat
    @Binding var paragraphSpacing: CGFloat
    let currentDocumentContext: () -> String
    var onRunLinter: () -> Void

    @State private var isTypographyExpanded = true
    @State private var isSourcesExpanded = true
    @State private var isLinterExpanded = true
    @State private var isCopilotExpanded = true

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Section 1: Typography & Paragraph Spacing (Affinity / InDesign Style)
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

                        HStack {
                            Text("Drop Caps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Toggle("", isOn: .constant(false))
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                        }
                    }
                    .padding(8)
                    .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 6))
                }
                .font(.caption.bold())

                Divider()

                // Section 2: Linked Citations (CSL Profiles)
                DisclosureGroup("Linked Citations & Styles", isExpanded: $isSourcesExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Style", selection: $activeCitationStyle) {
                            ForEach(CitationStyle.allCases, id: \.self) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                        .labelsHidden()

                        if sources.isEmpty {
                            Text("No sources linked in document.")
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

                // Section 3: Style Rules & Lint Warnings
                DisclosureGroup("Style Rules & Linting (\(lintIssues.count))", isExpanded: $isLinterExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Active Profile: Academic")
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

                // Section 4: AI Copilot Assistant Companion
                DisclosureGroup("AI Copilot Assistant", isExpanded: $isCopilotExpanded) {
                    AssistantSidebarView(currentDocumentContext: currentDocumentContext)
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
    }
}
