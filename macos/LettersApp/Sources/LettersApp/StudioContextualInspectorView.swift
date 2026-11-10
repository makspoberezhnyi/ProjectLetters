import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public enum InspectorTab: String, CaseIterable {
    case text = "Text"
    case page = "Page"
    case citations = "Citations"

    public var icon: String {
        switch self {
        case .text: return "textformat"
        case .page: return "doc.plaintext"
        case .citations: return "book.closed"
        }
    }
}

public struct StudioContextualInspectorView: View {
    @Binding var isPresented: Bool

    // Document Properties
    @Binding var fontFamily: String
    @Binding var fontSize: CGFloat
    @Binding var lineSpacing: CGFloat
    @Binding var paragraphSpacing: CGFloat
    @Binding var hangingIndent: CGFloat
    @Binding var textAlignment: TextAlignment
    @Binding var pageSize: PageSizePreset
    @Binding var marginPreset: MarginPreset
    @Binding var margins: PageMargins
    @Binding var columnCount: Int
    @Binding var showLineNumbers: Bool
    @Binding var showMarginGuides: Bool
    @Binding var citationStyle: CitationStyle
    @Binding var sources: [String: Source]

    // Selection Attributes
    var selectionAttributes: EditorSelectionAttributes? = nil

    // Actions
    var onToggleBold: (() -> Void)? = nil
    var onToggleItalic: (() -> Void)? = nil
    var onToggleUnderline: (() -> Void)? = nil
    var onToggleStrikethrough: (() -> Void)? = nil
    var onApplyParagraphStyle: ((DocumentParagraphStyle) -> Void)? = nil
    var onAddSource: (() -> Void)? = nil
    var onInsertBibliography: (() -> Void)? = nil
    var onToast: ((String) -> Void)? = nil

    @State private var activeTab: InspectorTab = .text

    public init(
        isPresented: Binding<Bool>,
        fontFamily: Binding<String>,
        fontSize: Binding<CGFloat>,
        lineSpacing: Binding<CGFloat>,
        paragraphSpacing: Binding<CGFloat>,
        hangingIndent: Binding<CGFloat>,
        textAlignment: Binding<TextAlignment>,
        pageSize: Binding<PageSizePreset>,
        marginPreset: Binding<MarginPreset>,
        margins: Binding<PageMargins>,
        columnCount: Binding<Int>,
        showLineNumbers: Binding<Bool>,
        showMarginGuides: Binding<Bool>,
        citationStyle: Binding<CitationStyle>,
        sources: Binding<[String: Source]>,
        selectionAttributes: EditorSelectionAttributes? = nil,
        onToggleBold: (() -> Void)? = nil,
        onToggleItalic: (() -> Void)? = nil,
        onToggleUnderline: (() -> Void)? = nil,
        onToggleStrikethrough: (() -> Void)? = nil,
        onApplyParagraphStyle: ((DocumentParagraphStyle) -> Void)? = nil,
        onAddSource: (() -> Void)? = nil,
        onInsertBibliography: (() -> Void)? = nil,
        onToast: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._fontFamily = fontFamily
        self._fontSize = fontSize
        self._lineSpacing = lineSpacing
        self._paragraphSpacing = paragraphSpacing
        self._hangingIndent = hangingIndent
        self._textAlignment = textAlignment
        self._pageSize = pageSize
        self._marginPreset = marginPreset
        self._margins = margins
        self._columnCount = columnCount
        self._showLineNumbers = showLineNumbers
        self._showMarginGuides = showMarginGuides
        self._citationStyle = citationStyle
        self._sources = sources
        self.selectionAttributes = selectionAttributes
        self.onToggleBold = onToggleBold
        self.onToggleItalic = onToggleItalic
        self.onToggleUnderline = onToggleUnderline
        self.onToggleStrikethrough = onToggleStrikethrough
        self.onApplyParagraphStyle = onApplyParagraphStyle
        self.onAddSource = onAddSource
        self.onInsertBibliography = onInsertBibliography
        self.onToast = onToast
    }

    private var currentFontSize: CGFloat {
        selectionAttributes?.fontSize ?? fontSize
    }

    private var opticalSizeBadge: String {
        let size = currentFontSize
        if size <= 10.5 { return "Small" }
        if size <= 14.5 { return "Medium" }
        if size <= 24.5 { return "Large" }
        return "Expanded"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Inspector Header
            HStack(spacing: 8) {
                Text("Inspector")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Close the inspector")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Segmented Tab Picker
            Picker("", selection: $activeTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch activeTab {
                    case .text:
                        textTabContent
                    case .page:
                        pageTabContent
                    case .citations:
                        citationsTabContent
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Tab 1: Text & Style
    private var textTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Section: Typography
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Typography")

                // Font Family Quick Selector
                HStack(spacing: 6) {
                    Button(action: { fontFamily = "New York" }) {
                        Text("New York")
                            .font(.system(size: 11, weight: fontFamily.contains("New York") ? .semibold : .regular, design: .serif))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                fontFamily.contains("New York")
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .foregroundColor(fontFamily.contains("New York") ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { fontFamily = "SF Pro" }) {
                        Text("SF Pro")
                            .font(.system(size: 11, weight: fontFamily.contains("SF Pro") || fontFamily == "System" ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                (fontFamily.contains("SF Pro") || fontFamily == "System")
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .foregroundColor((fontFamily.contains("SF Pro") || fontFamily == "System") ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }

                // System Font Picker Dropdown
                Menu {
                    ForEach(["New York", "SF Pro", "Georgia", "Helvetica Neue", "Times New Roman", "Menlo", "Courier New", "Avenir Next", "Baskerville", "Palatino", "Charter"], id: \.self) { fam in
                        Button(fam) {
                            fontFamily = fam
                        }
                    }
                } label: {
                    HStack {
                        Text(fontFamily)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                // Font Size Stepper & Optical Size Badge
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Button(action: { fontSize = max(8, currentFontSize - 1) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 26)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(currentFontSize)) pt")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(width: 48, alignment: .center)

                        Button(action: { fontSize = min(72, currentFontSize + 1) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 26)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Optical Size Indicator Badge
                    Text(opticalSizeBadge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }

                // Formatting Toggle Buttons (B, I, U, S)
                HStack(spacing: 6) {
                    formatToggleButton(title: "bold", isActive: selectionAttributes?.isBold ?? false) {
                        onToggleBold?()
                    }
                    formatToggleButton(title: "italic", isActive: selectionAttributes?.isItalic ?? false) {
                        onToggleItalic?()
                    }
                    formatToggleButton(title: "underline", isActive: selectionAttributes?.isUnderline ?? false) {
                        onToggleUnderline?()
                    }
                    formatToggleButton(title: "strikethrough", isActive: false) {
                        onToggleStrikethrough?()
                    }
                }

                // Paragraph Preset Menu
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paragraph Style")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)

                    Menu {
                        ForEach(DocumentParagraphStyle.allCases) { preset in
                            Button {
                                onApplyParagraphStyle?(preset)
                            } label: {
                                if (selectionAttributes?.paragraphStylePreset ?? .body) == preset {
                                    Label("\(preset.rawValue) (\(Int(preset.fontSize)) pt)", systemImage: "checkmark")
                                } else {
                                    Text("\(preset.rawValue) (\(Int(preset.fontSize)) pt)")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text((selectionAttributes?.paragraphStylePreset ?? .body).rawValue)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Section: Spacing & Rhythm
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Spacing")

                // Line Height Multiplier
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Line Spacing")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        let ratio = 1.0 + (lineSpacing / max(12, currentFontSize))
                        Text(String(format: "%.2f× · %.1f pt", ratio, currentFontSize * ratio))
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }

                    HStack(spacing: 4) {
                        ForEach([1.15, 1.20, 1.25, 1.50, 2.00], id: \.self) { mult in
                            Button(action: {
                                let targetLeading = currentFontSize * CGFloat(mult - 1.0)
                                lineSpacing = max(2, targetLeading)
                            }) {
                                Text(String(format: "%.2f×", mult))
                                    .font(.system(size: 10, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Paragraph Indent Modes (Block vs Academic)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paragraph Layout")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Button(action: {
                            hangingIndent = 0
                            paragraphSpacing = 8
                        }) {
                            VStack(spacing: 2) {
                                Text("Spaced")
                                    .font(.system(size: 11, weight: hangingIndent == 0 ? .semibold : .regular))
                                Text("No indent, space between")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                hangingIndent == 0
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .foregroundColor(hangingIndent == 0 ? .accentColor : .primary)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            hangingIndent = 24 // 0.33 in
                            paragraphSpacing = 0
                        }) {
                            VStack(spacing: 2) {
                                Text("Indented")
                                    .font(.system(size: 11, weight: hangingIndent > 0 ? .semibold : .regular))
                                Text("First line indented")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                hangingIndent > 0
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.primary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .foregroundColor(hangingIndent > 0 ? .accentColor : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Alignment
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alignment")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        alignmentButton(icon: "text.alignleft", align: .leading)
                        alignmentButton(icon: "text.aligncenter", align: .center)
                        alignmentButton(icon: "text.alignright", align: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Tab 2: Page Setup & Layout
    private var pageTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Paper Dimensions
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Paper")

                Picker("Page Size", selection: $pageSize) {
                    ForEach(PageSizePreset.allCases, id: \.self) { size in
                        Text("\(size.rawValue) (\(size.subtitle))").tag(size)
                    }
                }
                .pickerStyle(.menu)

                // Column Count
                Picker("Columns", selection: $columnCount) {
                    Text("One Column").tag(1)
                    Text("Two Columns").tag(2)
                }
                .pickerStyle(.menu)
            }

            Divider()

            // Margins
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Margins")

                Picker("Margins", selection: $marginPreset) {
                    ForEach(MarginPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: marginPreset) { _, newPreset in
                    if newPreset != .custom {
                        margins = newPreset.margins
                    }
                }

                // 4-Axis Margin Steppers
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        marginStepperRow(label: "Top", value: $margins.top)
                        marginStepperRow(label: "Bottom", value: $margins.bottom)
                    }
                    GridRow {
                        marginStepperRow(label: "Left", value: $margins.left)
                        marginStepperRow(label: "Right", value: $margins.right)
                    }
                }
            }

            Divider()

            // Canvas & Layout Guides
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Page Guides")

                Toggle("Show margin guides", isOn: $showMarginGuides)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))

                Toggle("Show line numbers", isOn: $showLineNumbers)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))
            }
        }
    }

    // MARK: - Tab 3: Citations & Research
    private var citationsTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Citation Style
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Citation Style")

                Picker("", selection: $citationStyle) {
                    ForEach(CitationStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            // Linked Sources
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionHeader("Sources (\(sources.count))")
                    Spacer()
                    Button(action: { onAddSource?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add Source")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                if sources.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("No sources yet")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text("Add a source to cite it in APA, MLA, Chicago, and more.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(sources.values), id: \.id) { source in
                            sourceRow(source: source)
                        }
                    }
                }

                // Insert / Refresh Bibliography Action
                Button(action: {
                    onInsertBibliography?()
                    onToast?("Bibliography added at the end of the document")
                }) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Insert Bibliography")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }

    private func sourceRow(source: Source) -> some View {
        let isComplete = !source.authors.isEmpty && !source.title.isEmpty && source.year != nil
        let authorsText = source.authors.isEmpty ? "No author" : source.authors.joined(separator: ", ")
        let yearText = source.year != nil ? "\(source.year!)" : "No date"

        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isComplete ? .green : .orange)
                .font(.system(size: 11))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.title.isEmpty ? "Untitled source" : source.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("\(authorsText) · \(yearText)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("[\(source.id)]")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func formatToggleButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: title)
                .font(.system(size: 12, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    isActive ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .foregroundColor(isActive ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private func alignmentButton(icon: String, align: TextAlignment) -> some View {
        let isSelected = (textAlignment == align)
        return Button(action: { textAlignment = align }) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private func marginStepperRow(label: String, value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 2) {
                Button(action: {
                    marginPreset = .custom
                    value.wrappedValue = max(18, value.wrappedValue - 9) // 1/8 inch
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 20)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Text(String(format: "%.2f\"", value.wrappedValue / 72.0))
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .frame(width: 38, alignment: .center)

                Button(action: {
                    marginPreset = .custom
                    value.wrappedValue = min(216, value.wrappedValue + 9) // 1/8 inch
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 20)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
