import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Unified right inspector
//
// One docked pane with three tabs, switched from the toolbar:
//   Document  – page geometry, canvas guides, typography rhythm, header & footer, reading health
//   Review    – comments, tracked changes and version history (InspectorReviewTab)
//   Assistant – AI writing help and citations & sources (InspectorAssistantTab)
//
// This file holds the shell and the Document tab; the other two tabs live next door.

/// Chrome shared by all three tabs: header with the active tab's name and a close button, then the tab body.
struct StudioContextualInspectorView<DocumentTab: View, ReviewTab: View, AssistantTab: View>: View {
    static var width: CGFloat { 320 }

    let tab: InspectorTab
    let onClose: () -> Void
    @ViewBuilder let documentTab: () -> DocumentTab
    @ViewBuilder let reviewTab: () -> ReviewTab
    @ViewBuilder let assistantTab: () -> AssistantTab

    private var subtitle: String {
        switch tab {
        case .document: return "Page, type and layout"
        case .review: return "Comments, changes and history"
        case .assistant: return "Writing help and sources"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)

            Group {
                switch tab {
                case .document: documentTab()
                case .review: reviewTab()
                case .assistant: assistantTab()
                }
            }
            .id(tab)
            .transition(.opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(VisualEffectBackground(material: .sidebar))
        .animation(.easeOut(duration: 0.16), value: tab)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(tab.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 4)

            Button(action: onClose) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(StudioHoverButtonStyle(cornerRadius: 6))
            .help("Hide the inspector")
            .accessibilityLabel("Hide the inspector")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Fonts

/// The families the document can be set in, with short display names.
enum StudioFontCatalog {
    static let families = [
        "New York", "SF Pro", "Georgia", "Helvetica Neue", "Times New Roman",
        "Menlo", "Courier New", "Avenir Next", "Baskerville", "Palatino", "Charter"
    ]

    static func displayName(_ raw: String) -> String {
        if raw.contains("Georgia") { return "Georgia" }
        if raw.contains("New York") { return "New York" }
        if raw.contains("Times") { return "Times New Roman" }
        if raw.contains("Menlo") || raw.contains("Mono") { return "Menlo" }
        if raw.contains("SF Pro") || raw.contains("Sans") || raw == "System" { return "SF Pro" }
        if let paren = raw.firstIndex(of: "(") {
            let prefix = raw[..<paren].trimmingCharacters(in: .whitespaces)
            if !prefix.isEmpty { return prefix }
        }
        return raw
    }

    static func isSelected(_ family: String, current: String) -> Bool {
        displayName(current) == displayName(family)
    }

    /// Curated heading + body looks. The document has one family that drives both, so a pairing sets that family.
    struct Pairing: Identifiable {
        let name: String
        let family: String
        let design: Font.Design
        var id: String { name }
    }

    static let pairings: [Pairing] = [
        Pairing(name: "Editorial", family: "New York", design: .serif),
        Pairing(name: "Modern", family: "SF Pro", design: .default),
        Pairing(name: "Classic", family: "Georgia", design: .serif),
        Pairing(name: "Academic", family: "Times New Roman", design: .serif)
    ]
}

// MARK: - Document tab

struct InspectorDocumentTab: View {
    @ObservedObject var document: LettersDocumentController
    @Binding var showMarginGuides: Bool
    @Binding var showRuler: Bool
    var isEditingHeaderFooter: Bool
    var activeHeaderFooterTarget: HeaderFooterTarget
    var onEditHeaderFooter: (HeaderFooterTarget) -> Void

    @State private var analytics = DocumentAnalytics()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pageSection
                guidesSection
                typographySection
                headerFooterSection
                analyticsSection
            }
            .padding(14)
        }
        .task(id: document.rawText) {
            // Quiet-period debounce; restarted on every keystroke, computed off the main thread.
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let text = document.rawText
            let next = await Task.detached(priority: .utility) { DocumentAnalytics.compute(text) }.value
            guard !Task.isCancelled else { return }
            if next != analytics { analytics = next }
        }
    }

    // MARK: Page geometry

    private var pageSection: some View {
        StudioFormSection(title: "Page", icon: "doc") {
            StudioFormRow(label: "Paper size", detail: document.pageSize.subtitle) {
                StudioMenuValue(value: document.pageSize.rawValue) {
                    Picker("Paper size", selection: $document.pageSize) {
                        ForEach(PageSizePreset.allCases, id: \.self) { size in
                            Text("\(size.rawValue) · \(size.subtitle)").tag(size)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            StudioRowDivider()
            StudioFormRow(label: "Orientation") {
                StudioSegmentedControl(
                    segments: [
                        StudioSegment(tag: false, title: "Portrait", icon: "rectangle.portrait", help: "Portrait"),
                        StudioSegment(tag: true, title: "Landscape", icon: "rectangle", help: "Landscape")
                    ],
                    selected: document.isLandscape,
                    height: 26,
                    showsIcons: false,
                    onSelect: { document.isLandscape = $0 }
                )
                .frame(width: 164)
            }
            StudioRowDivider()
            StudioFormRow(label: "Columns") {
                StudioSegmentedControl(
                    segments: [1, 2, 3].map { StudioSegment(tag: $0, title: "\($0)", help: $0 == 1 ? "One column" : "\($0) columns") },
                    selected: document.columnCount,
                    height: 26,
                    showsIcons: false,
                    onSelect: { document.columnCount = $0 }
                )
                .frame(width: 112)
            }
            StudioRowDivider()
            StudioFormRow(label: "Margins", detail: marginSummary) {
                StudioMenuValue(value: marginMenuTitle) {
                    Picker("Margins", selection: $document.marginPreset) {
                        ForEach(MarginPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            if document.marginPreset == .custom {
                StudioRowDivider()
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        marginStepper(label: "Top", value: $document.margins.top)
                        marginStepper(label: "Bottom", value: $document.margins.bottom)
                    }
                    GridRow {
                        marginStepper(label: "Left", value: $document.margins.left)
                        marginStepper(label: "Right", value: $document.margins.right)
                    }
                }
                .padding(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: document.marginPreset)
    }

    private var marginMenuTitle: String {
        // "Normal (1.0")" -> "Normal"
        document.marginPreset.rawValue.components(separatedBy: " (").first ?? document.marginPreset.rawValue
    }

    private var marginSummary: String {
        let m = document.margins
        func inches(_ v: CGFloat) -> String { String(format: "%.2g", v / 72.0) }
        if m.top == m.bottom && m.left == m.right && m.top == m.left {
            return "\(inches(m.top))\" on all sides"
        }
        return "\(inches(m.top))\" × \(inches(m.left))\""
    }

    private func marginStepper(label: String, value: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 2) {
                stepButton("minus", help: "Decrease \(label.lowercased()) margin") {
                    document.marginPreset = .custom
                    value.wrappedValue = max(18, value.wrappedValue - 9)
                }
                Text(String(format: "%.2f\"", value.wrappedValue / 72.0))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .frame(width: 44)
                stepButton("plus", help: "Increase \(label.lowercased()) margin") {
                    document.marginPreset = .custom
                    value.wrappedValue = min(216, value.wrappedValue + 9)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(StudioHoverButtonStyle(cornerRadius: 5))
        .help(help)
    }

    // MARK: Canvas guides

    private var guidesSection: some View {
        StudioFormSection(title: "Canvas guides", icon: "ruler") {
            toggleRow("Margin guides", isOn: $showMarginGuides)
            StudioRowDivider()
            toggleRow("Ruler", isOn: $showRuler)
            StudioRowDivider()
            toggleRow("Line numbers", isOn: $document.showLineNumbers)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        StudioFormRow(label: title) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    // MARK: Typography rhythm

    private var typographySection: some View {
        StudioFormSection(title: "Typography", icon: "textformat") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Heading & body pairing")
                    .font(.system(size: 12))
                HStack(spacing: 6) {
                    ForEach(StudioFontCatalog.pairings) { pairing in
                        pairingChip(pairing)
                    }
                }
            }
            .padding(10)

            StudioRowDivider()
            StudioFormRow(label: "Body font") {
                StudioMenuValue(value: StudioFontCatalog.displayName(document.fontFamily)) {
                    ForEach(StudioFontCatalog.families, id: \.self) { family in
                        Button {
                            document.fontFamily = family
                        } label: {
                            if StudioFontCatalog.isSelected(family, current: document.fontFamily) {
                                Label(family, systemImage: "checkmark")
                            } else {
                                Text(family)
                            }
                        }
                    }
                }
            }
            StudioRowDivider()
            StudioFormRow(label: "Size") {
                HStack(spacing: 2) {
                    stepButton("minus", help: "Smaller") { document.fontSize = max(8, document.fontSize - 1) }
                    Text("\(Int(document.fontSize)) pt")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .frame(width: 46)
                    stepButton("plus", help: "Larger") { document.fontSize = min(72, document.fontSize + 1) }
                }
            }
            StudioRowDivider()
            StudioFormRow(label: "Line spacing") {
                StudioSegmentedControl(
                    segments: [1.0, 1.15, 1.5, 2.0].map {
                        StudioSegment(tag: $0, title: lineSpacingTitle($0), help: "\(lineSpacingTitle($0))× line spacing")
                    },
                    selected: [1.0, 1.15, 1.5, 2.0].first { abs(Double(document.lineSpacing) - $0) < 0.02 },
                    height: 26,
                    showsIcons: false,
                    onSelect: { document.lineSpacing = CGFloat($0) }
                )
                .frame(width: 150)
            }
            StudioRowDivider()
            StudioFormRow(label: "Paragraph spacing") {
                StudioSegmentedControl(
                    segments: [0, 6, 12, 18].map {
                        StudioSegment(tag: $0, title: "\($0)", help: "\($0) pt after each paragraph")
                    },
                    selected: [0, 6, 12, 18].first { abs(Int(document.paragraphSpacing) - $0) <= 1 },
                    height: 26,
                    showsIcons: false,
                    onSelect: { document.paragraphSpacing = CGFloat($0) }
                )
                .frame(width: 132)
            }
            StudioRowDivider()
            StudioFormRow(label: "Paragraphs") {
                StudioSegmentedControl(
                    segments: [
                        StudioSegment(tag: false, title: "Spaced", help: "No indent, space between paragraphs"),
                        StudioSegment(tag: true, title: "Indented", help: "First line indented, no space between")
                    ],
                    selected: document.hangingIndent > 0,
                    height: 26,
                    showsIcons: false,
                    onSelect: { indented in
                        document.hangingIndent = indented ? 24 : 0
                        document.paragraphSpacing = indented ? 0 : 8
                    }
                )
                .frame(width: 160)
            }
        }
    }

    private func lineSpacingTitle(_ value: Double) -> String {
        value == 1.0 || value == 2.0 ? String(format: "%.1f", value) : String(format: "%.2f", value)
    }

    private func pairingChip(_ pairing: StudioFontCatalog.Pairing) -> some View {
        let isSelected = StudioFontCatalog.isSelected(pairing.family, current: document.fontFamily)
        return Button {
            document.fontFamily = pairing.family
        } label: {
            VStack(spacing: 2) {
                Text("Aa")
                    .font(.system(size: 17, weight: .semibold, design: pairing.design))
                Text(pairing.name)
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .accentColor : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(pairing.name): \(pairing.family)")
        .accessibilityLabel("\(pairing.name) pairing")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Header & footer

    private var headerFooterSection: some View {
        StudioFormSection(title: "Header & footer", icon: "rectangle.split.1x2") {
            StudioFormRow(label: "Header") {
                HStack(spacing: 8) {
                    editButton(.header)
                    Toggle("", isOn: $document.headerFooter.isHeaderVisible)
                        .toggleStyle(.switch).controlSize(.small).labelsHidden()
                }
            }
            StudioRowDivider()
            StudioFormRow(label: "Footer") {
                HStack(spacing: 8) {
                    editButton(.footer)
                    Toggle("", isOn: $document.headerFooter.isFooterVisible)
                        .toggleStyle(.switch).controlSize(.small).labelsHidden()
                }
            }
            StudioRowDivider()
            StudioFormRow(label: "Page numbers") {
                StudioMenuValue(value: pageNumberTitle) {
                    Picker("Page numbers", selection: $document.headerFooter.pageNumberPosition) {
                        ForEach(PageNumberPosition.allCases, id: \.self) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            StudioRowDivider()
            toggleRow("Different first page", isOn: $document.headerFooter.differentFirstPage)
        }
    }

    private var pageNumberTitle: String {
        document.headerFooter.pageNumberPosition.rawValue.components(separatedBy: " (").first
            ?? document.headerFooter.pageNumberPosition.rawValue
    }

    private func editButton(_ target: HeaderFooterTarget) -> some View {
        let editing = isEditingHeaderFooter && activeHeaderFooterTarget == target
        return Button {
            onEditHeaderFooter(target)
        } label: {
            Text(editing ? "Editing" : "Edit")
        }
        .buttonStyle(StudioPillButtonStyle(prominent: editing))
        .help("Edit the \(target.rawValue.lowercased()) on the page")
    }

    // MARK: Reading & health

    private var analyticsSection: some View {
        StudioFormSection(title: "Reading & health", icon: "waveform.path.ecg") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 12) {
                GridRow {
                    stat("Words", analytics.words.formatted())
                    stat("Characters", analytics.characters.formatted())
                }
                GridRow {
                    stat("Reading time", analytics.readingTimeLabel)
                    stat("Reading level", analytics.gradeLabel, caption: analytics.gradeDescription)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stat(_ label: String, _ value: String, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
            if let caption {
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.2), value: value)
    }
}
