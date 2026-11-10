import SwiftUI
import AppKit
import Combine
#if canImport(LettersKit)
import LettersKit
#endif


import UniformTypeIdentifiers
import PDFKit




public struct MainEditorView: View {
    @StateObject private var editorController = EditorActionController()
    @StateObject private var documentController = LettersDocumentController()
    @StateObject private var toastManager = ToastManager()

    @State private var selectedPage: Int = 1
    @State private var selectedText: String = ""
    @State private var selectionRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showInspector: Bool = true
    @State private var showCommandPalette: Bool = false
    @State private var lintIssues: [StyleLintMatch] = []
    @State private var zoomScale: Double = 1.0
    @State private var showingAddSourceSheet: Bool = false
    @State private var showingCrossReferenceSheet: Bool = false
    @State private var showFindReplace: Bool = false
    @State private var showInlineAI: Bool = false
    @State private var showingSettingsSheet: Bool = false
    @State private var hoveredCommentId: UUID? = nil
    @State private var showingPasteSpecialSheet: Bool = false
    @State private var selectedPasteMode: PasteSpecialMode = .matchStyle
    @State private var textColorState: Color = Color(red: 0.10, green: 0.10, blue: 0.12)
    @State private var highlightColorState: Color = .yellow
    @State private var showTextColorPopover: Bool = false
    @State private var showHighlightColorPopover: Bool = false
    @State private var recentTextColors: [Color] = []
    @State private var recentHighlightColors: [Color] = []

    // New Source form states
    @State private var newSourceTitle: String = ""
    @State private var newSourceAuthor: String = ""
    @State private var newSourceYear: String = ""
    @State private var newSourceType: SourceType = .journalArticle

    // Page Setup & Margins State
    @State private var showMarginGuides: Bool = true
    @State private var showCropMarks: Bool = true
    @State private var showRuler: Bool = true

    // Header & Footer Configuration State
    @State private var isEditingHeaderFooter: Bool = false
    @State private var activeHeaderFooterTarget: HeaderFooterTarget = .header
    @State private var isBottomBarHovered: Bool = false

    // Rich Interactive Blocks State

    // Live Typography States (Directly updates TextKit 2)
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var isUnderline: Bool = false

    // Live Selection Attributes (Tracks cursor/selection without modifying documentController.document defaults)
    @State private var selectionAttributes: EditorSelectionAttributes? = nil

    @State private var showOutlineDrawer: Bool = true
    /// Word / character counts, refreshed when typing pauses rather than on every keystroke.
    @State private var stats: (words: Int, characters: Int) = (0, 0)
    @State private var showRevisionsPopover: Bool = false

    // The right-hand pane is a single choice, not three independent booleans that have to be kept mutually exclusive by hand.
    enum RightPane { case none, inspector, assistant, history, comments }
    @State private var rightPane: RightPane = .inspector

    func paneBinding(_ pane: RightPane) -> Binding<Bool> {
        Binding(get: { rightPane == pane }, set: { rightPane = $0 ? pane : (rightPane == pane ? .none : rightPane) })
    }
    var showPageDesignInspector: Bool {
        get { rightPane == .inspector }
        nonmutating set { rightPane = newValue ? .inspector : (rightPane == .inspector ? .none : rightPane) }
    }
    var showAIDrawer: Bool {
        get { rightPane == .assistant }
        nonmutating set { rightPane = newValue ? .assistant : (rightPane == .assistant ? .none : rightPane) }
    }
    var showDocumentHistory: Bool {
        get { rightPane == .history }
        nonmutating set { rightPane = newValue ? .history : (rightPane == .history ? .none : rightPane) }
    }
    var showComments: Bool {
        get { rightPane == .comments }
        nonmutating set { rightPane = newValue ? .comments : (rightPane == .comments ? .none : rightPane) }
    }

    public init() {}

    var wordCount: Int { stats.words }

    var characterCount: Int { stats.characters }

    func refreshStats() {
        stats = (EditorPerformanceCache.countWords(in: documentController.rawText), documentController.rawText.count)
    }

    var readingTimeMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 200.0)))
    }

    var currentSheetWidth: CGFloat {
        documentController.pageSize.dimensions.width
    }

    var currentSheetHeight: CGFloat {
        documentController.pageSize.dimensions.height
    }

    func shortFontDisplayName(_ rawName: String) -> String {
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

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Toast Overlay (Sonner-style)
                ToastOverlay(position: .bottomTrailing)
                    .environmentObject(toastManager)
                    .allowsHitTesting(true)

                // 1. Sleek Minimalist Glass Top Navigation Bar (Responsive across window widths)
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
                .layoutPriority(-1)
                
                Divider().frame(height: 18)

                // Word-Style Font Formatting Controls
                HStack(spacing: 5) {
                    // Paragraph Style Preset Picker (Title, Heading 1-3, Body, Blockquote, Caption)
                    Menu {
                        ForEach(DocumentParagraphStyle.allCases) { preset in
                            Button {
                                applyParagraphStyleAction(preset)
                            } label: {
                                if (selectionAttributes?.paragraphStylePreset ?? .body) == preset {
                                    Label("\(preset.rawValue) (\(Int(preset.fontSize)) pt)", systemImage: "checkmark")
                                } else {
                                    Text("\(preset.rawValue) (\(Int(preset.fontSize)) pt)")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text((selectionAttributes?.paragraphStylePreset ?? .body).rawValue)
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
                            Button(fam) { setFontFamilyAction(fam) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(shortFontDisplayName(selectionAttributes?.fontFamily ?? documentController.fontFamily))
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
                        Button(action: { setFontSizeAction((selectionAttributes?.fontSize ?? documentController.fontSize) - 1) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 30)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(5)
                        }
                        
                        Text("\(Int(selectionAttributes?.fontSize ?? documentController.fontSize))")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .frame(width: 24, alignment: .center)
                            
                        Button(action: { setFontSizeAction((selectionAttributes?.fontSize ?? documentController.fontSize) + 1) }) {
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
                        Button(action: { toggleBoldAction() }) {
                            Image(systemName: "bold")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor((selectionAttributes?.isBold ?? isBold) ? .accentColor : .primary)
                                .frame(width: 30, height: 30)
                                .background((selectionAttributes?.isBold ?? isBold) ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                                .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                        .help("Bold (⌘B)")

                        Button(action: { toggleItalicAction() }) {
                            Image(systemName: "italic")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor((selectionAttributes?.isItalic ?? isItalic) ? .accentColor : .primary)
                                .frame(width: 30, height: 30)
                                .background((selectionAttributes?.isItalic ?? isItalic) ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                                .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                        .help("Italic (⌘I)")

                        Button(action: { toggleUnderlineAction() }) {
                            Image(systemName: "underline")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor((selectionAttributes?.isUnderline ?? isUnderline) ? .accentColor : .primary)
                                .frame(width: 30, height: 30)
                                .background((selectionAttributes?.isUnderline ?? isUnderline) ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
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
                                    .fill(textColorState)
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
                                selectedColor: $textColorState,
                                isHighlight: false,
                                allowNoColor: true,
                                clearTitle: "Default Color",
                                onSelectColor: { newColor in
                                    textColorState = newColor
                                    setTextColorAction(NSColor(newColor))
                                },
                                onClearColor: {
                                    let defaultColor = Color(red: 0.10, green: 0.10, blue: 0.12)
                                    textColorState = defaultColor
                                    setTextColorAction(NSColor(defaultColor))
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
                                    .fill(highlightColorState)
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
                                selectedColor: $highlightColorState,
                                isHighlight: true,
                                allowNoColor: true,
                                clearTitle: "No Highlight",
                                onSelectColor: { newColor in
                                    highlightColorState = newColor
                                    setTextHighlightAction(NSColor(newColor).withAlphaComponent(0.42))
                                },
                                onClearColor: {
                                    setTextHighlightAction(nil)
                                    showHighlightColorPopover = false
                                },
                                onDismiss: {
                                    showHighlightColorPopover = false
                                }
                            )
                        }

                        // Clear Formatting
                        Button(action: { clearFormattingAction() }) {
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
                            editorController.cleanContrastForCurrentSelection()
                            showToast("✓ Cleaned text contrast (dark mode sanitized)")
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
                        Button("Left") { setAlignmentAction(.leading) }
                        Button("Center") { setAlignmentAction(.center) }
                        Button("Right") { setAlignmentAction(.trailing) }
                    } label: {
                        let align = selectionAttributes?.alignment ?? documentController.textAlignment
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
                        Button(action: { insertBulletListAction() }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 30, height: 30)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Bulleted List (⇧⌘8)")

                        Button(action: { insertNumberedListAction() }) {
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
                                setLineSpacingAction(CGFloat(val))
                            } label: {
                                if abs(documentController.lineSpacing - CGFloat(val)) < 0.02 {
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
                                setParagraphSpacingAction(CGFloat(val))
                            } label: {
                                if abs(documentController.paragraphSpacing - CGFloat(val)) < 0.5 {
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
                            Text("\(String(format: "%.2g", documentController.lineSpacing)) · \(Int(documentController.paragraphSpacing))pt")
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
                    .help("Line Spacing (\(String(format: "%.2g", documentController.lineSpacing))) & Paragraph Spacing (\(Int(documentController.paragraphSpacing)) pt)")
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                // Quick Action Center (AI, Timeline, Command)
                HStack(spacing: 6) {
                    // Timeline
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showDocumentHistory.toggle()
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
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showComments.toggle() }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 12, weight: .medium))
                            Text("Comments")
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            if !documentController.sideNotes.isEmpty {
                                Text("\(documentController.sideNotes.filter { !$0.isResolved }.count)")
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
                            showPageDesignInspector.toggle()
                            if showPageDesignInspector {
                                showAIDrawer = false
                                showDocumentHistory = false
                            }
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
                        showToast(documentController.isTrackChangesEnabled ? "✓ Track Changes: ON" : "✓ Track Changes: OFF")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.and.outline")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Review")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            if !documentController.revisions.isEmpty {
                                Text("\(documentController.revisions.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.orange))
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 30)
                        .background(documentController.isTrackChangesEnabled ? Color.orange.opacity(0.18) : Color.primary.opacity(0.06))
                        .foregroundColor(documentController.isTrackChangesEnabled ? .orange : .primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(documentController.isTrackChangesEnabled ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
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
                            showAIDrawer.toggle()
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
                    Button(action: { showCommandPalette.toggle() }) {
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

            // Review Toolbar Strip (Track Changes Active or Pending Revisions)
            if documentController.isTrackChangesEnabled || !documentController.revisions.isEmpty {
                reviewToolbarStrip
            }

            // Header & Footer Editor Toolbar Strip (Docked, Non-Modal, Zero Overlap)
            if isEditingHeaderFooter {
                headerFooterToolbarStrip
            }

            // 2. Three-pane workspace: Outline | Sanctuary Canvas | Contextual pane
            HStack(spacing: 0) {
                if showOutlineDrawer {
                    DocumentOutlineView(
                        isPresented: $showOutlineDrawer,
                        rawText: $documentController.rawText,
                        cursorOffset: selectionRange.location,
                        pageCount: editorController.pageCount,
                        pageForOffset: { editorController.pageNumber(forCharacterOffset: $0) },
                        pageSnippet: { editorController.snippet(forPage: $0) },
                        sources: $documentController.document.sources,
                        activeCitationStyle: $documentController.citationStyle,
                        onSelectOffset: { offset in editorController.jumpToCharacterOffset(offset) },
                        onSelectHeading: { _, offset in editorController.jumpToCharacterOffset(offset) },
                        onSelectPage: { page in editorController.scrollToPage(page) }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    Divider()
                }

                canvasColumn

                // Docked Right Contextual Inspector / Copilot / Document History Panes
                if showPageDesignInspector {
                    Divider()

                    StudioContextualInspectorView(
                        isPresented: paneBinding(.inspector),
                        fontFamily: $documentController.fontFamily,
                        fontSize: $documentController.fontSize,
                        lineSpacing: $documentController.lineSpacing,
                        paragraphSpacing: $documentController.paragraphSpacing,
                        hangingIndent: $documentController.hangingIndent,
                        textAlignment: $documentController.textAlignment,
                        pageSize: $documentController.pageSize,
                        marginPreset: $documentController.marginPreset,
                        margins: $documentController.margins,
                        columnCount: $documentController.columnCount,
                        showLineNumbers: $documentController.showLineNumbers,
                        showMarginGuides: $showMarginGuides,
                        citationStyle: $documentController.citationStyle,
                        sources: $documentController.document.sources,
                        selectionAttributes: selectionAttributes,
                        onToggleBold: { toggleBoldAction() },
                        onToggleItalic: { toggleItalicAction() },
                        onToggleUnderline: { toggleUnderlineAction() },
                        onToggleStrikethrough: { toggleStrikethroughAction() },
                        onApplyParagraphStyle: { style in applyParagraphStyleAction(style) },
                        onAddSource: { showingAddSourceSheet = true },
                        onInsertBibliography: { insertBibliographyAction() },
                        onToast: { msg in showToast(msg) }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else if showAIDrawer {
                    Divider()

                    AssistantSidebarView(
                        rawText: $documentController.rawText,
                        selectedText: $selectedText,
                        onInsertTable: { table in
                            let marker = "\n\n[[table:\(table.id.uuidString)]]\n\n"
                            editorController.insertAtCaret(marker)
                            documentController.tables.append(table)
                            documentController.commitSnapshot(actionName: "Insert Table", isMilestone: true)
                        },
                        onInsertSource: { source in
                            documentController.document.sources[source.id] = source
                            let citeTag = "(\(source.authors.first ?? "Author"), \(source.year != nil ? "\(source.year!)" : "n.d."))"
                            if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
                                let ns = documentController.rawText as NSString
                                documentController.rawText = ns.replacingCharacters(in: selectionRange, with: " " + citeTag + " ")
                            }
                        },
                        onInsertHeading: { level, title in
                            insertSectionHeadingAction(level: level, customTitle: title)
                        },
                        onSetMargins: { presetStr in
                            let lower = presetStr.lowercased()
                            if lower.contains("narrow") {
                                documentController.marginPreset = .narrow
                            } else if lower.contains("wide") {
                                documentController.marginPreset = .wide
                            } else {
                                documentController.marginPreset = .normal
                            }
                        },
                        onInsertPageBreak: {
                            insertPageBreakAction()
                        },
                        onInsertTOC: {
                            insertTOCAction()
                        },
                        onInsertBibliography: {
                            insertBibliographyAction()
                        },
                        onToast: { msg in showToast(msg) },
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showAIDrawer = false
                            }
                        },
                        currentDocumentContext: { buildDocumentAIContext() }
                    )
                    .frame(width: 320)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else if showDocumentHistory {
                    Divider()

                    StudioDocumentHistoryView(isPresented: paneBinding(.history), store: documentController)
                        .frame(width: 300)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else if showComments {
                    Divider()

                    commentsPane
                        .frame(width: 300)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            // 3. Docked App Footer (Stats, Style Linter, Citation Standard, Zoom, AI Copilot)
            StatusBarMetrics(
                wordCount: wordCount,
                characterCount: characterCount,
                pageCount: editorController.pageCount,
                readingTimeMinutes: readingTimeMinutes,
                citationStyle: documentController.citationStyle.displayName,
                styleProfile: documentController.styleProfile,
                zoomScale: zoomScale
            )
        }
        .sheet(isPresented: $showingAddSourceSheet) {
            VStack(spacing: 16) {
                Text("Add Linked Source Citation")
                    .font(.headline)

                Form {
                    TextField("Title", text: $newSourceTitle)
                    TextField("Author(s) (comma separated)", text: $newSourceAuthor)
                    TextField("Year", text: $newSourceYear)
                    Picker("Source Type", selection: $newSourceType) {
                        ForEach(SourceType.allCases, id: \.self) { st in
                            Text(st.rawValue.capitalized).tag(st)
                        }
                    }
                }
                .frame(width: 320)

                HStack {
                    Button("Cancel") {
                        showingAddSourceSheet = false
                    }
                    Button("Add & Insert") {
                        let id = UUID().uuidString.prefix(6).lowercased()
                        let authors = newSourceAuthor.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        let yearInt = Int(newSourceYear)
                        let source = Source(
                            id: String(id),
                            sourceType: newSourceType,
                            authors: authors,
                            year: yearInt,
                            title: newSourceTitle
                        )
                        documentController.document.sources[String(id)] = source
                        let ref = CitationReference(sourceId: String(id))
                        let rendered = CoreBridge.shared.renderCitation(source: source, reference: ref, style: documentController.citationStyle)
                        documentController.rawText += " \(rendered)"
                        showingAddSourceSheet = false
                        newSourceTitle = ""
                        newSourceAuthor = ""
                        newSourceYear = ""
                        showToast("✓ Added citation \(rendered)")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newSourceTitle.isEmpty)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showingCrossReferenceSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Insert Cross Reference")
                    .font(.headline)
                
                if documentController.images.isEmpty {
                    Text("No figures available to reference.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(documentController.images) { img in
                            Button {
                                insertCrossReference(targetId: img.id.uuidString, type: "Figure")
                                showingCrossReferenceSheet = false
                            } label: {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("Figure \(figureNumber(for: img.id))")
                                        .bold()
                                    if !img.caption.isEmpty {
                                        Text("- \(img.caption)").foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 200)
                }
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingCrossReferenceSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(20)
            .frame(width: 400)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView(
                isPresented: $showCommandPalette,
                commands: paletteCommands,
                onExecuteDirectCLI: executeDirectCLICommand
            )
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(
                isPresented: $showingSettingsSheet,
                fontFamily: $documentController.fontFamily,
                fontSize: $documentController.fontSize,
                citationStyle: $documentController.citationStyle,
                pageSize: $documentController.pageSize,
                marginPreset: $documentController.marginPreset,
                showMarginGuides: $showMarginGuides,
                showCropMarks: $showCropMarks,
                onToast: { msg in showToast(msg) }
            )
        }
        .sheet(isPresented: $showingPasteSpecialSheet) {
            pasteSpecialSheetView
        }
        .modifier(EditorFileNotificationsModifier(
            onNew: newDocumentAction,
            onOpen: openDocument,
            onRestoreAutosave: restoreAutosaveAction,
            onImportWordOrPDF: importWordOrPDF,
            onSave: saveDocumentAsLetters,
            onExportDocx: saveDocumentAsDocx,
            onExportPDF: exportDocumentAsPDF,
            onExportMarkdown: saveDocumentAsMarkdown,
            onPrint: printDocument,
            onSettings: { showingSettingsSheet = true }
        ))
        .modifier(EditorFormatNotificationsModifier(
            onBold: toggleBoldAction,
            onItalic: toggleItalicAction,
            onUnderline: toggleUnderlineAction,
            onAlignLeft: { setAlignmentAction(.leading) },
            onAlignCenter: { setAlignmentAction(.center) },
            onAlignRight: { setAlignmentAction(.trailing) },
            onTable: { handleToolAction(.table) },
            onImage: insertImageAction,
            onVideo: {},
            onCitation: { showingAddSourceSheet = true },
            onFootnote: insertFootnote,
            onSideNote: insertSideNote,
            onTOC: insertTOCAction,
            onBibliography: insertBibliographyAction,
            onPageBreak: insertPageBreakAction
        ))
        .modifier(EditorViewNotificationsModifier(
            onFindReplace: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showFindReplace.toggle()
                }
            },
            onZoomIn: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = min(2.5, zoomScale + 0.15)
                }
                showToast("✓ Zoom: \(Int(zoomScale * 100))%")
            },
            onZoomOut: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = max(0.4, zoomScale - 0.15)
                }
                showToast("✓ Zoom: \(Int(zoomScale * 100))%")
            },
            onZoomReset: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = 1.0
                }
                showToast("✓ Zoom: 100%")
            },
            onToggleRuler: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showRuler.toggle()
                }
                showToast(showRuler ? "✓ Horizontal Ruler visible" : "✓ Horizontal Ruler hidden")
            },
            onOutline: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showOutlineDrawer.toggle()
                }
            },
            onAIDrawer: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAIDrawer.toggle()
                }
            },
            onPageDesign: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showPageDesignInspector.toggle()
                    if showPageDesignInspector {
                        showAIDrawer = false
                        showDocumentHistory = false
                    }
                }
            },
            onDocumentHistory: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showDocumentHistory.toggle()
                    if showDocumentHistory {
                        showAIDrawer = false
                        showPageDesignInspector = false
                    }
                }
            },
            onCommandPalette: {
                // ⌘K: with a selection it asks the AI about it, otherwise it opens the command palette.
                if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { showInlineAI.toggle() }
                } else {
                    showCommandPalette.toggle()
                }
            },
            onToggleTrackChanges: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    documentController.isTrackChangesEnabled.toggle()
                }
                showToast(documentController.isTrackChangesEnabled ? "✓ Track Changes: ON" : "✓ Track Changes: OFF")
            },
            onPasteAndMatchStyle: {
                editorController.pasteSpecial(mode: .matchStyle)
                showToast("✓ Pasted and Matched Style")
            },
            onPasteSpecial: {
                showingPasteSpecialSheet = true
            }
        ))
        .onAppear {
            refreshStats()
            runLinter()
            editorController.focusCanvas()
            
            editorController.onImportFile = { url in
                self.importFileNatively(url: url)
            }
            editorController.onInsertImageBlock = { block in
                self.documentController.images.append(block)
                let marker = "\n\n[[image:\(block.id.uuidString)]]\n\n"
                editorController.insertAtCaret(marker)
                self.documentController.commitSnapshot(actionName: "Insert Image", isMilestone: true)
                self.showToast("✓ Inserted Image Figure")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("lettersOpenFileURL"))) { note in
            if let url = note.object as? URL {
                openDocumentFromURL(url)
            }
        }
        .onReceive(documentController.$rawText.debounce(for: .milliseconds(350), scheduler: RunLoop.main)) { _ in
            refreshStats()
            runLinter()
        }
        .onChange(of: documentController.styleProfile) {
            runLinter()
        }
    }
    }

    var unreferencedTableIndices: [Int] {
        documentController.tables.indices.filter { idx in
            let idStr = documentController.tables[idx].id.uuidString
            let hasBudgetMarker = (idx == 0 && documentController.rawText.contains("[[table:budget]]"))
            return !documentController.rawText.contains("[[table:\(idStr)]]") && !hasBudgetMarker
        }
    }

    var unreferencedImageIndices: [Int] {
        documentController.images.indices.filter { idx in
            let idStr = documentController.images[idx].id.uuidString
            return !documentController.rawText.contains("[[image:\(idStr)]]")
        }
    }

    var unreferencedVideoIndices: [Int] {
        documentController.videos.indices.filter { idx in
            let idStr = documentController.videos[idx].id.uuidString
            return !documentController.rawText.contains("[[video:\(idStr)]]")
        }
    }

    // MARK: - Actions
    func newDocumentAction() {
        documentController.title = "Untitled Document"
        documentController.rawText = ""
        documentController.richTextData = nil
        documentController.tables = []
        documentController.images = []
        documentController.videos = []
        documentController.floatingElements = []
        documentController.footnotes = []
        documentController.sideNotes = []
        documentController.document.sources = [:]
        selectionAttributes = nil
        showToast("✓ Created New Document")
    }

    enum StudioTool {
        case select, text, table, image, citation, style, copilot, pan
    }

    func handleToolAction(_ tool: StudioTool) {
        switch tool {
        case .select:
            showToast("✓ Selection Tool active")
        case .text:
            documentController.rawText += "\n\nNew Section Heading\nType section body text here..."
            showToast("✓ Inserted Text Section")
        case .table:
            let newTable = StudioTableData(
                title: "",
                headers: ["", "", "", ""],
                rows: [
                    ["", "", "", ""],
                    ["", "", "", ""],
                    ["", "", "", ""]
                ]
            )

            let marker = "\n\n[[table:\(newTable.id.uuidString)]]\n\n"
            editorController.insertAtCaret(marker)
            // Append table AFTER modifying rawText so they are part of the same frame
            documentController.tables.append(newTable)
            documentController.commitSnapshot(actionName: "Insert Table", isMilestone: true)
            showToast("✓ Added Table with cell formula support")
        case .image:
            insertImageAction()
        case .citation:
            showingAddSourceSheet = true
            showToast("✓ Add Linked Citation")
        case .style:
            runLinter()
            showToast("✓ Scanned style rules: \(lintIssues.count) notices found")
        case .copilot:
            showAIDrawer.toggle()
            showToast("✓ AI Copilot toggled")
        case .pan:
            showToast("✓ Hand Pan tool active")
        }
    }

    func insertImageAction() {
        StudioImageView.pickImageFromDisk { block in
            if let block = block {
                documentController.images.append(block)
                let marker = "\n\n[[image:\(block.id.uuidString)]]\n\n"
                editorController.insertAtCaret(marker)
                showToast("✓ Inserted Image Figure")
            }
        }
    }

    func insertPageBreakAction() {
        editorController.insertAtCaret("\n\n---pagebreak---\n\n")
        showToast("✓ Inserted Page Break")
    }

    func insertTOCAction() {
        let marker = "\n\n[[toc]]\n\n"
        editorController.insertAtCaret(marker)
        showToast("✓ Inserted Table of Contents")
    }

    func insertBibliographyAction() {
        let marker = "\n\n[[bibliography]]\n\n"
        editorController.insertAtCaret(marker)
        showToast("✓ Inserted Bibliography / Works Cited")
    }

    func toggleStrikethroughAction() {
        editorController.toggleStrikethrough()
        showToast("✓ Strikethrough toggled")
    }

    func applyParagraphStyleAction(_ preset: DocumentParagraphStyle) {
        let fam = selectionAttributes?.fontFamily ?? documentController.fontFamily
        editorController.applyParagraphStyle(
            preset,
            fontFamily: fam,
            lineSpacing: documentController.lineSpacing,
            paragraphSpacing: documentController.paragraphSpacing
        )
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        showToast("✓ Applied Style: \(preset.rawValue)")
    }

    func insertSectionHeadingAction(level: Int = 1, customTitle: String? = nil) {
        if let customTitle = customTitle {
            let hashes = String(repeating: "#", count: max(1, min(6, level)))
            let item = "\(hashes) \(customTitle)"
            if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
                let ns = documentController.rawText as NSString
                documentController.rawText = ns.replacingCharacters(in: selectionRange, with: item)
            } else {
                documentController.rawText = documentController.rawText.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + item
            }
        }
        let preset: DocumentParagraphStyle = (level == 1) ? .heading1 : (level == 2 ? .heading2 : .heading3)
        applyParagraphStyleAction(preset)
    }

    func insertChecklistAction() {
        let item = "\n- [ ] Task item\n"
        editorController.insertAtCaret(item)
        showToast("✓ Inserted Checklist Item")
    }

    func insertBlockquoteAction() {
        let item = "\n> Quoted text block\n"
        editorController.insertAtCaret(item)
        showToast("✓ Inserted Blockquote")
    }

    func insertCodeBlockAction() {
        let item = "\n```swift\n// Code snippet\n```\n"
        editorController.insertAtCaret(item)
        showToast("✓ Inserted Code Block")
    }

    func insertDividerAction() {
        let item = "\n\n---\n\n"
        editorController.insertAtCaret(item)
        showToast("✓ Inserted Horizontal Divider")
    }

    func insertDateTimeAction() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let str = formatter.string(from: Date())
        editorController.insertAtCaret(str)
        showToast("✓ Inserted Date/Time: \(str)")
    }

    func transformTextSelection(mode: String) {
        guard !selectedText.isEmpty else {
            showToast("⚠️ Select text first to transform case")
            return
        }
        let transformed: String
        switch mode {
        case "upper": transformed = selectedText.uppercased()
        case "lower": transformed = selectedText.lowercased()
        case "capitalized": transformed = selectedText.capitalized
        default: transformed = selectedText
        }
        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: transformed)
        } else {
            documentController.rawText = documentController.rawText.replacingOccurrences(of: selectedText, with: transformed)
        }
        showToast("✓ Transformed Text: \(mode)")
    }

    func setLineSpacingAction(_ spacing: CGFloat) {
        documentController.lineSpacing = spacing
        editorController.applyLineSpacing(spacing, paragraphSpacing: documentController.paragraphSpacing)
        showToast("✓ Line Spacing: \(String(format: "%.2g", spacing))")
    }

    func setParagraphSpacingAction(_ spacing: CGFloat) {
        documentController.paragraphSpacing = spacing
        editorController.applyLineSpacing(documentController.lineSpacing, paragraphSpacing: spacing)
        showToast("✓ Paragraph Spacing: \(Int(spacing)) pt")
    }

    func insertBulletListAction() {
        editorController.toggleBulletList()
        showToast("✓ Toggled Bulleted List")
    }

    func insertNumberedListAction() {
        editorController.toggleNumberedList()
        showToast("✓ Toggled Numbered List")
    }

    func toggleBoldAction() {
        editorController.toggleBold()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isBold ? "✓ Bold enabled" : "Bold disabled")
        } else {
            isBold.toggle()
            showToast(isBold ? "✓ Bold enabled" : "Bold disabled")
        }
    }

    func setTextColorAction(_ color: NSColor) {
        editorController.setTextColor(color)
        showToast("✓ Text color applied")
    }

    func setTextHighlightAction(_ color: NSColor?) {
        editorController.setTextHighlight(color)
        showToast(color == nil ? "✓ Highlight removed" : "✓ Text highlighted")
    }

    func clearFormattingAction() {
        editorController.clearFormatting()
        showToast("✓ Formatting cleared (Reset to Black)")
    }

    func toggleKeepLinesTogetherAction() {
        editorController.toggleKeepLinesTogether()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isKeepLinesTogether ? "✓ Keep Lines Together enabled" : "Keep Lines Together disabled")
        }
    }

    func toggleKeepWithNextAction() {
        editorController.toggleKeepWithNext()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isKeepWithNext ? "✓ Keep With Next enabled" : "Keep With Next disabled")
        }
    }

    func toggleItalicAction() {
        editorController.toggleItalic()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isItalic ? "✓ Italic enabled" : "Italic disabled")
        } else {
            isItalic.toggle()
            showToast(isItalic ? "✓ Italic enabled" : "Italic disabled")
        }
    }

    func toggleUnderlineAction() {
        editorController.toggleUnderline()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isUnderline ? "✓ Underline enabled" : "Underline disabled")
        } else {
            isUnderline.toggle()
            showToast(isUnderline ? "✓ Underline enabled" : "Underline disabled")
        }
    }

    func setAlignmentAction(_ align: TextAlignment) {
        if selectionRange.length == 0 && (documentController.rawText as NSString).length == 0 {
            documentController.textAlignment = align
        }
        editorController.applyAlignment(align, lineSpacing: documentController.lineSpacing, paragraphSpacing: documentController.paragraphSpacing)
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        let name = align == .leading ? "Left" : align == .center ? "Center" : "Right"
        showToast("✓ Alignment: \(name)")
    }

    func setFontFamilyAction(_ font: String) {
        let sizeToApply = selectionAttributes?.fontSize ?? documentController.fontSize
        editorController.applyFontFamily(font, size: sizeToApply)
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        showToast("✓ Font: \(font)")
    }

    func setFontSizeAction(_ size: CGFloat) {
        editorController.applyFontSize(size)
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        showToast("✓ Font Size: \(Int(size)) pt")
    }

    func insertCitationForSelection() {
        showingAddSourceSheet = true
    }

    func insertFootnote() {
        let fnNumber = documentController.footnotes.count + 1
        let footnoteId = UUID()
        let marker = "\(fnNumber)"
        
        // Add model
        documentController.footnotes.append(StudioFootnote(id: footnoteId, referenceMarker: marker, text: "New Footnote Text"))
        
        // Insert into text
        let refStr = "[\(marker)]"
        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            let replaced = ns.replacingCharacters(in: selectionRange, with: refStr)
            documentController.rawText = replaced
        } else {
            // Append to current location if cursor is available, else append to end
            documentController.rawText += refStr
        }
        
        documentController.commitSnapshot(actionName: "Insert Footnote", isMilestone: false)
    }

    func insertCrossReference(targetId: String, type: String) {
        if documentController.richTextData == nil {
            let attrStr = NSAttributedString(string: documentController.rawText)
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: attrStr, requiringSecureCoding: false) {
                documentController.richTextData = data
            }
        }
        
        let attachment = CrossReferenceAttachment(targetId: targetId, targetType: type)
        editorController.insertAttachment(attachment)
        documentController.commitSnapshot(actionName: "Insert Cross Reference", isMilestone: false)
    }

    func insertSideNote() {
        let snNumber = documentController.sideNotes.count + 1
        let snId = UUID()
        let marker = "note:\(snNumber)"

        // Non-destructive: extract anchor text snippet and range from selection
        var anchorSnippet: String? = nil
        let ns = documentController.rawText as NSString
        let hasSelection = selectionRange.length > 0 && selectionRange.location + selectionRange.length <= ns.length
        if hasSelection {
            anchorSnippet = ns.substring(with: selectionRange)
        }

        documentController.sideNotes.append(
            StudioSideNote(
                id: snId,
                referenceMarker: marker,
                text: "Comment...",
                anchorText: anchorSnippet,
                rangeLocation: hasSelection ? selectionRange.location : nil,
                rangeLength: hasSelection ? selectionRange.length : nil,
                author: NSFullUserName().isEmpty ? "Reviewer" : NSFullUserName(),
                createdAt: Date(),
                isResolved: false
            )
        )

        // Document text stays 100% clean and pristine (no ugly [note:N] injected!)
        documentController.commitSnapshot(actionName: "Insert Margin Comment", isMilestone: false)
        showToast("💬 Added comment on selection")
    }

    func executeDirectCLICommand(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()

        // 1. Font Size (e.g. "size 24", "font 18", "pt 14")
        if lower.hasPrefix("size ") || lower.hasPrefix("font ") || lower.hasPrefix("pt ") {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let pt = Double(parts[1]), pt >= 6 && pt <= 144 {
                setFontSizeAction(CGFloat(pt))
                return true
            }
        }

        // 2. Font Family (e.g. "font georgia", "font sf pro", "font times")
        if lower.hasPrefix("font ") {
            let arg = lower.replacingOccurrences(of: "font ", with: "").trimmingCharacters(in: .whitespaces)
            if arg.contains("georgia") { setFontFamilyAction("Default Serif (Georgia)"); return true }
            if arg.contains("times") { setFontFamilyAction("Times New Roman"); return true }
            if arg.contains("sf") || arg.contains("san") { setFontFamilyAction("SF Pro"); return true }
            if arg.contains("helvetica") { setFontFamilyAction("Helvetica"); return true }
            if arg.contains("charter") { setFontFamilyAction("Charter"); return true }
            if arg.contains("menlo") || arg.contains("mono") { setFontFamilyAction("Menlo (Monospace)"); return true }
            if arg.contains("courier") { setFontFamilyAction("Courier"); return true }
        }

        // 3. Zoom (e.g. "zoom 125", "zoom 100")
        if lower.hasPrefix("zoom ") {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let z = Double(parts[1]), z >= 25 && z <= 500 {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = CGFloat(z / 100.0)
                }
                showToast("✓ Zoom: \(Int(z))%")
                return true
            }
        }

        // 4. Margins (e.g. "documentController.margins narrow", "documentController.margins standard", "margin 0.5")
        if lower.hasPrefix("margin") {
            if lower.contains("narrow") { documentController.marginPreset = .narrow; showToast("✓ Margins: Narrow"); return true }
            if lower.contains("wide") { documentController.marginPreset = .wide; showToast("✓ Margins: Wide"); return true }
            if lower.contains("moderate") { documentController.marginPreset = .moderate; showToast("✓ Margins: Moderate"); return true }
            if lower.contains("standard") || lower.contains("normal") { documentController.marginPreset = .normal; showToast("✓ Margins: Normal"); return true }
        }

        // 5. Page Size (e.g. "page a4", "page letter", "page legal")
        if lower.hasPrefix("page ") {
            if lower.contains("a4") { documentController.pageSize = .a4; showToast("✓ Page Size: A4"); return true }
            if lower.contains("letter") { documentController.pageSize = .letter; showToast("✓ Page Size: US Letter"); return true }
            if lower.contains("legal") { documentController.pageSize = .legal; showToast("✓ Page Size: US Legal"); return true }
            if lower.contains("exec") { documentController.pageSize = .executive; showToast("✓ Page Size: Executive"); return true }
        }

        // 6. Line Spacing (e.g. "line 1.5", "spacing 2", "leading 1.25")
        if lower.hasPrefix("line ") || lower.hasPrefix("spacing ") || lower.hasPrefix("leading ") {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let sp = Double(parts[1]), sp >= 0.8 && sp <= 4.0 {
                setLineSpacingAction(CGFloat(sp))
                return true
            }
        }

        // 7. Headings (e.g. "h1 Intro", "h2 Methods", "title Overview")
        if lower.hasPrefix("h1 ") {
            insertSectionHeadingAction(level: 1, customTitle: String(trimmed.dropFirst(3)))
            return true
        }
        if lower.hasPrefix("h2 ") {
            insertSectionHeadingAction(level: 2, customTitle: String(trimmed.dropFirst(3)))
            return true
        }
        if lower.hasPrefix("h3 ") {
            insertSectionHeadingAction(level: 3, customTitle: String(trimmed.dropFirst(3)))
            return true
        }
        if lower.hasPrefix("title ") {
            insertSectionHeadingAction(level: 1, customTitle: String(trimmed.dropFirst(6)))
            return true
        }

        // 8. Header & Footer (e.g. "header", "edit header", "footer", "edit footer", "page number", "page numbers", "exit header", "close header")
        if lower == "header" || lower == "edit header" || lower == "headers" {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                activeHeaderFooterTarget = .header
                isEditingHeaderFooter = true
            }
            showToast("✓ Header editor activated")
            return true
        }
        if lower == "footer" || lower == "edit footer" || lower == "footers" {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                activeHeaderFooterTarget = .footer
                isEditingHeaderFooter = true
            }
            showToast("✓ Footer editor activated")
            return true
        }
        if lower == "page number" || lower == "page numbers" || lower == "pagenum" || lower == "numbering" {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                activeHeaderFooterTarget = .footer
                isEditingHeaderFooter = true
            }
            showToast("✓ Page numbering settings opened")
            return true
        }
        if lower == "close header" || lower == "close footer" || lower == "done header" || lower == "exit header" {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isEditingHeaderFooter = false
            }
            showToast("✓ Header & footer editor closed")
            return true
        }

        // 9. Find (e.g. "find keyword")
        if lower.hasPrefix("find ") {
            showFindReplace = true
            showToast("✓ Search opened for: \(trimmed.dropFirst(5))")
            return true
        }

        // 10. AI prompt execution
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showAIDrawer = true
        }
        showToast("✨ AI Copilot prompted: \"\(trimmed)\"")
        return true
    }

    var paletteCommands: [CommandItem] {
        [
            // === File & Document Operations ===
            CommandItem(title: "Save Native .letters Package", subtitle: "Lossless Project Letters document archive", icon: "tray.and.arrow.down.fill", category: .document, shortcut: "⌘S", keywords: ["save", "native", "package", "store"]) {
                saveDocumentAsLetters()
            },
            CommandItem(title: "Open Existing Document", subtitle: "Open .letters, .docx, or .md file from disk", icon: "folder", category: .document, shortcut: "⌘O", keywords: ["open", "import", "browse", "load"]) {
                openDocument()
            },
            CommandItem(title: "Export as Word Document (.docx)", subtitle: "Generate native lossless Microsoft Word document", icon: "doc.fill", category: .document, shortcut: "⌘⇧S", keywords: ["export", "word", "docx", "microsoft"]) {
                saveDocumentAsDocx()
            },
            CommandItem(title: "Export as Vector PDF (.pdf)", subtitle: "High resolution publication PDF ready for printing", icon: "arrow.down.doc", category: .document, shortcut: "⌘⌥E", keywords: ["pdf", "vector", "export", "print"]) {
                exportDocumentAsPDF()
            },
            CommandItem(title: "Print Document", subtitle: "Open native macOS Print setup & pagination dialog", icon: "printer", category: .document, shortcut: "⌘P", keywords: ["print", "paper", "dialog"]) {
                printDocument()
            },
            CommandItem(title: "Document Statistics & Word Count", subtitle: "\(wordCount) words, \(characterCount) chars, \(editorController.pageCount) pages", icon: "chart.bar.doc.horizontal", category: .document, shortcut: "⌘I", keywords: ["stats", "words", "count", "info"]) {
                showToast("📊 \(wordCount) words • \(characterCount) chars • \(editorController.pageCount) pages")
            },
            CommandItem(title: "Clear Document (New File)", subtitle: "Reset text, tables, figures, and sources", icon: "trash", category: .document, keywords: ["clear", "reset", "empty", "new"]) {
                newDocumentAction()
            },

            // === Formatting & Typography ===
            CommandItem(title: "Toggle Bold", subtitle: "Make selected text bold", icon: "bold", category: .formatting, shortcut: "⌘B", keywords: ["bold", "weight", "heavy"]) {
                toggleBoldAction()
            },
            CommandItem(title: "Toggle Italic", subtitle: "Make selected text italic", icon: "italic", category: .formatting, shortcut: "⌘I", keywords: ["italic", "oblique", "slant"]) {
                toggleItalicAction()
            },
            CommandItem(title: "Toggle Underline", subtitle: "Underline selected text", icon: "underline", category: .formatting, shortcut: "⌘U", keywords: ["underline"]) {
                toggleUnderlineAction()
            },
            CommandItem(title: "Toggle Strikethrough", subtitle: "Cross out selected text", icon: "strikethrough", category: .formatting, shortcut: "⇧⌘X", keywords: ["strike", "strikethrough", "cross"]) {
                toggleStrikethroughAction()
            },
            CommandItem(title: "Align Left", subtitle: "Set text alignment to leading edge", icon: "text.alignleft", category: .formatting, shortcut: "⌘{", keywords: ["align", "left", "leading"]) {
                setAlignmentAction(.leading)
            },
            CommandItem(title: "Align Center", subtitle: "Center text horizontally", icon: "text.aligncenter", category: .formatting, shortcut: "⌘|", keywords: ["align", "center"]) {
                setAlignmentAction(.center)
            },
            CommandItem(title: "Align Right", subtitle: "Set text alignment to trailing edge", icon: "text.alignright", category: .formatting, shortcut: "⌘}", keywords: ["align", "right", "trailing"]) {
                setAlignmentAction(.trailing)
            },
            CommandItem(title: "Line Spacing: 1.0 (Single)", subtitle: "Compact single line spacing", icon: "arrow.up.and.down.text.horizontal", category: .formatting, keywords: ["spacing", "single", "leading"]) {
                setLineSpacingAction(1.0)
            },
            CommandItem(title: "Line Spacing: 1.15 (Standard)", subtitle: "Default modern document spacing", icon: "arrow.up.and.down.text.horizontal", category: .formatting, keywords: ["spacing", "standard", "leading"]) {
                setLineSpacingAction(1.15)
            },
            CommandItem(title: "Line Spacing: 1.5 (1.5x)", subtitle: "Academic 1.5x line spacing", icon: "arrow.up.and.down.text.horizontal", category: .formatting, keywords: ["spacing", "academic", "leading"]) {
                setLineSpacingAction(1.5)
            },
            CommandItem(title: "Line Spacing: 2.0 (Double)", subtitle: "Double line spacing for manuscripts", icon: "arrow.up.and.down.text.horizontal", category: .formatting, keywords: ["spacing", "double", "leading"]) {
                setLineSpacingAction(2.0)
            },
            CommandItem(title: "Font: Georgia (Default Serif)", subtitle: "Classic editorial serif typeface", icon: "textformat", category: .formatting, keywords: ["font", "georgia", "serif"]) {
                setFontFamilyAction("Default Serif (Georgia)")
            },
            CommandItem(title: "Font: SF Pro (San Francisco)", subtitle: "Clean modern Apple sans-serif", icon: "textformat", category: .formatting, keywords: ["font", "sf pro", "sans"]) {
                setFontFamilyAction("SF Pro")
            },
            CommandItem(title: "Font: Times New Roman", subtitle: "Standard academic journal typeface", icon: "textformat", category: .formatting, keywords: ["font", "times", "academic"]) {
                setFontFamilyAction("Times New Roman")
            },
            CommandItem(title: "Font: Helvetica Neue", subtitle: "Swiss modernist sans-serif", icon: "textformat", category: .formatting, keywords: ["font", "helvetica", "swiss"]) {
                setFontFamilyAction("Helvetica")
            },
            CommandItem(title: "Font: Charter", subtitle: "High readability Bitstream serif", icon: "textformat", category: .formatting, keywords: ["font", "charter", "serif"]) {
                setFontFamilyAction("Charter")
            },
            CommandItem(title: "Font: Menlo Monospace", subtitle: "Fixed-width code and tabular font", icon: "character.textbox", category: .formatting, keywords: ["font", "menlo", "mono", "code"]) {
                setFontFamilyAction("Menlo (Monospace)")
            },
            CommandItem(title: "Transform to UPPERCASE", subtitle: "Convert selection to uppercase letters", icon: "textformat.size.larger", category: .formatting, keywords: ["case", "upper", "capitalize"]) {
                transformTextSelection(mode: "upper")
            },
            CommandItem(title: "Transform to lowercase", subtitle: "Convert selection to lowercase letters", icon: "textformat.size.smaller", category: .formatting, keywords: ["case", "lower"]) {
                transformTextSelection(mode: "lower")
            },
            CommandItem(title: "Transform to Title Case", subtitle: "Capitalize first letter of each word", icon: "textformat", category: .formatting, keywords: ["case", "title", "capitalize"]) {
                transformTextSelection(mode: "capitalized")
            },

            // === Insert Structural Elements ===
            CommandItem(title: "Insert Heading 1 (Title)", subtitle: "Top level document section title (#)", icon: "text.quote", category: .insert, shortcut: "⌘⌥1", keywords: ["h1", "title", "heading"]) {
                insertSectionHeadingAction(level: 1)
            },
            CommandItem(title: "Insert Heading 2 (Section)", subtitle: "Major section heading (##)", icon: "text.quote", category: .insert, shortcut: "⌘⌥2", keywords: ["h2", "section", "heading"]) {
                insertSectionHeadingAction(level: 2)
            },
            CommandItem(title: "Insert Heading 3 (Subsection)", subtitle: "Subsection heading (###)", icon: "text.quote", category: .insert, shortcut: "⌘⌥3", keywords: ["h3", "subsection", "heading"]) {
                insertSectionHeadingAction(level: 3)
            },
            CommandItem(title: "Insert Smart Table", subtitle: "Embed interactive calculation table with formulas", icon: "tablecells", category: .insert, shortcut: "⌘T", keywords: ["table", "grid", "spreadsheet", "formula"]) {
                handleToolAction(.table)
            },
            CommandItem(title: "Insert Bulleted List", subtitle: "Add bulleted list item (•)", icon: "list.bullet", category: .insert, shortcut: "⇧⌘8", keywords: ["bullet", "list", "item"]) {
                insertBulletListAction()
            },
            CommandItem(title: "Insert Numbered List", subtitle: "Add ordered numbered item (1.)", icon: "list.number", category: .insert, shortcut: "⇧⌘7", keywords: ["number", "ordered", "list"]) {
                insertNumberedListAction()
            },
            CommandItem(title: "Insert Task / Checklist", subtitle: "Interactive markdown check box (- [ ])", icon: "checkmark.square", category: .insert, keywords: ["task", "checklist", "todo", "box"]) {
                insertChecklistAction()
            },
            CommandItem(title: "Insert Blockquote", subtitle: "Styled pull quote with vertical rule (>)", icon: "quote.opening", category: .insert, keywords: ["quote", "blockquote", "callout"]) {
                insertBlockquoteAction()
            },
            CommandItem(title: "Insert Code Block", subtitle: "Monospaced syntax block (```)", icon: "chevron.left.forwardslash.chevron.right", category: .insert, keywords: ["code", "snippet", "block"]) {
                insertCodeBlockAction()
            },
            CommandItem(title: "Insert Image Figure", subtitle: "Add image with aspect ratio and caption", icon: "photo", category: .insert, keywords: ["image", "picture", "photo", "figure"]) {
                insertImageAction()
            },
            CommandItem(title: "Add Bibliographic Citation", subtitle: "Link source author, year, and DOI/URL", icon: "quote.bubble", category: .insert, keywords: ["cite", "citation", "source", "reference", "bibliography"]) {
                showingAddSourceSheet = true
            },
            CommandItem(title: "Insert Formatted Bibliography", subtitle: "Dynamic [[bibliography]] works cited block", icon: "books.vertical", category: .insert, keywords: ["bibliography", "works cited", "references"]) {
                insertBibliographyAction()
            },
            CommandItem(title: "Insert Table of Contents", subtitle: "Dynamic [[toc]] page reference listing", icon: "list.bullet.indent", category: .insert, keywords: ["toc", "table of contents", "outline"]) {
                insertTOCAction()
            },
            CommandItem(title: "Insert Page Break", subtitle: "Force document onto new page sheet", icon: "pagebreak", category: .insert, shortcut: "⌘↵", keywords: ["page", "break", "sheet"]) {
                insertPageBreakAction()
            },
            CommandItem(title: "Insert Horizontal Divider", subtitle: "Visual separator rule (---)", icon: "divide", category: .insert, keywords: ["divider", "line", "rule", "separator"]) {
                insertDividerAction()
            },
            CommandItem(title: "Insert Current Date & Time", subtitle: "Stamp current timestamp into document", icon: "clock", category: .insert, keywords: ["date", "time", "stamp", "now"]) {
                insertDateTimeAction()
            },

            // === Page Setup & Layout ===
            CommandItem(title: "Page Format: A4 (210 × 297 mm)", subtitle: "International standard document size", icon: "doc", category: .layout, keywords: ["a4", "format", "size", "iso"]) {
                documentController.pageSize = .a4
                showToast("✓ Page Format: A4")
            },
            CommandItem(title: "Page Format: US Letter (8.5 × 11 in)", subtitle: "North American standard paper size", icon: "doc", category: .layout, keywords: ["letter", "format", "size", "us"]) {
                documentController.pageSize = .letter
                showToast("✓ Page Format: US Letter")
            },
            CommandItem(title: "Page Format: US Legal (8.5 × 14 in)", subtitle: "Extended legal document format", icon: "doc", category: .layout, keywords: ["legal", "format", "size"]) {
                documentController.pageSize = .legal
                showToast("✓ Page Format: US Legal")
            },
            CommandItem(title: "Page Format: Executive", subtitle: "Compact 7.25 × 10.5 in executive format", icon: "doc", category: .layout, keywords: ["executive", "format", "size"]) {
                documentController.pageSize = .executive
                showToast("✓ Page Format: Executive")
            },
            CommandItem(title: "Margins: Standard (1 inch / 72 pt)", subtitle: "Balanced standard print margins", icon: "doc.viewfinder", category: .layout, keywords: ["margin", "standard", "1 inch"]) {
                documentController.marginPreset = .normal
                showToast("✓ Margins: Standard (72 pt)")
            },
            CommandItem(title: "Margins: Narrow (0.5 inch / 36 pt)", subtitle: "Maximized printable canvas area", icon: "doc.viewfinder", category: .layout, keywords: ["margin", "narrow", "0.5 inch"]) {
                documentController.marginPreset = .narrow
                showToast("✓ Margins: Narrow (36 pt)")
            },
            CommandItem(title: "Margins: Wide (1.5 inch / 108 pt)", subtitle: "Spacious margins for annotations and notes", icon: "doc.viewfinder", category: .layout, keywords: ["margin", "wide", "spacious"]) {
                documentController.marginPreset = .wide
                showToast("✓ Margins: Wide (108 pt)")
            },
            CommandItem(title: "Toggle Margin Guides", subtitle: "Show or hide canvas guideline borders", icon: "square.dashed", category: .layout, keywords: ["margin", "guides", "rulers", "border"]) {
                showMarginGuides.toggle()
                showToast(showMarginGuides ? "✓ Margin Guides Enabled" : "Margin Guides Hidden")
            },
            CommandItem(title: "Toggle Crop Marks", subtitle: "Display commercial printer alignment crop marks", icon: "crop", category: .layout, keywords: ["crop", "marks", "print", "bleed"]) {
                showCropMarks.toggle()
                showToast(showCropMarks ? "✓ Crop Marks Enabled" : "Crop Marks Hidden")
            },
            CommandItem(title: "Edit Running Header", subtitle: "Customize running header text, dynamic tokens, and alignment", icon: "arrow.up.to.line", category: .layout, shortcut: "⌥⌘H", keywords: ["header", "running header", "title", "top", "token"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    activeHeaderFooterTarget = .header
                    isEditingHeaderFooter = true
                }
            },
            CommandItem(title: "Edit Running Footer", subtitle: "Customize footer content and dynamic page number positioning", icon: "arrow.down.to.line", category: .layout, shortcut: "⌥⌘F", keywords: ["footer", "running footer", "bottom", "page number"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    activeHeaderFooterTarget = .footer
                    isEditingHeaderFooter = true
                }
            },
            CommandItem(title: "Configure Page Numbering", subtitle: "Select numbering format (X of Y, Roman, Page X) and placement", icon: "number.square", category: .layout, keywords: ["page numbers", "numbering", "pagination", "format", "roman", "footer"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    activeHeaderFooterTarget = .footer
                    isEditingHeaderFooter = true
                }
            },
            CommandItem(title: "Toggle Different First Page", subtitle: "Suppress running headers and footers on document title cover", icon: "doc.text", category: .layout, keywords: ["first page", "cover", "title page", "suppress", "header", "footer"]) {
                documentController.headerFooter.differentFirstPage.toggle()
                showToast(documentController.headerFooter.differentFirstPage ? "✓ Different First Page Enabled" : "Different First Page Disabled")
            },

            // === AI Copilot & Intelligent Assistant ===
            CommandItem(title: "Toggle AI Copilot Assistant", subtitle: "Open native BYOK intelligence drawer", icon: "sparkles", category: .ai, shortcut: "⌘J", keywords: ["ai", "copilot", "chat", "assistant"]) {
                showAIDrawer.toggle()
            },
            CommandItem(title: "AI Polish Tone & Academic Flow", subtitle: "Refine phrasing and eliminate passive voice", icon: "wand.and.stars", category: .ai, keywords: ["polish", "academic", "tone", "flow", "refine"]) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showAIDrawer = true }
                showToast("✨ AI Copilot ready to polish")
            },
            CommandItem(title: "AI Instant Translation", subtitle: "Translate selected passage into target language", icon: "translate", category: .ai, keywords: ["translate", "language", "offline", "bilingual"]) {
                Task {
                    if let res = try? await TranslationService.shared.translate(text: selectedText.isEmpty ? documentController.rawText : selectedText) {
                        if !selectedText.isEmpty && selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
                            let ns = documentController.rawText as NSString
                            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: res)
                        }
                        showToast("✓ Translated with Offline Engine")
                    }
                }
            },
            CommandItem(title: "AI Explain Selected Concept", subtitle: "Get an in-depth breakdown of selected text", icon: "brain.head.profile", category: .ai, keywords: ["explain", "understand", "summary", "concept"]) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showAIDrawer = true }
                showToast("✨ AI Copilot explaining selection")
            },
            CommandItem(title: "AI Generate Table of Contents", subtitle: "Analyze document and build hierarchical TOC", icon: "sparkles.rectangle.stack", category: .ai, keywords: ["ai", "toc", "structure", "outline"]) {
                insertTOCAction()
            },

            // === View, Canvas & Tools ===
            CommandItem(title: "Find & Replace", subtitle: "Search for terms across all page sheets", icon: "magnifyingglass", category: .view, shortcut: "⌘F", keywords: ["find", "search", "replace", "locate"]) {
                showFindReplace.toggle()
            },
            CommandItem(title: "Toggle Outline Navigator Drawer", subtitle: "Sidebar table of contents and structure tree", icon: "sidebar.left", category: .view, keywords: ["outline", "sidebar", "navigator", "drawer"]) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showOutlineDrawer.toggle()
                }
            },
            CommandItem(title: "Zoom In (+)", subtitle: "Enlarge workspace canvas scale (+15%)", icon: "plus.magnifyingglass", category: .view, shortcut: "⌘+", keywords: ["zoom", "in", "enlarge", "scale"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = min(2.5, zoomScale + 0.15)
                }
                showToast("✓ Zoom: \(Int(zoomScale * 100))%")
            },
            CommandItem(title: "Zoom Out (-)", subtitle: "Reduce workspace canvas scale (-15%)", icon: "minus.magnifyingglass", category: .view, shortcut: "⌘-", keywords: ["zoom", "out", "shrink", "scale"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = max(0.5, zoomScale - 0.15)
                }
                showToast("✓ Zoom: \(Int(zoomScale * 100))%")
            },
            CommandItem(title: "Reset Zoom (100%)", subtitle: "Set canvas scale to standard 100%", icon: "arrow.counterclockwise", category: .view, shortcut: "⌘0", keywords: ["zoom", "reset", "100", "actual"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = 1.0
                }
                showToast("✓ Zoom: 100%")
            }
        ]
    }

    func buildDocumentAIContext() -> String {
        var context = "=== DOCUMENT METADATA ===\n"
        context += "Title: \(documentController.title)\n"
        context += "Page Format: \(documentController.pageSize.rawValue) (\(Int(currentSheetWidth))x\(Int(currentSheetHeight)) pt)\n"
        context += "Margins: Top \(Int(documentController.margins.top)) pt, Bottom \(Int(documentController.margins.bottom)) pt, Left \(Int(documentController.margins.left)) pt, Right \(Int(documentController.margins.right)) pt\n"
        context += "Word Count: \(wordCount) words, \(characterCount) characters\n\n"

        context += "=== DOCUMENT BODY TEXT ===\n"
        context += documentController.rawText + "\n\n"

        if !documentController.tables.isEmpty {
            context += "=== EMBEDDED SMART TABLES (\(documentController.tables.count)) ===\n"
            for (i, table) in documentController.tables.enumerated() {
                context += "Table \(i + 1):\n"
                context += "| " + table.headers.joined(separator: " | ") + " |\n"
                context += "| " + table.headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
                for row in table.rows {
                    context += "| " + row.joined(separator: " | ") + " |\n"
                }
                context += "\n"
            }
        }

        if !documentController.images.isEmpty {
            context += "=== EMBEDDED FIGURES & IMAGES (\(documentController.images.count)) ===\n"
            for (i, img) in documentController.images.enumerated() {
                context += "Figure \(i + 1): \(img.caption) [Alignment: \(img.alignment.rawValue), Aspect Ratio: \(img.aspectRatioPreset.rawValue)]\n"
            }
            context += "\n"
        }

        if !documentController.videos.isEmpty {
            context += "=== EMBEDDED MEDIA / VIDEOS (\(documentController.videos.count)) ===\n"
            for (i, vid) in documentController.videos.enumerated() {
                context += "Video \(i + 1): \(vid.title) (\(vid.platform.rawValue): \(vid.url))\n"
            }
            context += "\n"
        }

        if !documentController.document.sources.isEmpty {
            context += "=== LINKED BIBLIOGRAPHIC SOURCES (\(documentController.document.sources.count)) ===\n"
            for (id, src) in documentController.document.sources {
                let authorsStr = src.authors.joined(separator: ", ")
                let yearStr = src.year != nil ? String(src.year!) : "n.d."
                context += "[\(id)]: \(authorsStr) (\(yearStr)). \(src.title). [Type: \(src.sourceType.rawValue)]\n"
            }
            context += "\n"
        }

        if !lintIssues.isEmpty {
            context += "=== STYLE & CITATION LINT NOTICES (\(lintIssues.count)) ===\n"
            for issue in lintIssues.prefix(5) {
                let sugg = issue.suggestion ?? "Check rule guideline"
                context += "• [\(issue.ruleId)]: \(issue.message) -> Recommendation: \(sugg)\n"
            }
            context += "\n"
        }

        return context
    }

    func runLinter() {
        guard documentController.styleProfile != "none" else {
            lintIssues = []
            return
        }
        lintIssues = CoreBridge.shared.lint(text: documentController.rawText, profile: documentController.styleProfile)
    }

    // MARK: - Native .letters / .ltt Lossless Package Save & Open
    func saveDocumentAsLetters() {
        let bundle = documentController.createBundle()

        guard let data = try? bundle.encodeToData() else {
            showToast("⚠️ Could not encode .letters bundle")
            return
        }

        // If already associated with a .letters or .ltt file on disk, save in-place immediately
        if let existingURL = documentController.currentFileURL {
            let ext = existingURL.pathExtension.lowercased()
            if ext == "letters" || ext == "ltt" {
                do {
                    try data.write(to: existingURL, options: .atomic)
                    documentController.markSaved(url: existingURL)
                    showToast("✓ Saved \(existingURL.lastPathComponent)")
                    return
                } catch {
                    showToast("⚠️ Failed to save: \(error.localizedDescription)")
                }
            }
        }

        let panel = NSSavePanel()
        panel.title = "Save Project Letters Document"
        panel.nameFieldStringValue = "\(documentController.title.replacingOccurrences(of: " ", with: "_")).letters"
        if let typeLetters = UTType(filenameExtension: "letters"),
           let typeLtt = UTType(filenameExtension: "ltt") {
            panel.allowedContentTypes = [typeLetters, typeLtt]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url, options: .atomic)
                documentController.markSaved(url: url)
                showToast("✓ Saved .letters package: \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write file: \(error.localizedDescription)")
            }
        }
    }

    func restoreAutosaveAction() {
        let shadowURL = LettersDocumentController.autosaveShadowURL
        guard FileManager.default.fileExists(atPath: shadowURL.path) else {
            showToast("⚠️ No autosave recovery snapshot found yet")
            return
        }
        do {
            let data = try Data(contentsOf: shadowURL)
            let bundle = try LettersDocumentBundle.decode(from: data)
            documentController.loadBundle(bundle)
            showToast("✓ Restored last autosave snapshot")
        } catch {
            showToast("⚠️ Failed to restore autosave: \(error.localizedDescription)")
        }
    }

    func extractImagesFromAttributedString(_ inputAttr: NSAttributedString) -> (NSAttributedString, [StudioImageBlock]) {
        let mutable = NSMutableAttributedString(attributedString: inputAttr)
        var extractedImages: [StudioImageBlock] = []
        var attachmentRanges: [(NSRange, StudioImageBlock)] = []

        let fullRange = NSRange(location: 0, length: mutable.length)
        if fullRange.length > 0 {
            mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
                guard let attachment = value as? NSTextAttachment else { return }
                var nsImg: NSImage? = attachment.image
                if nsImg == nil, let fileData = attachment.fileWrapper?.regularFileContents {
                    nsImg = NSImage(data: fileData)
                }
                if nsImg == nil, let contents = attachment.contents {
                    nsImg = NSImage(data: contents)
                }
                guard let validImg = nsImg,
                      let tiff = validImg.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let pngData = rep.representation(using: .png, properties: [:]) else {
                    return
                }
                let base64 = pngData.base64EncodedString()
                let block = StudioImageBlock(
                    base64Data: base64,
                    originalByteSize: pngData.count,
                    compressedByteSize: pngData.count,
                    caption: "Imported Figure \(extractedImages.count + 1)",
                    scaleWidthPercent: 85.0,
                    alignment: .center
                )
                extractedImages.append(block)
                attachmentRanges.append((range, block))
            }
        }

        // Replace attachment characters in reverse order with [[image:UUID]] markers
        for (range, block) in attachmentRanges.reversed() {
            let marker = "\n[[image:\(block.id.uuidString)]]\n"
            mutable.replaceCharacters(in: range, with: marker)
        }

        return (mutable, extractedImages)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.title = "Open Document"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let typeLetters = UTType(filenameExtension: "letters"),
           let typeLtt = UTType(filenameExtension: "ltt"),
           let typeDocx = UTType(filenameExtension: "docx"),
           let typeMd = UTType(filenameExtension: "md"),
           let typeTxt = UTType(filenameExtension: "txt") {
            panel.allowedContentTypes = [typeLetters, typeLtt, typeDocx, typeMd, typeTxt]
        }

        if panel.runModal() == .OK, let url = panel.url {
            openDocumentFromURL(url)
        }
    }

    func openDocumentFromURL(_ url: URL) {
        do {
            let ext = url.pathExtension.lowercased()
            if ext == "letters" || ext == "ltt" {
                let data = try Data(contentsOf: url)
                let bundle = try LettersDocumentBundle.decode(from: data)
                documentController.loadBundle(bundle)
                documentController.markSaved(url: url)
                showToast("✓ Opened .letters document: \(url.lastPathComponent)")
            } else if ext == "md" || ext == "txt" {
                let content = try String(contentsOf: url, encoding: .utf8)
                documentController.title = url.deletingPathExtension().lastPathComponent
                documentController.rawText = content
                documentController.richTextData = nil
                documentController.markSaved(url: url)
                showToast("✓ Opened file: \(url.lastPathComponent)")
            } else if ext == "docx" {
                let rawAttr = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.officeOpenXML], documentAttributes: nil)
                let (attrStr, extractedImages) = extractImagesFromAttributedString(rawAttr)
                documentController.title = url.deletingPathExtension().lastPathComponent
                if !extractedImages.isEmpty {
                    documentController.images.append(contentsOf: extractedImages)
                }
                documentController.rawText = attrStr.string
                if let data = try? NSKeyedArchiver.archivedData(withRootObject: attrStr, requiringSecureCoding: false) {
                    documentController.richTextData = data
                }
                documentController.markSaved(url: url)
                showToast("✓ Opened Word file natively: \(url.lastPathComponent)")
            }
        } catch {
            showToast("⚠️ Could not open document: \(error.localizedDescription)")
        }
    }

    func importWordOrPDF() {
        let panel = NSOpenPanel()
        panel.title = "Import Word or PDF"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let typeDocx = UTType(filenameExtension: "docx"),
           let typePdf = UTType(filenameExtension: "pdf") {
            panel.allowedContentTypes = [typeDocx, typePdf]
        }

        if panel.runModal() == .OK, let url = panel.url {
            importFileNatively(url: url)
        }
    }

    func importFileNatively(url: URL) {
        let ext = url.pathExtension.lowercased()
        do {
            if ext == "docx" {
                    let rawAttr = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.officeOpenXML], documentAttributes: nil)
                    let (attrStr, extractedImages) = extractImagesFromAttributedString(rawAttr)
                    if !extractedImages.isEmpty {
                        documentController.images.append(contentsOf: extractedImages)
                    }
                    
                    let text = attrStr.string
                    var finalAttrStr = attrStr
                    
                    if let oldData = documentController.richTextData, let oldAttr = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: oldData) {
                        let combined = NSMutableAttributedString(attributedString: oldAttr)
                        if selectionRange.location <= combined.length {
                            combined.replaceCharacters(in: selectionRange, with: attrStr)
                        } else {
                            if combined.length > 0 {
                                combined.append(NSAttributedString(string: "\n\n"))
                            }
                            combined.append(attrStr)
                        }
                        finalAttrStr = combined
                    }
                    
                    if let data = try? NSKeyedArchiver.archivedData(withRootObject: finalAttrStr, requiringSecureCoding: false) {
                        documentController.richTextData = data
                    }
                    
                    if selectionRange.location <= (documentController.rawText as NSString).length {
                        let ns = documentController.rawText as NSString
                        documentController.rawText = ns.replacingCharacters(in: selectionRange, with: text)
                    } else {
                        documentController.rawText += (documentController.rawText.isEmpty ? "" : "\n\n") + text
                    }
                    showToast("✓ Imported Word file natively: \(url.lastPathComponent)")
                } else if ext == "md" || ext == "txt" {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    if selectionRange.location <= (documentController.rawText as NSString).length {
                        let ns = documentController.rawText as NSString
                        documentController.rawText = ns.replacingCharacters(in: selectionRange, with: content)
                    } else {
                        documentController.rawText += (documentController.rawText.isEmpty ? "" : "\n\n") + content
                    }
                    showToast("✓ Imported text natively: \(url.lastPathComponent)")
                } else if ext == "pdf" {
                    if let pdf = PDFDocument(url: url), let text = pdf.string {
                        editorController.insertAtCaret(text)
                        showToast("✓ Imported PDF text from: \(url.lastPathComponent)")
                    } else {
                        showToast("⚠️ Could not extract text from PDF")
                    }
                }
            } catch {
                showToast("⚠️ Could not import file: \(error.localizedDescription)")
            }
        }

    // MARK: - Word, PDF & Print
    func buildExpandedMarkdownExport() -> String {
        var text = documentController.rawText
        var referencedTables = Set<UUID>()
        var referencedImages = Set<UUID>()
        var referencedVideos = Set<UUID>()

        for (idx, table) in documentController.tables.enumerated() {
            let marker = "[[table:\(table.id.uuidString)]]"
            let md = "\n\n" + table.toMarkdown() + "\n\n"
            if text.contains(marker) {
                text = text.replacingOccurrences(of: marker, with: md)
                referencedTables.insert(table.id)
            } else if idx == 0 && text.contains("[[table:budget]]") {
                text = text.replacingOccurrences(of: "[[table:budget]]", with: md)
                referencedTables.insert(table.id)
            }
        }

        for image in documentController.images {
            let marker = "[[image:\(image.id.uuidString)]]"
            if text.contains(marker) {
                text = text.replacingOccurrences(of: marker, with: "\n\n" + image.toMarkdown() + "\n\n")
                referencedImages.insert(image.id)
            }
        }

        for video in documentController.videos {
            let marker = "[[video:\(video.id.uuidString)]]"
            if text.contains(marker) {
                text = text.replacingOccurrences(of: marker, with: "\n\n" + video.toMarkdown() + "\n\n")
                referencedVideos.insert(video.id)
            }
        }

        if text.contains("[[toc]]") {
            var tocLines: [String] = ["## Table of Contents"]
            let regex = EditorPerformanceCache.shared.tocHeadingRegex
            let nsText = documentController.rawText as NSString
            var lineStart = 0
            for line in documentController.rawText.components(separatedBy: .newlines) {
                defer { lineStart += (line as NSString).length + 1 }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let pageNum = editorController.pageNumber(forCharacterOffset: min(lineStart, nsText.length))
                if trimmed.hasPrefix("# ") {
                    tocLines.append("- **\(trimmed.dropFirst(2))** (p. \(pageNum))")
                } else if trimmed.hasPrefix("## ") {
                    tocLines.append("  - \(trimmed.dropFirst(3)) (p. \(pageNum))")
                } else if trimmed.hasPrefix("### ") {
                    tocLines.append("    - \(trimmed.dropFirst(4)) (p. \(pageNum))")
                } else {
                    let ns = trimmed as NSString
                    if let m = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: ns.length)), m.range.location != NSNotFound {
                        tocLines.append("- \(trimmed) (p. \(pageNum))")
                    }
                }
            }
            text = text.replacingOccurrences(of: "[[toc]]", with: "\n\n" + tocLines.joined(separator: "\n") + "\n\n")
        }

        if text.contains("[[bibliography]]") {
            let sortedSources = documentController.document.sources.values.sorted {
                ($0.authors.first ?? $0.title).localizedCaseInsensitiveCompare($1.authors.first ?? $1.title) == .orderedAscending
            }
            var bibLines: [String] = ["## References"]
            for source in sortedSources {
                let authors = (source.authors.isEmpty ? [source.title] : source.authors).joined(separator: ", ")
                let yearStr = source.year.map { String($0) } ?? "n.d."
                bibLines.append("- \(authors) (\(yearStr)). *\(source.title)*. [\(source.sourceType.rawValue.capitalized)].")
            }
            text = text.replacingOccurrences(of: "[[bibliography]]", with: "\n\n" + bibLines.joined(separator: "\n") + "\n\n")
        }

        text = text.replacingOccurrences(of: "---pagebreak---", with: "\n\n---\n\n")

        let unrefTables = documentController.tables.filter { !referencedTables.contains($0.id) }
        if !unrefTables.isEmpty {
            text += "\n\n" + unrefTables.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        let unrefImages = documentController.images.filter { !referencedImages.contains($0.id) }
        if !unrefImages.isEmpty {
            text += "\n\n" + unrefImages.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        let unrefVideos = documentController.videos.filter { !referencedVideos.contains($0.id) }
        if !unrefVideos.isEmpty {
            text += "\n\n" + unrefVideos.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !documentController.footnotes.isEmpty {
            var fnLines: [String] = ["### Footnotes"]
            for fn in documentController.footnotes {
                fnLines.append("[\(fn.referenceMarker)] \(fn.text)")
            }
            text += "\n\n" + fnLines.joined(separator: "\n")
        }

        return text
    }

    /// Vector PDF of the live canvas: one page per sheet, with the same fonts, headers and footers
    /// the writer sees (guides and seam labels are suppressed while exporting).
    func renderMultiPagePDFData() -> Data? {
        editorController.flushPendingEdits()
        return editorController.textView?.exportPDFData()
    }

    func buildRichAttributedStringForDocxExport() -> NSAttributedString {
        let baseFont = resolveFontNamed(family: documentController.fontFamily, size: documentController.fontSize, bold: isBold, italic: isItalic)
        let baseParaStyle = NSMutableParagraphStyle()
        switch documentController.textAlignment {
        case .leading: baseParaStyle.alignment = .left
        case .center: baseParaStyle.alignment = .center
        case .trailing: baseParaStyle.alignment = .right
        }
        baseParaStyle.lineHeightMultiple = documentController.lineSpacing
        baseParaStyle.paragraphSpacing = documentController.paragraphSpacing
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .paragraphStyle: baseParaStyle,
            .foregroundColor: NSColor.black
        ]

        let attrStr: NSMutableAttributedString
        if let data = documentController.richTextData,
           let unarchived = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data),
           unarchived.string == documentController.rawText {
            attrStr = NSMutableAttributedString(attributedString: unarchived)
            let fullRange = NSRange(location: 0, length: attrStr.length)
            if fullRange.length > 0 {
                attrStr.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, subRange, _ in
                    let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                    style.lineHeightMultiple = documentController.lineSpacing
                    style.paragraphSpacing = documentController.paragraphSpacing
                    attrStr.addAttribute(.paragraphStyle, value: style, range: subRange)
                }
            }
        } else {
            attrStr = NSMutableAttributedString(string: documentController.rawText, attributes: defaultAttrs)
        }

        func replaceMarker(_ marker: String, with replacement: String) {
            while true {
                let range = (attrStr.string as NSString).range(of: marker)
                if range.location == NSNotFound { break }
                let existingAttrs = range.location < attrStr.length
                    ? attrStr.attributes(at: range.location, effectiveRange: nil)
                    : defaultAttrs
                let repAttr = NSAttributedString(string: replacement, attributes: existingAttrs)
                attrStr.replaceCharacters(in: range, with: repAttr)
            }
        }

        func replaceMarkerWithAttributed(_ marker: String, with replacement: NSAttributedString) {
            while true {
                let range = (attrStr.string as NSString).range(of: marker)
                if range.location == NSNotFound { break }
                attrStr.replaceCharacters(in: range, with: replacement)
            }
        }

        for (idx, table) in documentController.tables.enumerated() {
            let marker = "[[table:\(table.id.uuidString)]]"
            let tableAttr = buildNativeTextTableAttributedString(from: table, baseFont: baseFont)
            replaceMarkerWithAttributed(marker, with: tableAttr)
            if idx == 0 {
                replaceMarkerWithAttributed("[[table:budget]]", with: tableAttr)
            }
        }
        for image in documentController.images {
            let marker = "[[image:\(image.id.uuidString)]]"
            if let data = Data(base64Encoded: image.base64Data),
               let nsImg = NSImage(data: data) {
                let attachment = NSTextAttachment()
                attachment.image = nsImg
                let imgAttr = NSMutableAttributedString(string: "\n")
                imgAttr.append(NSAttributedString(attachment: attachment))
                if !image.caption.isEmpty {
                    let capStyle = NSMutableParagraphStyle()
                    capStyle.alignment = .center
                    let capFont = resolveFontNamed(family: documentController.fontFamily, size: 11, bold: false, italic: true)
                    imgAttr.append(NSAttributedString(string: "\n\(image.caption)\n", attributes: [
                        .font: capFont,
                        .paragraphStyle: capStyle,
                        .foregroundColor: NSColor.darkGray
                    ]))
                } else {
                    imgAttr.append(NSAttributedString(string: "\n"))
                }
                replaceMarkerWithAttributed(marker, with: imgAttr)
            } else {
                replaceMarker(marker, with: "\n\n" + image.toMarkdown() + "\n\n")
            }
        }
        for video in documentController.videos {
            replaceMarker("[[video:\(video.id.uuidString)]]", with: "\n\n" + video.toMarkdown() + "\n\n")
        }
        replaceMarker("---pagebreak---", with: "\n\u{000C}\n")

        return attrStr
    }

    func buildNativeTextTableAttributedString(from tableData: StudioTableData, baseFont: NSFont) -> NSAttributedString {
        let numCols = max(1, tableData.headers.count)
        let textTable = NSTextTable()
        textTable.numberOfColumns = numCols
        textTable.collapsesBorders = true
        textTable.hidesEmptyCells = false

        let result = NSMutableAttributedString(string: "\n", attributes: [.font: baseFont])
        let headerFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)

        func appendCell(text: String, row: Int, col: Int, isHeader: Bool) {
            let block = NSTextTableBlock(table: textTable, startingRow: row, rowSpan: 1, startingColumn: col, columnSpan: 1)
            block.setWidth(1.0, type: .absoluteValueType, for: .border)
            block.setBorderColor(NSColor.gray.withAlphaComponent(0.5))
            block.setWidth(4.0, type: .absoluteValueType, for: .padding)
            if isHeader {
                block.backgroundColor = NSColor(white: 0.94, alpha: 1.0)
            }
            let paraStyle = NSMutableParagraphStyle()
            paraStyle.textBlocks = [block]
            let cellStr = (text.isEmpty ? " " : text) + "\n"
            let cellAttr = NSAttributedString(string: cellStr, attributes: [
                .font: isHeader ? headerFont : baseFont,
                .paragraphStyle: paraStyle,
                .foregroundColor: NSColor.black
            ])
            result.append(cellAttr)
        }

        for col in 0..<numCols {
            let hText = col < tableData.headers.count ? tableData.headers[col] : ""
            appendCell(text: hText, row: 0, col: col, isHeader: true)
        }

        for (rIdx, row) in tableData.rows.enumerated() {
            for col in 0..<numCols {
                let evaluated = tableData.evaluatedCell(row: rIdx + 1, col: col)
                let fallback = col < row.count ? row[col] : ""
                let cellText = evaluated.isEmpty ? fallback : evaluated
                appendCell(text: cellText, row: rIdx + 1, col: col, isHeader: false)
            }
        }

        result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
        return result
    }

    func saveDocumentAsDocx() {
        let richAttr = buildRichAttributedStringForDocxExport()
        let fullRange = NSRange(location: 0, length: richAttr.length)

        var exportedData: Data? = nil
        if fullRange.length > 0 {
            exportedData = try? richAttr.data(
                from: fullRange,
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.officeOpenXML,
                    .title: documentController.title
                ]
            )
        }
        if exportedData == nil {
            let fullExport = buildExpandedMarkdownExport()
            exportedData = CoreBridge.shared.exportDocx(title: documentController.title, text: fullExport)
        }

        guard let docxData = exportedData else {
            showToast("⚠️ Could not generate DOCX")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Word Document"
        panel.nameFieldStringValue = "\(documentController.title.replacingOccurrences(of: " ", with: "_")).docx"
        if let type = UTType(filenameExtension: "docx") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try docxData.write(to: url)
                showToast("✓ Saved \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write file: \(error.localizedDescription)")
            }
        }
    }

    func exportDocumentAsPDF() {
        let panel = NSSavePanel()
        panel.title = "Export Vector PDF"
        panel.nameFieldStringValue = "\(documentController.title.replacingOccurrences(of: " ", with: "_")).pdf"
        if let type = UTType(filenameExtension: "pdf") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            guard let pdfData = renderMultiPagePDFData() else {
                showToast("⚠️ Could not render PDF")
                return
            }

            do {
                try pdfData.write(to: url)
                showToast("✓ Exported Vector PDF (\(editorController.pageCount) pages): \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write PDF: \(error.localizedDescription)")
            }
        }
    }

    func printDocument() {
        let paperSize = NSSize(width: currentSheetWidth, height: currentSheetHeight)
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = paperSize
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.orientation = .portrait

        if let pdfData = renderMultiPagePDFData(),
           let pdfDoc = PDFDocument(data: pdfData),
           let op = pdfDoc.printOperation(for: printInfo, scalingMode: .pageScaleNone, autoRotate: false) {
            op.showsPrintPanel = true
            op.run()
            return
        }

        let textView = NSTextView(frame: NSRect(origin: .zero, size: paperSize))
        textView.string = documentController.rawText
        textView.font = resolveFontNamed(family: documentController.fontFamily, size: documentController.fontSize, bold: isBold, italic: isItalic)

        let op = NSPrintOperation(view: textView, printInfo: printInfo)
        op.showsPrintPanel = true
        op.run()
    }

    func saveDocumentAsMarkdown() {
        let fullExport = buildExpandedMarkdownExport()

        let panel = NSSavePanel()
        panel.title = "Save Markdown"
        panel.nameFieldStringValue = "\(documentController.title.replacingOccurrences(of: " ", with: "_")).md"
        if let type = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try fullExport.write(to: url, atomically: true, encoding: .utf8)
                showToast("✓ Saved \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write file: \(error.localizedDescription)")
            }
        }
    }

    /// Shows a transient confirmation using the new ToastManager (Sonner-style).
    func showToast(_ rawMessage: String) {
        var msg = rawMessage
        let isWarning = msg.hasPrefix("⚠️")
        for prefix in ["✓ ", "⚠️ ", "✨ ", "💬 ", "📊 "] where msg.hasPrefix(prefix) {
            msg.removeFirst(prefix.count)
            break
        }
        if isWarning {
            toastManager.show(.warning(msg))
        } else {
            toastManager.show(.success(msg))
        }
    }

    func marginCommentCard(sn: StudioSideNote) -> some View {
        let binding = Binding(
            get: { sn.text },
            set: { newText in
                if let idx = documentController.sideNotes.firstIndex(where: { $0.id == sn.id }) {
                    documentController.sideNotes[idx].text = newText
                }
            }
        )

        return VStack(alignment: .leading, spacing: 4) {
            // Header: Author & Action Buttons
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(sn.isResolved ? Color.gray.opacity(0.3) : Color.accentColor.opacity(0.2))
                        .frame(width: 15, height: 15)
                    Text(String(sn.author.prefix(1)).uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(sn.isResolved ? .secondary : .accentColor)
                }

                Text(sn.author)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(sn.isResolved ? .secondary : .primary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                // Resolve toggle button
                Button(action: {
                    if let idx = documentController.sideNotes.firstIndex(where: { $0.id == sn.id }) {
                        documentController.sideNotes[idx].isResolved.toggle()
                        showToast(documentController.sideNotes[idx].isResolved ? "✓ Resolved comment" : "✓ Reopened comment")
                    }
                }) {
                    Image(systemName: sn.isResolved ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(sn.isResolved ? .green : .secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(sn.isResolved ? "Reopen comment" : "Mark as resolved")

                // Delete button
                Button(action: {
                    documentController.sideNotes.removeAll(where: { $0.id == sn.id })
                    showToast("✓ Deleted comment")
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete comment")
            }

            // Quoted Anchor Text Excerpt
            if let anchor = sn.anchorText, !anchor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Capsule()
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: 2.5, height: 14)
                    Text("\"\(anchor)\"")
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .italic()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.06))
                .cornerRadius(3)
            }

            // Comment text editor
            NativeFootnoteField(
                text: binding,
                placeholder: "Add a comment...",
                font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                textColor: sn.isResolved ? .secondaryLabelColor : .labelColor
            )
            .frame(minHeight: 20)
            .opacity(sn.isResolved ? 0.6 : 1.0)

            if sn.isResolved {
                Text("RESOLVED")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(2)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    hoveredCommentId == sn.id
                        ? Color.orange
                        : (sn.isResolved ? Color.secondary.opacity(0.2) : Color.accentColor.opacity(0.3)),
                    lineWidth: hoveredCommentId == sn.id ? 1.6 : 0.8
                )
        )
        .shadow(
            color: hoveredCommentId == sn.id ? Color.orange.opacity(0.25) : Color.black.opacity(0.06),
            radius: hoveredCommentId == sn.id ? 5 : 3,
            x: 0,
            y: 1.5
        )
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredCommentId = isHovered ? sn.id : nil
            }
        }
    }

    func onPaperRevisionCard(rev: StudioTrackedRevision) -> some View {
        let isInsertion = rev.kind == .insertion
        let accentColor = isInsertion ? Color.green : Color.red

        return VStack(alignment: .leading, spacing: 4) {
            // Header: Author + Action icon + 1-Click Accept / Reject
            HStack(spacing: 4) {
                Image(systemName: isInsertion ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(accentColor)

                Text(rev.author)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                // 1-Click Accept Button on Paper
                Button(action: {
                    documentController.acceptRevision(id: rev.id)
                    showToast("✓ Accepted change on paper")
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .buttonStyle(.plain)
                .help("Accept change (Keep this edit)")

                // 1-Click Reject Button on Paper
                Button(action: {
                    documentController.rejectRevision(id: rev.id)
                    showToast("✓ Rejected change on paper")
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 18, height: 18)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
                .help("Reject change (Revert this edit)")
            }

            // Body text
            if !isInsertion, let orig = rev.originalText ?? (rev.text.isEmpty ? nil : rev.text) {
                Text(orig)
                    .font(.system(size: 9))
                    .strikethrough()
                    .foregroundColor(.red.opacity(0.85))
                    .lineLimit(3)
            } else {
                Text(rev.text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.green.opacity(0.9))
                    .lineLimit(3)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(accentColor.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1.5)
    }

    var reviewToolbarStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(documentController.isTrackChangesEnabled ? Color.orange : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(documentController.isTrackChangesEnabled ? "Track Changes ON" : "Review Mode")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(documentController.isTrackChangesEnabled ? .orange : .secondary)

                if !documentController.revisions.isEmpty {
                    Text("(\(documentController.revisions.count) changes)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !documentController.revisions.isEmpty {
                Button(action: { showRevisionsPopover.toggle() }) {
                    Label("Review Changes", systemImage: "list.bullet.rectangle")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showRevisionsPopover, arrowEdge: .bottom) {
                    revisionsPopoverContent
                }

                Button(action: {
                    documentController.acceptAllRevisions()
                    showToast("✓ Accepted all changes")
                }) {
                    Label("Accept All", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    documentController.rejectAllRevisions()
                    showToast("✓ Rejected all changes")
                }) {
                    Label("Reject All", systemImage: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button(action: { insertSideNote() }) {
                Label("Add Comment", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    documentController.isTrackChangesEnabled.toggle()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close Review Bar")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.2)),
            alignment: .bottom
        )
    }

    var revisionsPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "pencil.and.outline")
                    .foregroundColor(.orange)
                Text("Tracked Changes (\(documentController.revisions.count))")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
            }
            Divider()

            if documentController.revisions.isEmpty {
                Text("No pending revisions.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(documentController.revisions) { rev in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: rev.kind == .insertion ? "plus.circle.fill" : "minus.circle.fill")
                                        .foregroundColor(rev.kind == .insertion ? .green : .red)
                                        .font(.system(size: 11))
                                    Text("\(rev.author) • \(rev.kind.rawValue.capitalized)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(action: {
                                        documentController.acceptRevision(id: rev.id)
                                        showToast("✓ Accepted change")
                                    }) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.green)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Accept Change")

                                    Button(action: {
                                        documentController.rejectRevision(id: rev.id)
                                        showToast("✓ Rejected change")
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Reject Change")
                                }

                                if let orig = rev.originalText, !orig.isEmpty {
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("Was:")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text(orig)
                                            .font(.system(size: 10))
                                            .strikethrough()
                                            .foregroundColor(.red.opacity(0.8))
                                            .lineLimit(2)
                                    }
                                }

                                HStack(alignment: .top, spacing: 4) {
                                    Text("Now:")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(rev.text)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(rev.kind == .insertion ? .green : .primary)
                                        .lineLimit(3)
                                }
                            }
                            .padding(8)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.trailing, 16)
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    var pasteSpecialSheetView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paste Special")
                        .font(.headline)
                    Text("Choose how clipboard content should be inserted into your document.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(PasteSpecialMode.allCases) { mode in
                    Button(action: { selectedPasteMode = mode }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selectedPasteMode == mode ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(selectedPasteMode == mode ? .accentColor : .secondary)
                                .font(.system(size: 14))
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(mode.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedPasteMode == mode ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.02))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedPasteMode == mode ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button("Cancel") {
                    showingPasteSpecialSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Paste") {
                    editorController.pasteSpecial(mode: selectedPasteMode)
                    showingPasteSpecialSheet = false
                    showToast("✓ Pasted (\(selectedPasteMode.rawValue))")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    var headerFooterToolbarStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: activeHeaderFooterTarget == .header ? "arrow.up.to.line" : "arrow.down.to.line")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("Editing \(activeHeaderFooterTarget.rawValue)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            // Custom Compact Switcher (Header vs Footer)
            HStack(spacing: 1) {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        activeHeaderFooterTarget = .header
                    }
                } label: {
                    Text("Header")
                        .font(.system(size: 10, weight: activeHeaderFooterTarget == .header ? .bold : .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            activeHeaderFooterTarget == .header ? Color.accentColor.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .foregroundColor(activeHeaderFooterTarget == .header ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        activeHeaderFooterTarget = .footer
                    }
                } label: {
                    Text("Footer")
                        .font(.system(size: 10, weight: activeHeaderFooterTarget == .footer ? .bold : .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            activeHeaderFooterTarget == .footer ? Color.accentColor.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .foregroundColor(activeHeaderFooterTarget == .footer ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))

            Divider().frame(height: 14)

            // Page Number Position Picker Menu
            Menu {
                ForEach(PageNumberPosition.allCases, id: \.self) { pos in
                    Button(pos.rawValue) {
                        documentController.headerFooter.pageNumberPosition = pos
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "number.square")
                        .font(.system(size: 9))
                    Text(documentController.headerFooter.pageNumberPosition.rawValue)
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Page Number Placement")

            // Page Number Format Picker Menu
            Menu {
                ForEach(PageNumberFormat.allCases, id: \.self) { fmt in
                    Button(fmt.rawValue) {
                        documentController.headerFooter.pageNumberFormat = fmt
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(documentController.headerFooter.pageNumberFormat.rawValue)
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Page Number Format Style")

            // Starting Page Stepper
            HStack(spacing: 2) {
                Text("Start:")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)

                Button {
                    if documentController.headerFooter.startingPageNumber > 0 {
                        documentController.headerFooter.startingPageNumber -= 1
                    }
                } label: {
                    Text("−")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 12, height: 14)
                }
                .buttonStyle(.plain)

                Text("\(documentController.headerFooter.startingPageNumber)")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16)

                Button {
                    documentController.headerFooter.startingPageNumber += 1
                } label: {
                    Text("+")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 12, height: 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
            .help("Starting Page Number (Offset)")

            Divider().frame(height: 14)

            // Different First Page Checkbox
            Toggle(isOn: $documentController.headerFooter.differentFirstPage) {
                Text("Different First Page")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.checkbox)
            .help("Hide header and footer on the title / cover page")

            Divider().frame(height: 14)

            // Insert Token Field Menu
            Menu {
                Button("Insert {page} (Current Page)") { appendHeaderFooterToken("{page}") }
                Button("Insert {pages} (Total Pages)") { appendHeaderFooterToken("{pages}") }
                Button("Insert {title} (Document Title)") { appendHeaderFooterToken("{title}") }
                Button("Insert {date} (Current Date)") { appendHeaderFooterToken("{date}") }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus.circle")
                    Text("Insert Field")
                }
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Close / Done Button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isEditingHeaderFooter = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Done")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Close Header & Footer Editor (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .bottom
        )
    }

    func appendHeaderFooterToken(_ token: String) {
        if activeHeaderFooterTarget == .header {
            documentController.headerFooter.headerRightText += (documentController.headerFooter.headerRightText.isEmpty ? "" : " ") + token
        } else {
            documentController.headerFooter.footerRightText += (documentController.headerFooter.footerRightText.isEmpty ? "" : " ") + token
        }
    }

    func figureNumber(for imgId: UUID) -> Int {
        (documentController.images.firstIndex(where: { $0.id == imgId }) ?? 0) + 1
    }

    func replaceSelection(with newText: String) {
        if documentController.isTrackChangesEnabled {
            documentController.recordRevision(
                kind: .insertion,
                text: newText,
                originalText: selectedText.isEmpty ? nil : selectedText,
                author: "AI Copilot"
            )
        }
        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: newText)
        } else if !selectedText.isEmpty && documentController.rawText.contains(selectedText) {
            documentController.rawText = documentController.rawText.replacingOccurrences(of: selectedText, with: newText)
        } else {
            documentController.rawText += "\n\n" + newText
        }
        selectedText = ""
        selectionRange = NSRange(location: 0, length: 0)
        showToast("✓ Applied AI changes to canvas")
    }

    func insertBelowSelection(newText: String) {
        if documentController.isTrackChangesEnabled {
            documentController.recordRevision(
                kind: .insertion,
                text: newText,
                originalText: nil,
                author: "AI Copilot"
            )
        }
        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            let insertPos = selectionRange.location + selectionRange.length
            let head = ns.substring(to: insertPos)
            let tail = ns.substring(from: insertPos)
            documentController.rawText = head + "\n\n" + newText + tail
        } else if !selectedText.isEmpty, let range = documentController.rawText.range(of: selectedText) {
            documentController.rawText.insert(contentsOf: "\n\n" + newText, at: range.upperBound)
        } else {
            documentController.rawText += "\n\n" + newText
        }
        selectedText = ""
        selectionRange = NSRange(location: 0, length: 0)
        showToast("✓ Inserted AI content below selection")
    }

    func applyLintFix(_ issue: StyleLintMatch) {
        guard let suggestion = issue.suggestion, !suggestion.isEmpty else { return }
        let ns = documentController.rawText as NSString
        guard issue.spanStart >= 0, issue.spanEnd <= ns.length, issue.spanStart <= issue.spanEnd else { return }
        let range = NSRange(location: issue.spanStart, length: issue.spanEnd - issue.spanStart)
        let oldSnippet = ns.substring(with: range)
        if documentController.isTrackChangesEnabled {
            documentController.recordRevision(
                kind: .insertion,
                text: suggestion,
                originalText: oldSnippet,
                author: "Style Linter"
            )
        }

        // Update richTextData synchronously so formatting is never lost across the document
        if let data = documentController.richTextData,
           let richDoc = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data),
           richDoc.length == ns.length {
            let mutableRich = NSMutableAttributedString(attributedString: richDoc)
            let existingAttrs = range.length > 0 ? richDoc.attributes(at: range.location, effectiveRange: nil) : [:]
            let replacementAttrStr = NSAttributedString(string: suggestion, attributes: existingAttrs)
            mutableRich.replaceCharacters(in: range, with: replacementAttrStr)
            if let updatedData = try? NSKeyedArchiver.archivedData(withRootObject: mutableRich, requiringSecureCoding: false) {
                documentController.richTextData = updatedData
            }
        }

        let replaced = ns.replacingCharacters(in: range, with: suggestion)
        documentController.rawText = replaced
        documentController.commitSnapshot(actionName: "Apply Fix: \(issue.ruleId)", isMilestone: false)
        runLinter()
        showToast("✓ Applied fix: \(suggestion)")
    }
}

// MARK: - Visual Publishing Guides & Interactive Horizontal Ruler
struct StudioHorizontalRulerView: View {
    let sheetWidth: CGFloat
    var zoomScale: CGFloat = 1.0
    @Binding var margins: PageMargins
    @Binding var hangingIndent: CGFloat
    var onMarginChanged: () -> Void = {}

    @AppStorage("letters_ruler_unit") private var rulerUnitString: String = "in"

    @State private var leftDragStart: CGFloat? = nil
    @State private var rightDragStart: CGFloat? = nil
    @State private var indentDragStart: CGFloat? = nil

    var isMetric: Bool {
        rulerUnitString == "cm"
    }

    // Conversion: 72 pt = 1 inch, 28.3464567 pt = 1 cm
    var ptPerUnit: CGFloat {
        isMetric ? 28.3464567 : 72.0
    }

    var subdivisions: Int {
        isMetric ? 2 : 4 // cm: 0.5 cm ticks; in: 1/4 in ticks
    }

    var minorStep: CGFloat {
        ptPerUnit / CGFloat(subdivisions)
    }

    func snapCoordinate(_ val: CGFloat, isShift: Bool) -> CGFloat {
        if isShift {
            // Snaps to exact whole unit (1.0 in or 1.0 cm)
            return round(val / ptPerUnit) * ptPerUnit
        }
        let nearestTick = round(val / minorStep) * minorStep
        if abs(val - nearestTick) < 5.0 {
            return nearestTick
        }
        return round(val)
    }

    func formatUnit(_ pt: CGFloat) -> String {
        if isMetric {
            let cm = Double(pt) / 28.3464567
            return String(format: "%.1f cm", cm)
        } else {
            let inch = Double(pt) / 72.0
            return String(format: "%.2f\"", inch)
        }
    }

    var body: some View {
        let effectiveWidth = sheetWidth * zoomScale
        let scaledLeftMargin = margins.left * zoomScale
        let scaledRightMargin = margins.right * zoomScale
        let rightHandleX = effectiveWidth - scaledRightMargin

        ZStack(alignment: .topLeading) {
            // 1. Single Pixel-Aligned High-DPI CoreGraphics Canvas
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // Transparent ruler track background with crisp 1px borders
                let trackRect = CGRect(x: 0, y: 0, width: w, height: h)
                context.fill(Path(trackRect), with: .color(Color(nsColor: .windowBackgroundColor).opacity(0.35)))

                let topPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: 0.5))
                    p.addLine(to: CGPoint(x: w, y: 0.5))
                }
                let bottomPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: h - 0.5))
                    p.addLine(to: CGPoint(x: w, y: h - 0.5))
                }
                context.stroke(topPath, with: .color(Color.primary.opacity(0.12)), lineWidth: 1)
                context.stroke(bottomPath, with: .color(Color.primary.opacity(0.12)), lineWidth: 1)

                // Transparent Active Printable Column with subtle accent tint (Never solid white)
                let activeLeft = floor(scaledLeftMargin) + 0.5
                let activeRight = floor(rightHandleX) + 0.5
                if activeRight > activeLeft {
                    let activeRect = CGRect(x: activeLeft, y: 1, width: activeRight - activeLeft, height: h - 2)
                    context.fill(Path(activeRect), with: .color(Color.accentColor.opacity(0.04)))

                    // Left & Right boundary guidelines
                    let leftLine = Path { p in
                        p.move(to: CGPoint(x: activeLeft, y: 0))
                        p.addLine(to: CGPoint(x: activeLeft, y: h))
                    }
                    let rightLine = Path { p in
                        p.move(to: CGPoint(x: activeRight, y: 0))
                        p.addLine(to: CGPoint(x: activeRight, y: h))
                    }
                    context.stroke(leftLine, with: .color(Color.accentColor.opacity(0.5)), lineWidth: 1)
                    context.stroke(rightLine, with: .color(Color.accentColor.opacity(0.5)), lineWidth: 1)
                }

                // Ticks & Numbers drawing
                let totalSteps = Int(ceil(sheetWidth / minorStep))
                for step in 0...totalSteps {
                    let rawX = CGFloat(step) * minorStep * zoomScale
                    if rawX > w { break }
                    let x = floor(rawX) + 0.5
                    let isMajor = (step % subdivisions == 0)
                    let isHalf = isMetric ? false : (step % 2 == 0)
                    let tickH: CGFloat = isMajor ? 7.5 : (isHalf ? 5.0 : 3.0)

                    let tickPath = Path { p in
                        p.move(to: CGPoint(x: x, y: h - tickH))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }
                    context.stroke(tickPath, with: .color(Color(nsColor: .labelColor).opacity(isMajor ? 0.75 : 0.35)), lineWidth: 1)

                    if isMajor && step > 0 {
                        let unitValue = step / subdivisions
                        let labelText = Text("\(unitValue)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(nsColor: .labelColor))
                        context.draw(labelText, at: CGPoint(x: x, y: 8), anchor: .center)
                    }
                }
            }
            .frame(width: effectiveWidth, height: 26)

            // Unit Switcher Tag (Click to toggle in / cm)
            Button {
                rulerUnitString = isMetric ? "in" : "cm"
            } label: {
                Text(isMetric ? "cm" : "in")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
            }
            .buttonStyle(.plain)
            .position(x: min(effectiveWidth - 14, effectiveWidth - scaledRightMargin / 2), y: 8)
            .help("Click to switch ruler units (Inches / Centimeters)")

            // 3. Hanging / First-Line Indent Handle (Top downward triangle at y: 5)
            let indentX = (margins.left + hangingIndent) * zoomScale
            ZStack {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color.orange.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .position(x: indentX, y: 5)
            .help("First Line / Hanging Indent: \(formatUnit(hangingIndent)) (\(Int(hangingIndent)) pt) • Hold ⇧ to snap to 1 \(isMetric ? "cm" : "inch")")
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if indentDragStart == nil { indentDragStart = hangingIndent }
                        let base = indentDragStart ?? hangingIndent
                        let deltaDoc = value.translation.width / zoomScale
                        let proposedX = margins.left + base + deltaDoc
                        let isShift = NSEvent.modifierFlags.contains(.shift)
                        let snappedX = snapCoordinate(proposedX, isShift: isShift)
                        hangingIndent = max(0, min(144, snappedX - margins.left))
                    }
                    .onEnded { _ in
                        indentDragStart = nil
                    }
            )

            // 4. Left Margin Draggable Handle (Bottom upward triangle at y: 20)
            ZStack {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 8.5))
                    .foregroundColor(.accentColor)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .position(x: scaledLeftMargin, y: 20)
            .help("Left Margin: \(formatUnit(margins.left)) (\(Int(margins.left)) pt) • Hold ⇧ to snap to 1 \(isMetric ? "cm" : "inch")")
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if leftDragStart == nil { leftDragStart = margins.left }
                        let base = leftDragStart ?? margins.left
                        let deltaDoc = value.translation.width / zoomScale
                        let proposed = min(max(18, base + deltaDoc), sheetWidth - margins.right - 72)
                        let isShift = NSEvent.modifierFlags.contains(.shift)
                        margins.left = snapCoordinate(proposed, isShift: isShift)
                        onMarginChanged()
                    }
                    .onEnded { _ in
                        leftDragStart = nil
                    }
            )

            // 5. Right Margin Draggable Handle (Bottom upward triangle at y: 20)
            ZStack {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 8.5))
                    .foregroundColor(.accentColor)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0.5)
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .position(x: rightHandleX, y: 20)
            .help("Right Margin: \(formatUnit(margins.right)) (\(Int(margins.right)) pt) • Hold ⇧ to snap to 1 \(isMetric ? "cm" : "inch")")
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if rightDragStart == nil { rightDragStart = margins.right }
                        let base = rightDragStart ?? margins.right
                        let deltaDoc = value.translation.width / zoomScale
                        let proposedX = sheetWidth - (base - deltaDoc)
                        let isShift = NSEvent.modifierFlags.contains(.shift)
                        let snappedX = snapCoordinate(proposedX, isShift: isShift)
                        margins.right = max(18, min(sheetWidth - margins.left - 72, sheetWidth - snappedX))
                        onMarginChanged()
                    }
                    .onEnded { _ in
                        rightDragStart = nil
                    }
            )
        }
        .frame(width: effectiveWidth, height: 26, alignment: .topLeading)
    }
}

struct EditorFileNotificationsModifier: ViewModifier {
    let onNew: () -> Void
    let onOpen: () -> Void
    let onRestoreAutosave: () -> Void
    let onImportWordOrPDF: () -> Void
    let onSave: () -> Void
    let onExportDocx: () -> Void
    let onExportPDF: () -> Void
    let onExportMarkdown: () -> Void
    let onPrint: () -> Void
    let onSettings: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .lettersNewDocument)) { _ in onNew() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersOpenDocument)) { _ in onOpen() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersRestoreAutosave)) { _ in onRestoreAutosave() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersImportWordOrPDF)) { _ in onImportWordOrPDF() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersSaveDocument)) { _ in onSave() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersExportDocx)) { _ in onExportDocx() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersExportPDF)) { _ in onExportPDF() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersExportMarkdown)) { _ in onExportMarkdown() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersPrintDocument)) { _ in onPrint() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersOpenSettings)) { _ in onSettings() }
    }
}

struct EditorFormatNotificationsModifier: ViewModifier {
    let onBold: () -> Void
    let onItalic: () -> Void
    let onUnderline: () -> Void
    let onAlignLeft: () -> Void
    let onAlignCenter: () -> Void
    let onAlignRight: () -> Void
    let onTable: () -> Void
    let onImage: () -> Void
    let onVideo: () -> Void
    let onCitation: () -> Void
    let onFootnote: () -> Void
    let onSideNote: () -> Void
    let onTOC: () -> Void
    let onBibliography: () -> Void
    let onPageBreak: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleBold)) { _ in onBold() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleItalic)) { _ in onItalic() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleUnderline)) { _ in onUnderline() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersAlignLeft)) { _ in onAlignLeft() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersAlignCenter)) { _ in onAlignCenter() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersAlignRight)) { _ in onAlignRight() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertTable)) { _ in onTable() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertImage)) { _ in onImage() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertVideo)) { _ in onVideo() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertCitation)) { _ in onCitation() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertFootnote)) { _ in onFootnote() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertSideNote)) { _ in onSideNote() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertTOC)) { _ in onTOC() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertBibliography)) { _ in onBibliography() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertPageBreak)) { _ in onPageBreak() }
    }
}

struct EditorViewNotificationsModifier: ViewModifier {
    let onFindReplace: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomReset: () -> Void
    let onToggleRuler: () -> Void
    let onOutline: () -> Void
    let onAIDrawer: () -> Void
    let onPageDesign: () -> Void
    let onDocumentHistory: () -> Void
    let onCommandPalette: () -> Void
    var onToggleTrackChanges: () -> Void = {}
    var onPasteAndMatchStyle: () -> Void = {}
    var onPasteSpecial: () -> Void = {}

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleFindReplace)) { _ in onFindReplace() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersZoomIn)) { _ in onZoomIn() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersZoomOut)) { _ in onZoomOut() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersZoomReset)) { _ in onZoomReset() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleRuler)) { _ in onToggleRuler() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleOutline)) { _ in onOutline() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleAIDrawer)) { _ in onAIDrawer() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersTogglePageDesign)) { _ in onPageDesign() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleDocumentHistory)) { _ in onDocumentHistory() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleCommandPalette)) { _ in onCommandPalette() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleTrackChanges)) { _ in onToggleTrackChanges() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersPasteAndMatchStyle)) { _ in onPasteAndMatchStyle() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersPasteSpecial)) { _ in onPasteSpecial() }
    }
}


@MainActor








enum SnapshotActor: String, Codable, Equatable, Sendable {
    case user
    case ai
}

public struct HistoryNode: Identifiable, Equatable {
    public let id: UUID
    public let parentId: UUID?
    let timestamp: Date
    var actionName: String
    var diffSummary: String?
    let actor: SnapshotActor
    var isMilestone: Bool
    var isPinned: Bool
    var customName: String?
    let bundle: LettersDocumentBundle

    nonisolated public static func == (lhs: HistoryNode, rhs: HistoryNode) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
public class LettersDocumentController: ObservableObject {
    public static weak var active: LettersDocumentController?
    @Published public var title: String
    @Published public var rawText: String
    @Published public var richTextData: Data?
    
    @Published public var document: DocumentModel
    @Published public var tables: [StudioTableData]
    @Published public var images: [StudioImageBlock]
    @Published public var videos: [StudioVideoBlock]
    @Published public var floatingElements: [StudioFloatingElement]
    @Published public var footnotes: [StudioFootnote]
    @Published public var sideNotes: [StudioSideNote]
    @Published public var citationStyle: CitationStyle
    
    @Published public var pageSize: PageSizePreset
    @Published public var marginPreset: MarginPreset
    @Published public var margins: PageMargins
    @Published public var coverBanner: CoverBannerConfig
    @Published public var headerFooter: HeaderFooterConfig
    @Published public var isTrackChangesEnabled: Bool
    @Published public var revisions: [StudioTrackedRevision]
    @Published public var styleProfile: String = "none"
    
    @Published public var fontFamily: String
    @Published public var fontSize: CGFloat
    @Published public var lineSpacing: CGFloat
    @Published public var paragraphSpacing: CGFloat
    @Published public var textAlignment: TextAlignment
    @Published public var columnCount: Int
    @Published public var showLineNumbers: Bool
    @Published public var watermarkText: String
    @Published public var kern: CGFloat
    @Published public var hangingIndent: CGFloat
    
    // MARK: - DAG Time Travel Engine & Document Lifecycle
    @Published public var historyNodes: [UUID: HistoryNode] = [:]
    @Published public var currentSnapshotId: UUID? = nil
    @Published public var mainBranchHeadId: UUID? = nil
    @Published public var isPeeking: Bool = false
    @Published public var currentFileURL: URL? = nil
    @Published public var isDirty: Bool = false {
        didSet {
            NSApp.windows.first?.isDocumentEdited = isDirty
        }
    }
    @Published public var lastAutosaveDate: Date? = nil
    
    /// Installed by the canvas: archives the live text view into `richTextData` before the model is read.
    var flushEditor: (() -> Void)?

    var isReverting: Bool = false
    var cancellables = Set<AnyCancellable>()
    var backupBundleForPeek: LettersDocumentBundle? = nil
    
    public static var autosaveShadowURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = appSupport.appendingPathComponent("ProjectLetters", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("AutosaveRecovery.letters")
    }

    func performAutosave() {
        guard !isReverting, !isPeeking else { return }
        let bundle = createBundle()
        guard let data = try? bundle.encodeToData() else { return }
        // 1. Always write shadow recovery bundle
        try? data.write(to: Self.autosaveShadowURL, options: .atomic)
        // 2. If user already saved to a .letters or .ltt file on disk, autosave in place
        if let fileURL = currentFileURL {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "letters" || ext == "ltt" {
                if (try? data.write(to: fileURL, options: .atomic)) != nil {
                    isDirty = false
                }
            }
        }
        lastAutosaveDate = Date()
    }

    func markSaved(url: URL) {
        currentFileURL = url
        isDirty = false
        lastAutosaveDate = Date()
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        let titleStr = url.lastPathComponent
        NSApp.windows.first?.title = "Letters — \(titleStr)"
        NSApp.windows.first?.representedURL = url
    }
    
    private static func scrubDeadTags(text: String, tables: [StudioTableData], images: [StudioImageBlock], videos: [StudioVideoBlock]) -> String {
        let regex = EditorPerformanceCache.shared.canvasSegmentRegex
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        
        var toRemove: [NSRange] = []
        for match in matches {
            let kind = ns.substring(with: match.range(at: 1))
            let idStr = (match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound) ? ns.substring(with: match.range(at: 2)) : ""
            
            if kind == "table" {
                if let uuid = UUID(uuidString: idStr), tables.contains(where: { $0.id == uuid }) { continue }
                if idStr.lowercased() == "budget" && !tables.isEmpty { continue }
                if tables.contains(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) { continue }
                toRemove.append(match.range)
            } else if kind == "image" {
                if let uuid = UUID(uuidString: idStr), images.contains(where: { $0.id == uuid }) { continue }
                if images.contains(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) { continue }
                toRemove.append(match.range)
            } else if kind == "video" {
                if let uuid = UUID(uuidString: idStr), videos.contains(where: { $0.id == uuid }) { continue }
                if videos.contains(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) { continue }
                toRemove.append(match.range)
            }
        }
        
        var cleanText = text
        for range in toRemove.reversed() {
            let nsMutable = NSMutableString(string: cleanText)
            nsMutable.deleteCharacters(in: range)
            cleanText = nsMutable as String
        }

        // Scrub any legacy `[note:1]` or `[note:xyz]` tags that might exist in old files
        cleanText = cleanText.replacingOccurrences(of: #"\s*\[note:[^\]]+\]"#, with: "", options: .regularExpression)
        
        return cleanText
    }

    public init(
        title: String = "Untitled Document",
        rawText: String = "",
        richTextData: Data? = nil,
        document: DocumentModel = DocumentModel(title: "Untitled", blocks: [], sources: [String: Source](), pageSize: .letter, margins: PageMargins(top: 72, bottom: 72, left: 72, right: 72)),
        tables: [StudioTableData] = [],
        images: [StudioImageBlock] = [],
        videos: [StudioVideoBlock] = [],
        floatingElements: [StudioFloatingElement] = [],
        footnotes: [StudioFootnote] = [],
        sideNotes: [StudioSideNote] = [],
        citationStyle: CitationStyle = .apa7,
        pageSize: PageSizePreset = .letter,
        marginPreset: MarginPreset = .normal,
        margins: PageMargins = PageMargins(top: 72, bottom: 72, left: 72, right: 72),
        coverBanner: CoverBannerConfig = CoverBannerConfig(),
        headerFooter: HeaderFooterConfig = HeaderFooterConfig(),
        isTrackChangesEnabled: Bool = false,
        revisions: [StudioTrackedRevision] = [],
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        lineSpacing: CGFloat = 1.15,
        paragraphSpacing: CGFloat = 12.0,
        textAlignment: TextAlignment = .leading,
        columnCount: Int = 1,
        showLineNumbers: Bool = false,
        watermarkText: String = "",
        kern: CGFloat = 0.0,
        hangingIndent: CGFloat = 0.0,
        styleProfile: String = "none"
    ) {
        self.title = title
        self.rawText = Self.scrubDeadTags(text: rawText, tables: tables, images: images, videos: videos)
        self.richTextData = richTextData
        self.document = document
        self.tables = tables
        self.images = images
        self.videos = videos
        self.floatingElements = floatingElements
        self.footnotes = footnotes
        self.sideNotes = sideNotes
        self.citationStyle = citationStyle
        self.pageSize = pageSize
        self.marginPreset = marginPreset
        self.margins = margins
        self.coverBanner = coverBanner
        self.headerFooter = headerFooter
        self.isTrackChangesEnabled = isTrackChangesEnabled
        self.revisions = revisions
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.textAlignment = textAlignment
        self.columnCount = columnCount
        self.showLineNumbers = showLineNumbers
        self.watermarkText = watermarkText
        self.kern = kern
        self.hangingIndent = hangingIndent
        self.styleProfile = styleProfile
        Self.active = self
        // Initial snapshot
        DispatchQueue.main.async {
            self.commitSnapshot(actionName: "Created Document", isMilestone: true)
            self.isDirty = false
        }
        
        $rawText
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.isDirty = true
            }
            .store(in: &cancellables)

        $rawText
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.commitSnapshot(actionName: "Typing", isMilestone: false)
                self.performAutosave()
            }
            .store(in: &cancellables)

        $tables
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.isDirty = true
                self.commitSnapshot(actionName: "Table Edit", isMilestone: false)
                self.performAutosave()
            }
            .store(in: &cancellables)

        $images
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.isDirty = true
                self.performAutosave()
            }
            .store(in: &cancellables)
    }
    
    func createBundle() -> LettersDocumentBundle {
        flushEditor?()
        let alignStr: String
        switch textAlignment {
        case .leading: alignStr = "leading"
        case .center: alignStr = "center"
        case .trailing: alignStr = "trailing"
        }

        return LettersDocumentBundle(
            title: title,
            rawText: rawText,
            richTextData: richTextData,
            tables: tables,
            images: images,
            videos: videos,
            floatingElements: floatingElements,
            footnotes: footnotes,
            sideNotes: sideNotes,
            sources: document.sources,
            citationStyle: citationStyle,
            pageSizePreset: pageSize,
            marginPreset: marginPreset,
            margins: margins,
            fontFamily: fontFamily,
            fontSize: Double(fontSize),
            lineSpacing: Double(lineSpacing),
            paragraphSpacing: Double(paragraphSpacing),
            textAlignmentString: alignStr,
            columnCount: columnCount,
            showLineNumbers: showLineNumbers,
            watermarkText: watermarkText,
            kern: Double(kern),
            hangingIndent: Double(hangingIndent),
            headerFooter: headerFooter,
            coverBanner: coverBanner,
            isTrackChangesEnabled: isTrackChangesEnabled,
            revisions: revisions,
            styleProfile: styleProfile
        )
    }
    
    func loadBundle(_ bundle: LettersDocumentBundle) {
        self.title = bundle.title
        self.tables = bundle.tables
        self.images = bundle.images
        self.videos = bundle.videos
        self.floatingElements = bundle.floatingElements
        self.footnotes = bundle.footnotes
        self.sideNotes = bundle.sideNotes
        self.rawText = Self.scrubDeadTags(text: bundle.rawText, tables: bundle.tables, images: bundle.images, videos: bundle.videos)
        self.richTextData = bundle.richTextData
        self.document.sources = bundle.sources
        self.citationStyle = bundle.citationStyle
        self.pageSize = bundle.pageSizePreset
        self.marginPreset = bundle.marginPreset
        self.margins = bundle.margins
        switch bundle.textAlignmentString {
        case "center": self.textAlignment = .center
        case "trailing", "right": self.textAlignment = .trailing
        default: self.textAlignment = .leading
        }
        self.columnCount = bundle.columnCount
        self.showLineNumbers = bundle.showLineNumbers
        self.watermarkText = bundle.watermarkText
        self.coverBanner = bundle.coverBanner
        self.headerFooter = bundle.headerFooter
        self.isTrackChangesEnabled = bundle.isTrackChangesEnabled
        self.revisions = bundle.revisions
        self.styleProfile = bundle.styleProfile
        self.fontFamily = bundle.fontFamily
        self.fontSize = CGFloat(bundle.fontSize)
        self.lineSpacing = CGFloat(bundle.lineSpacing)
        self.paragraphSpacing = CGFloat(bundle.paragraphSpacing)
        self.kern = CGFloat(bundle.kern)
        self.hangingIndent = CGFloat(bundle.hangingIndent)
    }

    // MARK: - Track Changes & Revisions Engine
    func recordRevision(
        kind: StudioTrackedRevision.RevisionKind,
        text: String,
        originalText: String? = nil,
        author: String? = nil,
        rangeLocation: Int? = nil,
        pageIndex: Int? = nil
    ) {
        let auth = author ?? (NSFullUserName().isEmpty ? "Reviewer" : NSFullUserName())

        // 1. Coalesce rapid consecutive typing (insertions) into single revision card
        if kind == .insertion, originalText == nil,
           let last = revisions.last,
           last.kind == .insertion,
           last.originalText == nil,
           last.author == auth,
           Date().timeIntervalSince(last.createdAt) < 3.0 {
            revisions[revisions.count - 1].text += text
            revisions[revisions.count - 1].createdAt = Date()
            return
        }

        // 2. Coalesce rapid consecutive backspacing/deletions into single revision card
        if kind == .deletion,
           let last = revisions.last,
           last.kind == .deletion,
           last.author == auth,
           Date().timeIntervalSince(last.createdAt) < 3.0 {
            let lastOrig = last.originalText ?? ""
            let newOrig = originalText ?? ""
            if let newLoc = rangeLocation, let lastLoc = last.rangeLocation, newLoc <= lastLoc {
                revisions[revisions.count - 1].originalText = newOrig + lastOrig
                revisions[revisions.count - 1].rangeLocation = newLoc
            } else {
                revisions[revisions.count - 1].originalText = lastOrig + newOrig
            }
            revisions[revisions.count - 1].createdAt = Date()
            return
        }

        let rev = StudioTrackedRevision(
            id: UUID(),
            kind: kind,
            text: text,
            originalText: originalText,
            author: auth,
            createdAt: Date(),
            rangeLocation: rangeLocation,
            pageIndex: pageIndex
        )
        revisions.append(rev)
        commitSnapshot(actionName: "Track Change (\(kind.rawValue))", isMilestone: false)
    }

    func acceptRevision(id: UUID) {
        guard let rev = revisions.first(where: { $0.id == id }) else { return }
        if rev.kind == .deletion, let orig = rev.originalText, !orig.isEmpty {
            rawText = rawText.replacingOccurrences(of: orig, with: "")
        }
        revisions.removeAll(where: { $0.id == id })
        commitSnapshot(actionName: "Accept Change", isMilestone: false)
    }

    func rejectRevision(id: UUID) {
        guard let rev = revisions.first(where: { $0.id == id }) else { return }
        if rev.kind == .insertion {
            rawText = rawText.replacingOccurrences(of: rev.text, with: rev.originalText ?? "")
        } else if rev.kind == .deletion {
            if let orig = rev.originalText, !orig.isEmpty {
                if let loc = rev.rangeLocation, loc <= (rawText as NSString).length {
                    let ns = rawText as NSString
                    let newStr = ns.substring(to: loc) + orig + ns.substring(from: loc)
                    rawText = newStr
                } else {
                    rawText += orig
                }
            }
        }
        revisions.removeAll(where: { $0.id == id })
        commitSnapshot(actionName: "Reject Change", isMilestone: false)
    }

    func acceptAllRevisions() {
        for rev in revisions {
            if rev.kind == .deletion, let orig = rev.originalText ?? (rev.text.isEmpty ? nil : rev.text) {
                rawText = rawText.replacingOccurrences(of: orig, with: "")
            }
        }
        revisions.removeAll()
        commitSnapshot(actionName: "Accept All Changes", isMilestone: false)
    }

    func rejectAllRevisions() {
        for rev in revisions.reversed() {
            if rev.kind == .insertion {
                rawText = rawText.replacingOccurrences(of: rev.text, with: rev.originalText ?? "")
            } else if rev.kind == .deletion {
                if let orig = rev.originalText, !orig.isEmpty {
                    if let loc = rev.rangeLocation, loc <= (rawText as NSString).length {
                        let ns = rawText as NSString
                        let newStr = ns.substring(to: loc) + orig + ns.substring(from: loc)
                        rawText = newStr
                    } else {
                        rawText += orig
                    }
                }
            }
        }
        revisions.removeAll()
        commitSnapshot(actionName: "Reject All Changes", isMilestone: false)
    }
    
    // MARK: - DAG Engine Methods
    
    func generateDiffSummary(old: LettersDocumentBundle, new: LettersDocumentBundle) -> String? {
        var diffs = [String]()
        
        let oldWords = old.rawText.split(whereSeparator: { $0.isWhitespace }).count
        let newWords = new.rawText.split(whereSeparator: { $0.isWhitespace }).count
        let wordDiff = newWords - oldWords
        
        if wordDiff > 0 { diffs.append("+\(wordDiff) words") }
        else if wordDiff < 0 { diffs.append("\(wordDiff) words") }
        
        let tableDiff = new.tables.count - old.tables.count
        if tableDiff > 0 { diffs.append("+\(tableDiff) table") }
        else if tableDiff < 0 { diffs.append("\(tableDiff) table") }
        
        return diffs.isEmpty ? nil : diffs.joined(separator: ", ")
    }
    
    func commitSnapshot(actionName: String, actor: SnapshotActor = .user, isMilestone: Bool = false) {
        if isReverting || isPeeking { return }
        
        let newBundle = createBundle()
        var diffSummary: String? = nil
        
        if let parentId = currentSnapshotId, let parentNode = historyNodes[parentId] {
            // Prevent duplicate identical snapshots
            if parentNode.bundle.rawText == newBundle.rawText && parentNode.bundle.tables == newBundle.tables {
                return 
            }
            diffSummary = generateDiffSummary(old: parentNode.bundle, new: newBundle)
        }
        
        let newNode = HistoryNode(
            id: UUID(),
            parentId: currentSnapshotId,
            timestamp: Date(),
            actionName: actionName,
            diffSummary: diffSummary,
            actor: actor,
            isMilestone: isMilestone,
            isPinned: false,
            customName: nil,
            bundle: newBundle
        )
        
        historyNodes[newNode.id] = newNode
        if mainBranchHeadId == nil || currentSnapshotId == mainBranchHeadId {
            mainBranchHeadId = newNode.id
        }
        currentSnapshotId = newNode.id
        
        // Memory cap: 200 nodes. Garbage collect oldest non-pinned leaves if necessary.
        if historyNodes.count > 200 {
            garbageCollectOldestNode()
        }
    }
    
    func garbageCollectOldestNode() {
        let sorted = historyNodes.values
            .filter { !$0.isPinned && $0.parentId == nil } // Try to kill roots first
            .sorted { $0.timestamp < $1.timestamp }
        
        if let oldest = sorted.first {
            historyNodes.removeValue(forKey: oldest.id)
        }
    }
    
    // MARK: - Time Travel & Peek
    
    func setAsMainBranch(nodeId: UUID) {
        mainBranchHeadId = nodeId
        if currentSnapshotId != nodeId {
            revertTo(id: nodeId)
        }
    }

    func revertTo(id: UUID) {
        guard let node = historyNodes[id] else { return }
        isReverting = true
        currentSnapshotId = id
        loadBundle(node.bundle)
        isReverting = false
    }
    
    func startPeek(id: UUID) {
        guard !isPeeking, let node = historyNodes[id] else { return }
        isPeeking = true
        backupBundleForPeek = createBundle()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            loadBundle(node.bundle)
        }
    }
    
    func endPeek() {
        guard isPeeking, let backup = backupBundleForPeek else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            loadBundle(backup)
        }
        backupBundleForPeek = nil
        isPeeking = false
    }
    
    func togglePin(id: UUID) {
        historyNodes[id]?.isPinned.toggle()
    }
    
    // MARK: - Micro Undo/Redo (Linear path resolution)
    
    func undo() {
        guard let current = currentSnapshotId, let node = historyNodes[current], let parentId = node.parentId else { return }
        revertTo(id: parentId)
    }
    
    func redo() {
        // Redo follows the most recently created child of the current node
        guard let current = currentSnapshotId else { return }
        let children = historyNodes.values.filter { $0.parentId == current }.sorted { $0.timestamp > $1.timestamp }
        if let mostRecentChild = children.first {
            revertTo(id: mostRecentChild.id)
        }
    }

    // MARK: - Tables API (Migrated to Snapshot Engine)
    
    func mutateTable(id: UUID, actionName: String? = nil, mutation: (inout StudioTableData) -> Void) {
        guard let index = tables.firstIndex(where: { $0.id == id }) else { return }
        var newTable = tables[index]
        mutation(&newTable)
        self.tables[index] = newTable
        
        if let name = actionName {
            commitSnapshot(actionName: name, isMilestone: true)
        }
    }
    
    func addTable(_ table: StudioTableData) {
        tables.append(table)
        commitSnapshot(actionName: "Insert Table", isMilestone: true)
    }
    
    func removeTable(id: UUID) {
        guard let index = tables.firstIndex(where: { $0.id == id }) else { return }
        tables.remove(at: index)
        commitSnapshot(actionName: "Delete Table", isMilestone: true)
    }
    
    func insertTable(_ table: StudioTableData, at index: Int) {
        tables.insert(table, at: index)
        commitSnapshot(actionName: "Insert Table", isMilestone: true)
    }
}

// MARK: - Workspace composition (canvas column, HUD, comments pane)
extension MainEditorView {
    var canvasConfig: CanvasConfig {
        CanvasConfig(
            geometry: SheetGeometry(
                sheetSize: CGSize(width: currentSheetWidth, height: currentSheetHeight),
                margins: documentController.margins
            ),
            fontFamily: documentController.fontFamily,
            fontSize: documentController.fontSize,
            lineSpacing: documentController.lineSpacing,
            paragraphSpacing: documentController.paragraphSpacing,
            alignment: documentController.textAlignment,
            kern: documentController.kern,
            hangingIndent: documentController.hangingIndent,
            showLineNumbers: documentController.showLineNumbers,
            showMarginGuides: showMarginGuides,
            showCropMarks: showCropMarks,
            watermark: documentController.watermarkText,
            headerFooter: documentController.headerFooter,
            title: documentController.title
        )
    }

    /// Center pane: optional ruler above one native scroll view that owns the paper.
    /// Nothing is layered on top of the page, so every click on the sheet reaches the text view.
    @ViewBuilder
    var canvasColumn: some View {
        VStack(spacing: 0) {
            if showRuler {
                StudioHorizontalRulerView(
                    sheetWidth: currentSheetWidth,
                    zoomScale: CGFloat(zoomScale),
                    margins: $documentController.margins,
                    hangingIndent: $documentController.hangingIndent,
                    onMarginChanged: { documentController.marginPreset = .custom }
                )
                .frame(width: currentSheetWidth * zoomScale, height: 26)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .background(StudioTheme.canvasBackground)
            }

            SanctuaryCanvas(
                document: documentController,
                controller: editorController,
                config: canvasConfig,
                zoom: $zoomScale,
                hoveredCommentId: hoveredCommentId,
                onSelectionChange: { snapshot in
                    if selectionRange != snapshot.range { selectionRange = snapshot.range }
                    if selectedText != snapshot.text { selectedText = snapshot.text }
                    if selectionAttributes != snapshot.attributes { selectionAttributes = snapshot.attributes }
                    if let tc = snapshot.attributes.textColor { textColorState = tc }
                    if let hc = snapshot.attributes.highlightColor { highlightColorState = hc }
                },
                onEditHeaderFooter: { target in
                    activeHeaderFooterTarget = target
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isEditingHeaderFooter = true }
                },
                blockContent: { kind in
                    AnyView(DocumentBlockView(kind: kind, document: documentController, onToast: { msg in showToast(msg) }))
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) { transientHUD }
    }

    /// Inline AI and find & replace. Only the visible cards take clicks; empty space passes straight through to the page.
    @ViewBuilder
    var transientHUD: some View {
        VStack(spacing: 10) {
            if showInlineAI && !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                InlineAICanvasEditorView(
                    selectedText: selectedText,
                    fullDocumentContext: documentController.rawText,
                    onAccept: { newText in
                        replaceSelection(with: newText)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showInlineAI = false }
                    },
                    onInsertBelow: { newText in
                        insertBelowSelection(newText: newText)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showInlineAI = false }
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showInlineAI = false }
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.94).combined(with: .opacity).combined(with: .offset(y: 12)),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
            }

            if showFindReplace {
                FindReplaceBar(
                    isPresented: $showFindReplace,
                    rawText: $documentController.rawText,
                    onToast: { msg in showToast(msg) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 16)
    }

    var footnotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FOOTNOTES")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            ForEach(documentController.footnotes) { fn in
                HStack(alignment: .top, spacing: 6) {
                    Text(fn.referenceMarker)
                        .font(.system(size: 10, weight: .bold))
                        .baselineOffset(4)
                    NativeFootnoteField(
                        text: Binding(
                            get: { fn.text },
                            set: { newText in
                                if let idx = documentController.footnotes.firstIndex(where: { $0.id == fn.id }) {
                                    documentController.footnotes[idx].text = newText
                                }
                            }
                        ),
                        placeholder: "Footnote text...",
                        font: NSFont.systemFont(ofSize: 11),
                        textColor: .labelColor
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        let marker = fn.referenceMarker
                        documentController.footnotes.removeAll(where: { $0.id == fn.id })
                        documentController.rawText = documentController.rawText.replacingOccurrences(of: marker, with: "")
                        showToast("✓ Removed footnote")
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Delete Footnote")
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Right pane listing every margin comment and tracked change in document order.
    var commentsPane: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right").foregroundColor(.accentColor)
                Text("Comments").font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    insertSideNote()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { showComments = false }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if documentController.sideNotes.isEmpty && documentController.revisions.isEmpty && documentController.footnotes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble").font(.system(size: 26)).foregroundColor(.secondary.opacity(0.5))
                    Text("No comments yet").font(.system(size: 12, weight: .semibold))
                    Text("Select text, then press Add to attach a comment.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(documentController.sideNotes) { note in
                            marginCommentCard(sn: note)
                        }
                        ForEach(documentController.revisions) { rev in
                            onPaperRevisionCard(rev: rev)
                        }
                        if !documentController.footnotes.isEmpty {
                            footnotesSection
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(StudioTheme.panelBackground)
    }
}
