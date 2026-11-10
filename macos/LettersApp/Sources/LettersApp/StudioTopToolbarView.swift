import SwiftUI
import AppKit
import Combine
#if canImport(LettersKit)
import LettersKit
#endif

/// Every command the toolbar can issue. The toolbar owns no editing logic; `MainEditorView` wires these up.
struct StudioToolbarActions {
    var paragraphStyle: (DocumentParagraphStyle) -> Void
    var fontFamily: (String) -> Void
    var fontSize: (CGFloat) -> Void
    var bold: () -> Void
    var italic: () -> Void
    var underline: () -> Void
    var textColor: (NSColor) -> Void
    var highlight: (NSColor?) -> Void
    var clearFormatting: () -> Void
    var cleanContrast: () -> Void
    var alignment: (TextAlignment) -> Void
    var bullet: () -> Void
    var numbered: () -> Void
    var lineSpacing: (CGFloat) -> Void
    var paragraphSpacing: (CGFloat) -> Void
    var toast: (String) -> Void
    var openCommandPalette: () -> Void
}

/// The fields of the document the toolbar renders. Typing in the body text changes none of these,
/// so the toolbar is not re-evaluated while the user types.
struct StudioToolbarSlice: Equatable {
    var fontFamily: String
    var fontSize: CGFloat
    var textAlignment: TextAlignment
    var lineSpacing: CGFloat
    var paragraphSpacing: CGFloat
    var isTrackChangesEnabled: Bool
    var revisionCount: Int
    var noteCount: Int
    var openNoteCount: Int

    @MainActor
    init(_ doc: LettersDocumentController) {
        fontFamily = doc.fontFamily
        fontSize = doc.fontSize
        textAlignment = doc.textAlignment
        lineSpacing = doc.lineSpacing
        paragraphSpacing = doc.paragraphSpacing
        isTrackChangesEnabled = doc.isTrackChangesEnabled
        revisionCount = doc.revisions.count
        noteCount = doc.sideNotes.count
        openNoteCount = doc.sideNotes.reduce(0) { $0 + ($1.isResolved ? 0 : 1) }
    }
}

/// Document title field and autosave indicator. Observes the controller directly because the
/// text field needs a synchronous two-way binding; the view is a handful of nodes.
struct DocumentTitleBadge: View {
    @ObservedObject var documentController: LettersDocumentController

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 15))

            TextField("Document Title", text: $documentController.title)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(minWidth: 70, idealWidth: 135, maxWidth: 185)

            if documentController.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .help("Edited — Autosaving in background")
            } else if documentController.lastAutosaveDate != nil || documentController.currentFileURL != nil {
                Image(systemName: "checkmark.icloud.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green.opacity(0.85))
                    .help("All changes saved")
            }
        }
    }
}

/// Top glass strip: outline toggle, title, Word-style formatting controls and the quick-action cluster.
struct StudioTopToolbarView: View {
    /// Used only to mutate (track changes) and to build the title badge; not observed.
    let documentController: LettersDocumentController
    @ObservedObject var format: EditorFormatStore
    @Binding var showOutlineDrawer: Bool
    @Binding var rightPane: EditorRightPane
    let actions: StudioToolbarActions

    @StateObject private var slice: DocumentSlice<StudioToolbarSlice>
    @State private var showTextColorPopover = false
    @State private var showHighlightColorPopover = false

    init(
        documentController: LettersDocumentController,
        format: EditorFormatStore,
        showOutlineDrawer: Binding<Bool>,
        rightPane: Binding<EditorRightPane>,
        actions: StudioToolbarActions
    ) {
        self.documentController = documentController
        self.format = format
        self._showOutlineDrawer = showOutlineDrawer
        self._rightPane = rightPane
        self.actions = actions
        self._slice = StateObject(wrappedValue: DocumentSlice(documentController) { StudioToolbarSlice($0) })
    }

    private var s: StudioToolbarSlice { slice.value }
    private var showDocumentHistory: Bool { rightPane == .history }
    private var showComments: Bool { rightPane == .comments }
    private var showPageDesignInspector: Bool { rightPane == .inspector }
    private var showAIDrawer: Bool { rightPane == .assistant }

    private func shortFontDisplayName(_ rawName: String) -> String {
        if rawName.contains("Georgia") { return "Georgia" }
        if rawName.contains("New York") { return "New York" }
        if rawName.contains("Times") { return "Times New Roman" }
        if rawName.contains("Menlo") { return "Menlo" }
        if rawName.contains("SF Pro") || rawName.contains("Sans") { return "SF Pro" }
        if let parenIndex = rawName.firstIndex(of: "(") {
            let prefix = rawName[..<parenIndex].trimmingCharacters(in: .whitespaces)
            if !prefix.isEmpty && prefix != "Default Serif" {
                return prefix
            }
        }
        return rawName
    }

    var body: some View {
        HStack(spacing: 10) {
            // Left Navigator Sidebar Toggle Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showOutlineDrawer.toggle()
                }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(showOutlineDrawer ? .accentColor : .primary.opacity(0.75))
                    .frame(width: 30, height: 30)
                    .background(showOutlineDrawer ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(7)
                    .symbolEffect(.bounce, value: showOutlineDrawer)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Toggle Outline Navigator (⌥⌘1)")

            // Document Title & Live Autosave Status Badge
            DocumentTitleBadge(documentController: documentController)
                .layoutPriority(-1)
            
            Divider().frame(height: 18)

            // Word-Style Font Formatting Controls
            HStack(spacing: 5) {
                // Paragraph Style Preset Picker (Title, Heading 1-3, Body, Blockquote, Caption)
                Menu {
                    ForEach(DocumentParagraphStyle.allCases) { preset in
                        Button {
                            actions.paragraphStyle(preset)
                        } label: {
                            if (format.attributes?.paragraphStylePreset ?? .body) == preset {
                                Label("\(preset.rawValue) (\(Int(preset.fontSize)) pt)", systemImage: "checkmark")
                            } else {
                                Text("\(preset.rawValue) (\(Int(preset.fontSize)) pt)")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text((format.attributes?.paragraphStylePreset ?? .body).rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .frame(minWidth: 54, maxWidth: 82, alignment: .leading)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(Color.accentColor.opacity(0.10))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .help("Paragraph Style (Title, Heading 1–3, Body, Blockquote, Caption)")

                // Font Family
                Menu {
                    ForEach(["System", "Georgia", "Helvetica Neue", "Times New Roman", "Menlo", "Courier New", "Avenir Next", "Baskerville", "Palatino", "Charter"], id: \.self) { fam in
                        Button(fam) { actions.fontFamily(fam) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(shortFontDisplayName(format.attributes?.fontFamily ?? s.fontFamily))
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(minWidth: 64, maxWidth: 105, alignment: .leading)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                
                // Font Size
                HStack(spacing: 2) {
                    Button(action: { actions.fontSize((format.attributes?.fontSize ?? s.fontSize) - 1) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 30)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(5)
                    }
                    
                    Text("\(Int(format.attributes?.fontSize ?? s.fontSize))")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .frame(width: 24, alignment: .center)
                        
                    Button(action: { actions.fontSize((format.attributes?.fontSize ?? s.fontSize) + 1) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 30)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(5)
                    }
                }
                .buttonStyle(.plain)
                .fixedSize()
                
                Divider().frame(height: 16)
                
                // Bold, Italic, Underline
                HStack(spacing: 4) {
                    Button(action: { actions.bold() }) {
                        Image(systemName: "bold")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor((format.attributes?.isBold ?? format.isBold) ? .accentColor : .primary)
                            .frame(width: 30, height: 30)
                            .background((format.attributes?.isBold ?? format.isBold) ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Bold (⌘B)")

                    Button(action: { actions.italic() }) {
                        Image(systemName: "italic")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor((format.attributes?.isItalic ?? format.isItalic) ? .accentColor : .primary)
                            .frame(width: 30, height: 30)
                            .background((format.attributes?.isItalic ?? format.isItalic) ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Italic (⌘I)")

                    Button(action: { actions.underline() }) {
                        Image(systemName: "underline")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor((format.attributes?.isUnderline ?? format.isUnderline) ? .accentColor : .primary)
                            .frame(width: 30, height: 30)
                            .background((format.attributes?.isUnderline ?? format.isUnderline) ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Underline (⌘U)")

                    // Text Color Palette (Word Style Theme Grid + Native ColorPicker)
                    Button(action: { showTextColorPopover.toggle() }) {
                        VStack(spacing: 2) {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(format.textColor)
                                .frame(width: 14, height: 3)
                                .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                        }
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Text Color & Palette (Word-Style)")
                    .popover(isPresented: $showTextColorPopover, arrowEdge: .bottom) {
                        WordStyleColorPaletteView(
                            title: "Text Color",
                            selectedColor: $format.textColor,
                            isHighlight: false,
                            allowNoColor: true,
                            clearTitle: "Default Color",
                            onSelectColor: { newColor in
                                format.textColor = newColor
                                actions.textColor(NSColor(newColor))
                            },
                            onClearColor: {
                                let defaultColor = Color(red: 0.10, green: 0.10, blue: 0.12)
                                format.textColor = defaultColor
                                actions.textColor(NSColor(defaultColor))
                                showTextColorPopover = false
                            },
                            onDismiss: {
                                showTextColorPopover = false
                            }
                        )
                    }

                    // Text Highlight (Word Style Theme Grid + Native ColorPicker)
                    Button(action: { showHighlightColorPopover.toggle() }) {
                        VStack(spacing: 2) {
                            Image(systemName: "highlighter")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(format.highlightColor)
                                .frame(width: 14, height: 3)
                                .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                        }
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Text Highlight & Palette (Word-Style)")
                    .popover(isPresented: $showHighlightColorPopover, arrowEdge: .bottom) {
                        WordStyleColorPaletteView(
                            title: "Highlight Color",
                            selectedColor: $format.highlightColor,
                            isHighlight: true,
                            allowNoColor: true,
                            clearTitle: "No Highlight",
                            onSelectColor: { newColor in
                                format.highlightColor = newColor
                                actions.highlight(NSColor(newColor).withAlphaComponent(0.42))
                            },
                            onClearColor: {
                                actions.highlight(nil)
                                showHighlightColorPopover = false
                            },
                            onDismiss: {
                                showHighlightColorPopover = false
                            }
                        )
                    }

                    // Clear Formatting
                    Button(action: { actions.clearFormatting() }) {
                        Image(systemName: "eraser")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Formatting (Reset text to default black)")

                    // Clean Contrast / Adapt Text
                    Button(action: {
                        actions.cleanContrast()
                        actions.toast("✓ Cleaned text contrast (dark mode sanitized)")
                    }) {
                        Image(systemName: "sun.max")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Clean Contrast (Convert white/invisible text to dark charcoal)")
                }
                .fixedSize()
                
                Divider().frame(height: 16)
                
                // Alignment
                Menu {
                    Button("Left") { actions.alignment(.leading) }
                    Button("Center") { actions.alignment(.center) }
                    Button("Right") { actions.alignment(.trailing) }
                } label: {
                    let align = format.attributes?.alignment ?? s.textAlignment
                    let alignIcon = align == .leading ? "text.alignleft" : (align == .center ? "text.aligncenter" : "text.alignright")
                    Image(systemName: alignIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("Text Alignment")

                // Smart Bulleted & Numbered Lists
                HStack(spacing: 3) {
                    Button(action: { actions.bullet() }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Bulleted List (⇧⌘8)")

                    Button(action: { actions.numbered() }) {
                        Image(systemName: "list.number")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Numbered List (⇧⌘7)")
                }
                .fixedSize()

                // Line & Paragraph Spacing
                Menu {
                    ForEach([
                        (1.0, "1.0 (Single)"),
                        (1.15, "1.15 (Standard)"),
                        (1.25, "1.25 (Relaxed)"),
                        (1.5, "1.5 (1.5x)"),
                        (2.0, "2.0 (Double)")
                    ], id: \.0) { val, label in
                        Button {
                            actions.lineSpacing(CGFloat(val))
                        } label: {
                            if abs(s.lineSpacing - CGFloat(val)) < 0.02 {
                                Label(label, systemImage: "checkmark")
                            } else {
                                Text(label)
                            }
                        }
                    }
                    Divider()
                    ForEach([
                        (12.0, "Add Space After Paragraph (12 pt)"),
                        (6.0, "Compact Space After Paragraph (6 pt)"),
                        (0.0, "Remove Space After Paragraph (0 pt)")
                    ], id: \.0) { val, label in
                        Button {
                            actions.paragraphSpacing(CGFloat(val))
                        } label: {
                            if abs(s.paragraphSpacing - CGFloat(val)) < 0.5 {
                                Label(label, systemImage: "checkmark")
                            } else {
                                Text(label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down.text.horizontal")
                            .font(.system(size: 12, weight: .medium))
                        Text("\(String(format: "%.2g", s.lineSpacing)) · \(Int(s.paragraphSpacing))pt")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .help("Line Spacing (\(String(format: "%.2g", s.lineSpacing))) & Paragraph Spacing (\(Int(s.paragraphSpacing)) pt)")
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            // Quick Action Center (AI, Timeline, Command)
            HStack(spacing: 6) {
                // Timeline
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        rightPane = rightPane.toggled(.history)
                    }
                }) {
                    Image(systemName: showDocumentHistory ? "chart.bar.doc.horizontal.fill" : "chart.bar.doc.horizontal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showDocumentHistory ? StudioTheme.luminousCyan : .primary)
                        .frame(width: 30, height: 30)
                        .background(showDocumentHistory ? StudioTheme.luminousCyan.opacity(0.18) : Color.primary.opacity(0.06))
                        .cornerRadius(7)
                        .symbolEffect(.bounce, value: showDocumentHistory)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("Toggle Reading Flow Timeline (⌥⌘T)")
                
                // Comments
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { rightPane = rightPane.toggled(.comments) }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 12, weight: .medium))
                        Text("Comments")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        if s.noteCount > 0 {
                            Text("\(s.openNoteCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.accentColor))
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(showComments ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                    .foregroundColor(showComments ? .accentColor : .primary)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .help("Show Comments")

                // Page Design & 3D Theme Inspector Button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        rightPane = rightPane.toggled(.inspector)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Design")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(showPageDesignInspector ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                    .foregroundColor(showPageDesignInspector ? .accentColor : .primary)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .help("Toggle Page Design & 3D Theme Inspector (⌥⌘D)")

                // Review Mode / Track Changes Toggle
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        documentController.isTrackChangesEnabled.toggle()
                    }
                    actions.toast(documentController.isTrackChangesEnabled ? "✓ Track Changes: ON" : "✓ Track Changes: OFF")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Review")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        if s.revisionCount > 0 {
                            Text("\(s.revisionCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.orange))
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .background(s.isTrackChangesEnabled ? Color.orange.opacity(0.18) : Color.primary.opacity(0.06))
                    .foregroundColor(s.isTrackChangesEnabled ? .orange : .primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(s.isTrackChangesEnabled ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .help("Toggle Track Changes & Review Mode (⌥⌘K)")

                Divider().frame(height: 16)
                
                // AI Copilot Toggle
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        rightPane = rightPane.toggled(.assistant)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Copilot")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(showAIDrawer ? StudioTheme.luminousPurple.opacity(0.2) : Color.primary.opacity(0.06))
                    .foregroundColor(showAIDrawer ? StudioTheme.luminousPurple : .primary)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                
                // Command Center Button
                Button(action: { actions.openCommandPalette() }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .bottom
        )
    }
}
