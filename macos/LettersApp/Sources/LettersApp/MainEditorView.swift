import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
import OSLog
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

    /// The right-hand inspector is one pane with three tabs (Document, Review, Assistant) or closed.
    @State var rightPane: EditorRightPane = .document
    /// Which sub-filter each tab shows. Kept here so the toolbar badge and menu commands can steer them.
    @State var reviewSegment: ReviewSegment = .comments
    @State var assistantSegment: AssistantSegment = .assistant

    /// True while the Assistant tab is showing; setting it opens or closes that tab.
    var showAIDrawer: Bool {
        get { rightPane == .assistant }
        nonmutating set { rightPane = newValue ? .assistant : (rightPane == .assistant ? .none : rightPane) }
    }

    /// Opens the Review tab on a given sub-filter; calling it again for the visible one closes the pane.
    func toggleReview(_ segment: ReviewSegment) {
        if rightPane == .review && reviewSegment == segment {
            rightPane = .none
        } else {
            reviewSegment = segment
            rightPane = .review
        }
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
        let size = documentController.pageSize.dimensions
        return documentController.isLandscape ? size.height : size.width
    }

    var currentSheetHeight: CGFloat {
        let size = documentController.pageSize.dimensions
        return documentController.isLandscape ? size.width : size.height
    }

    public var body: some View {
        VStack(spacing: 0) {
            StudioTopToolbarView(
                documentController: documentController,
                format: formatStore,
                showOutlineDrawer: $showOutlineDrawer,
                rightPane: $rightPane,
                reviewSegment: $reviewSegment,
                actions: toolbarActions
            )

            // Docked header & footer editor. Track-changes review lives in the inspector's Review tab.
            if isEditingHeaderFooter {
                headerFooterToolbarStrip
            }

            workspace

            statusBar
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
                    rightPane = rightPane.toggled(.document)
                }
            },
            onDocumentHistory: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    toggleReview(.history)
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

    /// Confirmations are deliberately silent: the interface already shows the result of an action, and
    /// banners over the page were noise. Call sites keep passing messages so a feedback channel can be
    /// reintroduced in one place; problems are still written to the unified log.
    func showToast(_ message: String) {
        guard message.hasPrefix("⚠️") else { return }
        Self.log.warning("\(message, privacy: .public)")
    }

    private static let log = Logger(subsystem: "com.projectletters.Letters", category: "editor")
}
