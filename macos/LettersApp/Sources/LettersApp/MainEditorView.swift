import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

/// Editor shell. It owns the document, the canvas controller and the window-level UI state, and wires
/// them to the regions below. It deliberately does **not** observe the document: every region that
/// renders document state subscribes itself (see `EditorStateModels.swift`), so typing never
/// re-evaluates this view.
///
/// Layout of the feature:
///   * `StudioTopToolbarView`          – top toolbar strip
///   * `MainEditorView+Workspace`      – outline | canvas | right pane, status bar
///   * `EditorModalsAndOverlays`       – sheets, toast host, inline-AI / find HUD
///   * `MainEditorView+Actions` / `+CommandCenter` / `+FileIO` / `+Review` / `+HeaderFooter`
public struct MainEditorView: View {
    /// Non-publishing holder for the objects below; keeps the root out of the keystroke path.
    @StateObject var context = EditorContext()

    var documentController: LettersDocumentController { context.document }
    var editorController: EditorActionController { context.editor }
    var toastManager: ToastManager { context.toasts }
    var caretStore: EditorCaretStore { context.caret }
    var formatStore: EditorFormatStore { context.format }

    // Window-level UI state. Changing any of these re-evaluates the shell, never typing.
    @State var showCommandPalette: Bool = false
    @State var zoomScale: Double = 1.0
    @State var showingAddSourceSheet: Bool = false
    @State var showingCrossReferenceSheet: Bool = false
    @State var showFindReplace: Bool = false
    @State var showInlineAI: Bool = false
    @State var showingSettingsSheet: Bool = false
    @State var hoveredCommentId: UUID? = nil
    @State var showingPasteSpecialSheet: Bool = false
    @State var selectedPasteMode: PasteSpecialMode = .matchStyle

    // New Source form states
    @State var newSourceTitle: String = ""
    @State var newSourceAuthor: String = ""
    @State var newSourceYear: String = ""
    @State var newSourceType: SourceType = .journalArticle

    // Page Setup & Margins State
    @State var showMarginGuides: Bool = true
    @State var showCropMarks: Bool = true
    @State var showRuler: Bool = true

    // Header & Footer Configuration State
    @State var isEditingHeaderFooter: Bool = false
    @State var activeHeaderFooterTarget: HeaderFooterTarget = .header

    @State var showOutlineDrawer: Bool = true
    @State var showRevisionsPopover: Bool = false

    /// The right-hand pane is a single choice, not several booleans kept mutually exclusive by hand.
    @State var rightPane: EditorRightPane = .inspector

    func paneBinding(_ pane: EditorRightPane) -> Binding<Bool> {
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

    // MARK: Selection / formatting state (forwarded to the granular stores)
    var selectionRange: NSRange {
        get { caretStore.range }
        nonmutating set { caretStore.range = newValue }
    }
    var selectedText: String {
        get { caretStore.text }
        nonmutating set { caretStore.text = newValue }
    }
    var selectionAttributes: EditorSelectionAttributes? {
        get { formatStore.attributes }
        nonmutating set { formatStore.attributes = newValue }
    }
    var isBold: Bool {
        get { formatStore.isBold }
        nonmutating set { formatStore.isBold = newValue }
    }
    var isItalic: Bool {
        get { formatStore.isItalic }
        nonmutating set { formatStore.isItalic = newValue }
    }
    var isUnderline: Bool {
        get { formatStore.isUnderline }
        nonmutating set { formatStore.isUnderline = newValue }
    }
    var lintIssues: [StyleLintMatch] {
        get { context.lintIssues }
        nonmutating set { context.lintIssues = newValue }
    }

    public init() {}

    // Computed on demand (command palette, AI context); the footer maintains its own debounced copy.
    var wordCount: Int { EditorPerformanceCache.countWords(in: documentController.rawText) }
    var characterCount: Int { documentController.rawText.count }

    var currentSheetWidth: CGFloat {
        documentController.pageSize.dimensions.width
    }

    var currentSheetHeight: CGFloat {
        documentController.pageSize.dimensions.height
    }

    public var body: some View {
        VStack(spacing: 0) {
            StudioTopToolbarView(
                documentController: documentController,
                format: formatStore,
                showOutlineDrawer: $showOutlineDrawer,
                rightPane: $rightPane,
                actions: toolbarActions
            )

            // Review strip (track changes active / pending revisions) and the docked header & footer editor.
            Observing(documentController) { doc in
                if doc.isTrackChangesEnabled || !doc.revisions.isEmpty {
                    reviewToolbarStrip
                }
                if isEditingHeaderFooter {
                    headerFooterToolbarStrip
                }
            }

            workspace

            statusBar
        }
        .overlay(alignment: .bottomTrailing) {
            EditorToastHost(toasts: toastManager)
        }
        .modifier(EditorSheetsModifier(host: self))
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
        // The shell no longer observes the document, so it subscribes to the two signals it acts on.
        .onReceive(documentController.$rawText.debounce(for: .milliseconds(350), scheduler: RunLoop.main)) { _ in
            runLinter()
        }
        .onReceive(documentController.$styleProfile.dropFirst().removeDuplicates()) { _ in
            runLinter()
        }
    }

    /// Maps toolbar buttons onto the editing actions in `MainEditorView+Actions`.
    var toolbarActions: StudioToolbarActions {
        StudioToolbarActions(
            paragraphStyle: { applyParagraphStyleAction($0) },
            fontFamily: { setFontFamilyAction($0) },
            fontSize: { setFontSizeAction($0) },
            bold: { toggleBoldAction() },
            italic: { toggleItalicAction() },
            underline: { toggleUnderlineAction() },
            textColor: { setTextColorAction($0) },
            highlight: { setTextHighlightAction($0) },
            clearFormatting: { clearFormattingAction() },
            cleanContrast: { editorController.cleanContrastForCurrentSelection() },
            alignment: { setAlignmentAction($0) },
            bullet: { insertBulletListAction() },
            numbered: { insertNumberedListAction() },
            lineSpacing: { setLineSpacingAction($0) },
            paragraphSpacing: { setParagraphSpacingAction($0) },
            toast: { showToast($0) },
            openCommandPalette: { showCommandPalette.toggle() }
        )
    }

    /// Shows a transient confirmation using the new ToastManager (Sonner-style).
    func showToast(_ rawMessage: String) {
        var msg = rawMessage
        let isWarning = msg.hasPrefix("⚠️")
        for prefix in ["✓ ", "⚠️ ", "✨ ", "💬 ", "📊 "] where msg.hasPrefix(prefix) {
            msg.removeFirst(prefix.count)
            break
        }
        let lower = msg.lowercased()
        if lower.hasPrefix("font") || lower.hasPrefix("bold") || lower.hasPrefix("italic") ||
           lower.hasPrefix("underline") || lower.hasPrefix("alignment") || lower.hasPrefix("zoom") ||
           lower.hasPrefix("paragraph spacing") || lower.hasPrefix("line spacing") {
            return
        }
        if isWarning {
            toastManager.show(.warning(msg))
        } else {
            toastManager.show(.success(msg))
        }
    }
}
