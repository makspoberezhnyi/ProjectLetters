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
                isPresented: $showOutlineDrawer,
                rawText: documentController.binding(\.rawText),
                cursorOffset: caret.range.location,
                pageCount: editorController.pageCount,
                pageForOffset: { editorController.pageNumber(forCharacterOffset: $0) },
                pageSnippet: { editorController.snippet(forPage: $0) },
                sources: documentController.binding(\.document.sources),
                activeCitationStyle: documentController.binding(\.citationStyle),
                onSelectOffset: { offset in editorController.jumpToCharacterOffset(offset) },
                onSelectHeading: { _, offset in editorController.jumpToCharacterOffset(offset) },
                onSelectPage: { page in editorController.scrollToPage(page) }
            )
        }
    }

    @ViewBuilder
    var rightPaneView: some View {
        if showPageDesignInspector {
            Divider()

            inspectorPane
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if showAIDrawer {
            Divider()

            assistantPane
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

    var inspectorPane: some View {
        Observing(formatStore) { format in
            StudioContextualInspectorView(
                isPresented: paneBinding(.inspector),
                fontFamily: documentController.binding(\.fontFamily),
                fontSize: documentController.binding(\.fontSize),
                lineSpacing: documentController.binding(\.lineSpacing),
                paragraphSpacing: documentController.binding(\.paragraphSpacing),
                hangingIndent: documentController.binding(\.hangingIndent),
                textAlignment: documentController.binding(\.textAlignment),
                pageSize: documentController.binding(\.pageSize),
                marginPreset: documentController.binding(\.marginPreset),
                margins: documentController.binding(\.margins),
                columnCount: documentController.binding(\.columnCount),
                showLineNumbers: documentController.binding(\.showLineNumbers),
                showMarginGuides: $showMarginGuides,
                citationStyle: documentController.binding(\.citationStyle),
                sources: documentController.binding(\.document.sources),
                selectionAttributes: format.attributes,
                onToggleBold: { toggleBoldAction() },
                onToggleItalic: { toggleItalicAction() },
                onToggleUnderline: { toggleUnderlineAction() },
                onToggleStrikethrough: { toggleStrikethroughAction() },
                onApplyParagraphStyle: { style in applyParagraphStyleAction(style) },
                onAddSource: { showingAddSourceSheet = true },
                onInsertBibliography: { insertBibliographyAction() },
                onToast: { msg in showToast(msg) }
            )
        }
    }

    var assistantPane: some View {
        Observing(caretStore) { caret in
            AssistantSidebarView(
                rawText: documentController.binding(\.rawText),
                selectedText: Binding(get: { caret.text }, set: { caret.text = $0 }),
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
