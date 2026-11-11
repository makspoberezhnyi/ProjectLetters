import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Workspace composition (outline | canvas | right pane, status bar)
//
// Each region subscribes to the state it renders: the three-pane workspace observes the document,
// the outline additionally the caret, the inspector the formatting store. The toolbar, sheets and
// notification modifiers live outside this subtree and are untouched by keystrokes.
extension MainEditorView {
    /// Three-pane workspace: Outline | Sanctuary Canvas | Contextual pane.
    var workspace: some View {
        Observing(documentController) { _ in
            HStack(spacing: 0) {
                if showOutlineDrawer {
                    outlinePane
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Divider()
                }

                canvasColumn

                // Docked right contextual inspector / copilot / document history / comments panes.
                rightPaneView
            }
        }
    }

    var outlinePane: some View {
        Observing(caretStore) { caret in
            DocumentOutlineView(
                rawText: documentController.binding(\.rawText),
                cursorOffset: caret.range.location,
                pageCount: editorController.pageCount,
                pageForOffset: { editorController.pageNumber(forCharacterOffset: $0) },
                pageSnippet: { editorController.snippet(forPage: $0) },
                onSelectOffset: { offset in editorController.jumpToCharacterOffset(offset) },
                onSelectHeading: { _, offset in editorController.jumpToCharacterOffset(offset) },
                onSelectPage: { page in editorController.scrollToPage(page) }
            )
        }
    }

    /// The unified inspector: Document | Review | Assistant, or nothing.
    @ViewBuilder
    var rightPaneView: some View {
        if let tab = rightPane.tab {
            Divider()

            inspectorPane(tab: tab)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    func inspectorPane(tab: InspectorTab) -> some View {
        StudioContextualInspectorView(
            tab: tab,
            onClose: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { rightPane = .none }
            },
            documentTab: {
                InspectorDocumentTab(
                    document: documentController,
                    showMarginGuides: $showMarginGuides,
                    showRuler: $showRuler,
                    isEditingHeaderFooter: isEditingHeaderFooter,
                    activeHeaderFooterTarget: activeHeaderFooterTarget,
                    onEditHeaderFooter: { target in
                        activeHeaderFooterTarget = target
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isEditingHeaderFooter = true }
                    }
                )
            },
            reviewTab: {
                InspectorReviewTab(
                    document: documentController,
                    segment: $reviewSegment,
                    hoveredCommentId: $hoveredCommentId,
                    onAddComment: { insertSideNote() },
                    onJumpToOffset: { editorController.jumpToCharacterOffset($0) }
                )
            },
            assistantTab: { assistantTab }
        )
    }

    var assistantTab: some View {
        Observing(caretStore) { caret in
            InspectorAssistantTab(
                document: documentController,
                segment: $assistantSegment,
                selectedText: Binding(get: { caret.text }, set: { caret.text = $0 }),
                onInsertTable: { table in
                    let marker = "\n\n[[table:\(table.id.uuidString)]]\n\n"
                    editorController.insertAtCaret(marker)
                    documentController.tables.append(table)
                    documentController.commitSnapshot(actionName: "Insert Table", isMilestone: true)
                },
                onInsertSource: { source in
                    documentController.document.sources[source.id] = source
                    let citeTag = InTextCitation.text(for: source, style: documentController.citationStyle)
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
                onInsertPageBreak: { insertPageBreakAction() },
                onInsertTOC: { insertTOCAction() },
                onInsertBibliography: { insertBibliographyAction() },
                onInsertAtCaret: { editorController.insertAtCaret($0) },
                onToast: { msg in showToast(msg) },
                currentDocumentContext: { buildDocumentAIContext() },
                onAddSource: { showingAddSourceSheet = true }
            )
        }
    }

    /// Docked app footer. Keeps its own debounced word / character / page counts.
    var statusBar: some View {
        EditorStatusBarHost(
            documentController: documentController,
            editorController: editorController,
            zoomScale: zoomScale
        )
    }

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
                    margins: documentController.binding(\.margins),
                    hangingIndent: documentController.binding(\.hangingIndent),
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
                    applySelectionSnapshot(snapshot)
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

    /// Writes the canvas selection into the granular stores, skipping unchanged values so
    /// that only the regions that render a changed field are invalidated.
    func applySelectionSnapshot(_ snapshot: SelectionSnapshot) {
        if caretStore.range != snapshot.range { caretStore.range = snapshot.range }
        if caretStore.text != snapshot.text { caretStore.text = snapshot.text }
        if formatStore.attributes != snapshot.attributes { formatStore.attributes = snapshot.attributes }
        if let tc = snapshot.attributes.textColor, formatStore.textColor != tc { formatStore.textColor = tc }
        if let hc = snapshot.attributes.highlightColor, formatStore.highlightColor != hc { formatStore.highlightColor = hc }
    }
}
