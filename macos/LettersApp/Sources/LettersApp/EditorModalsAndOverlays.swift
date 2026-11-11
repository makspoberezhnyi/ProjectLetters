import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Modals & overlays
//
// Everything that floats above the editor: the sheets (add source, cross reference, command palette,
// settings, paste special), the toast host, and the transient inline-AI / find & replace HUD.

/// Hosts the Sonner-style toast stack. Lives outside any document-observing subtree.
struct EditorToastHost: View {
    let toasts: ToastManager

    var body: some View {
        ToastOverlay(manager: toasts, position: .bottomTrailing)
    }
}

/// All `.sheet` presentations of the editor shell, in one place.
struct EditorSheetsModifier: ViewModifier {
    let host: MainEditorView

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: host.$showingAddSourceSheet) {
                AddSourceSheet(
                    isPresented: host.$showingAddSourceSheet,
                    title: host.$newSourceTitle,
                    author: host.$newSourceAuthor,
                    year: host.$newSourceYear,
                    sourceType: host.$newSourceType,
                    documentController: host.documentController,
                    onToast: { host.showToast($0) }
                )
            }
            .sheet(isPresented: host.$showingCrossReferenceSheet) {
                CrossReferenceSheet(
                    isPresented: host.$showingCrossReferenceSheet,
                    documentController: host.documentController,
                    onInsertFigure: { host.insertCrossReference(targetId: $0, type: "Figure") }
                )
            }
            .sheet(isPresented: host.$showCommandPalette) {
                CommandPaletteView(
                    isPresented: host.$showCommandPalette,
                    commands: host.paletteCommands,
                    onExecuteDirectCLI: host.executeDirectCLICommand
                )
            }
            .sheet(isPresented: host.$showingSettingsSheet) {
                Observing(host.documentController) { doc in
                    SettingsView(
                        isPresented: host.$showingSettingsSheet,
                        fontFamily: doc.binding(\.fontFamily),
                        fontSize: doc.binding(\.fontSize),
                        citationStyle: doc.binding(\.citationStyle),
                        pageSize: doc.binding(\.pageSize),
                        marginPreset: doc.binding(\.marginPreset),
                        showMarginGuides: host.$showMarginGuides,
                        showCropMarks: host.$showCropMarks,
                        onToast: { host.showToast($0) }
                    )
                }
            }
            .sheet(isPresented: host.$showingPasteSpecialSheet) {
                host.pasteSpecialSheetView
            }
    }
}

struct AddSourceSheet: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var author: String
    @Binding var year: String
    @Binding var sourceType: SourceType
    let documentController: LettersDocumentController
    let onToast: (String) -> Void

    init(
        isPresented: Binding<Bool>,
        title: Binding<String>,
        author: Binding<String>,
        year: Binding<String>,
        sourceType: Binding<SourceType>,
        documentController: LettersDocumentController,
        onToast: @escaping (String) -> Void
    ) {
        self._isPresented = isPresented
        self._title = title
        self._author = author
        self._year = year
        self._sourceType = sourceType
        self.documentController = documentController
        self.onToast = onToast
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Linked Source Citation")
                .font(.headline)

            Form {
                TextField("Title", text: $title)
                TextField("Author(s) (comma separated)", text: $author)
                TextField("Year", text: $year)
                Picker("Source Type", selection: $sourceType) {
                    ForEach(SourceType.allCases, id: \.self) { st in
                        Text(st.rawValue.capitalized).tag(st)
                    }
                }
            }
            .frame(width: 320)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                Button("Add & Insert") {
                    addAndInsert()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
        }
        .padding(20)
    }

    private func addAndInsert() {
        let id = UUID().uuidString.prefix(6).lowercased()
        let authors = author.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let source = Source(
            id: String(id),
            sourceType: sourceType,
            authors: authors,
            year: Int(year),
            title: title
        )
        documentController.document.sources[String(id)] = source
        let ref = CitationReference(sourceId: String(id))
        let rendered = CoreBridge.shared.renderCitation(source: source, reference: ref, style: documentController.citationStyle)
        documentController.rawText += " \(rendered)"
        isPresented = false
        title = ""
        author = ""
        year = ""
        onToast("✓ Added citation \(rendered)")
    }
}

struct CrossReferenceSheet: View {
    @Binding var isPresented: Bool
    let documentController: LettersDocumentController
    let onInsertFigure: (String) -> Void

    var body: some View {
        Observing(documentController) { doc in
            VStack(alignment: .leading, spacing: 16) {
                Text("Insert Cross Reference")
                    .font(.headline)

                if doc.images.isEmpty {
                    Text("No figures available to reference.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(Array(doc.images.enumerated()), id: \.element.id) { index, img in
                            Button {
                                onInsertFigure(img.id.uuidString)
                                isPresented = false
                            } label: {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("Figure \(index + 1)")
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
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(20)
            .frame(width: 400)
        }
    }
}

extension MainEditorView {
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

    /// Inline AI and find & replace. Only the visible cards take clicks; empty space passes straight through to the page.
    var transientHUD: some View {
        Observing(caretStore) { caret in
            VStack(spacing: 10) {
                if showInlineAI && !caret.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    InlineAICanvasEditorView(
                        selectedText: caret.text,
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
                        rawText: documentController.binding(\.rawText),
                        onToast: { msg in showToast(msg) }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 16)
        }
    }
}

/// Docked footer. Word / character / page counts are recomputed once typing pauses,
/// and the citation label follows the document immediately, without involving the shell.
struct EditorStatusBarHost: View {
    let documentController: LettersDocumentController
    let editorController: EditorActionController
    let zoomScale: Double

    @StateObject private var labels: DocumentSlice<Labels>
    @State private var counts = Counts()

    struct Labels: Equatable {
        var citationStyle: String
        var styleProfile: String
    }
    struct Counts: Equatable {
        var words = 0
        var characters = 0
        var pages = 1
    }

    init(documentController: LettersDocumentController, editorController: EditorActionController, zoomScale: Double) {
        self.documentController = documentController
        self.editorController = editorController
        self.zoomScale = zoomScale
        self._labels = StateObject(wrappedValue: DocumentSlice(documentController) {
            Labels(citationStyle: $0.citationStyle.displayName, styleProfile: $0.styleProfile)
        })
    }

    var body: some View {
        StatusBarMetrics(
            wordCount: counts.words,
            characterCount: counts.characters,
            pageCount: counts.pages,
            readingTimeMinutes: counts.words == 0 ? 0 : max(1, Int(ceil(Double(counts.words) / 200.0))),
            citationStyle: labels.value.citationStyle,
            styleProfile: labels.value.styleProfile,
            zoomScale: zoomScale
        )
        .onAppear(perform: refresh)
        // Any document change (typing, page setup, page breaks) restarts the quiet-period timer.
        .onReceive(documentController.objectWillChange.debounce(for: .milliseconds(350), scheduler: RunLoop.main)) { _ in
            refresh()
        }
    }

    private func refresh() {
        let text = documentController.rawText
        let next = Counts(
            words: EditorPerformanceCache.countWords(in: text),
            characters: text.count,
            pages: editorController.pageCount
        )
        if next != counts { counts = next }
    }
}
