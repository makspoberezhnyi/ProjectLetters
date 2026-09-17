import SwiftUI
import AppKit
import UniformTypeIdentifiers
#if canImport(LettersKit)
import LettersKit
#endif

public struct MainEditorView: View {
    @State private var documentTitle: String = "Letters Product Specification"
    @State private var document = DocumentModel(
        title: "Letters Product Specification",
        blocks: []
    )

    @State private var rawText: String = """
# Letters: Modern Document Studio

Letters is a next-generation desktop publishing and document studio combining graphic design precision with native Word (.docx) fidelity.

## 1. Core Architecture & Native Engine
* **SwiftUI & TextKit 2 Viewport:** Ultra-smooth layout and scrolling on massive 100+ page documents.
* **Headless Rust Core:** Lossless OpenXML (.docx) packaging and parsing with zero formatting degradation.
* **Universal BYOK AI Gateway:** Direct cloud streaming with Anthropic Claude, OpenAI GPT-4o, and Google Gemini.

## 2. Linked Sources & Dynamic Style Rules
* Citations store structured bibliographic metadata rather than flat static text.
* Real-time re-rendering across APA 7, MLA 9, Chicago, and Bluebook legal standards.

## 3. Dynamic Smart Tables & Formulas
* Embedded computational tables with reactive formula evaluation and paragraph variable referencing.
"""

    @State private var activeTool: StudioTool = .select
    @State private var activePersona: StudioPersona = .write
    @State private var selectedPage: Int = 1
    @State private var selectedText: String = ""
    @State private var selectionRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showInspector: Bool = true
    @State private var activeCitationStyle: CitationStyle = .apa7
    @State private var showCommandPalette: Bool = false
    @State private var lintIssues: [StyleLintMatch] = []
    @State private var toastMessage: String? = nil
    @State private var zoomScale: Double = 1.0
    @State private var showingAddSourceSheet: Bool = false

    // New Source form states
    @State private var newSourceTitle: String = ""
    @State private var newSourceAuthor: String = ""
    @State private var newSourceYear: String = ""
    @State private var newSourceType: SourceType = .journalArticle

    // Live Typography States (Directly updates TextKit 2)
    @State private var fontFamily: String = "Default Serif (Georgia)"
    @State private var fontSize: CGFloat = 15.0
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var isUnderline: Bool = false
    @State private var textAlignment: TextAlignment = .leading
    @State private var lineSpacing: CGFloat = 1.15
    @State private var paragraphSpacing: CGFloat = 12.0

    public init() {}

    private var wordCount: Int {
        rawText.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var characterCount: Int {
        rawText.count
    }

    private var readingTimeMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 200.0)))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Studio Persona & Live Formatting Ribbon
            StudioTopBar(
                activePersona: $activePersona,
                fontFamily: $fontFamily,
                fontSize: $fontSize,
                isBold: $isBold,
                isItalic: $isItalic,
                isUnderline: $isUnderline,
                alignment: $textAlignment,
                lineSpacing: $lineSpacing,
                onExportDocx: saveDocumentAsDocx,
                onSaveMarkdown: saveDocumentAsMarkdown,
                onToggleInspector: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInspector.toggle()
                    }
                }
            )

            // 2. Main Studio Workspace Layout
            HStack(spacing: 0) {
                // Left Pro Tool Rail (Affinity / Figma Style)
                StudioToolRail(activeTool: $activeTool) { clickedTool in
                    handleToolAction(clickedTool)
                }

                // Left Pages / Spreads & Outline Navigator
                StudioPagesNavigator(rawText: $rawText, selectedPage: $selectedPage)

                // Center Studio Canvas & Paper Sheet
                ZStack(alignment: .bottom) {
                    ScrollView([.vertical, .horizontal]) {
                        VStack(spacing: 20) {
                            // Document Sheet Title Header (Clean and de-duplicated)
                            HStack {
                                TextField("Document Title", text: $documentTitle)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text("US Letter • 8.5 × 11 in")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 816 * zoomScale)
                            .padding(.top, 24)

                            // Graphic Studio Paper Sheet Canvas
                            ZStack(alignment: .top) {
                                TextKit2EditorView(
                                    text: $rawText,
                                    selectedText: $selectedText,
                                    selectionRange: $selectionRange,
                                    fontFamily: fontFamily,
                                    fontSize: fontSize,
                                    isBold: isBold,
                                    isItalic: isItalic,
                                    alignment: textAlignment,
                                    lineSpacing: lineSpacing,
                                    paragraphSpacing: paragraphSpacing,
                                    onSelectionChanged: { _, _ in }
                                )
                                .frame(width: 816)
                                .frame(minHeight: 1056)
                                .background(StudioTheme.paperBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(StudioTheme.border, lineWidth: 1)
                                )
                                // Multi-layered depth shadow
                                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                                .shadow(color: Color.black.opacity(0.12), radius: 28, x: 0, y: 14)
                                .scaleEffect(zoomScale, anchor: .top)

                                // Floating contextual selection menu
                                if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    FloatingActionMenu(
                                        selectedText: selectedText,
                                        onBold: {
                                            rawText = rawText.replacingOccurrences(of: selectedText, with: "**\(selectedText)**")
                                        },
                                        onItalic: {
                                            rawText = rawText.replacingOccurrences(of: selectedText, with: "*\(selectedText)*")
                                        },
                                        onTranslate: {
                                            Task {
                                                if let res = try? await TranslationService.shared.translate(text: selectedText) {
                                                    rawText = rawText.replacingOccurrences(of: selectedText, with: res)
                                                }
                                            }
                                        },
                                        onExplain: {
                                            activePersona = .aiStudio
                                            showInspector = true
                                        },
                                        onCite: {
                                            insertCitationForSelection()
                                        }
                                    )
                                    .padding(.top, 16)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.bottom, 60)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .background(StudioTheme.canvasBackground)

                    // Floating Toast Notification
                    if let msg = toastMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(msg)
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 14, x: 0, y: 6)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Right Studio Inspector (Accordion Style)
                if showInspector {
                    StudioInspectorView(
                        activePersona: $activePersona,
                        sources: $document.sources,
                        activeCitationStyle: $activeCitationStyle,
                        lintIssues: $lintIssues,
                        lineSpacing: $lineSpacing,
                        paragraphSpacing: $paragraphSpacing,
                        currentDocumentContext: { rawText },
                        onRunLinter: runLinter,
                        onAddSource: { showingAddSourceSheet = true }
                    )
                    .transition(.move(edge: .trailing))
                }
            }

            // 3. Bottom Studio Status & Zoom Bar
            StudioBottomBar(
                selectedPage: $selectedPage,
                totalPages: 2,
                wordCount: wordCount,
                characterCount: characterCount,
                readingTime: readingTimeMinutes,
                zoomLevel: $zoomScale
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
                        document.sources[String(id)] = source
                        let ref = CitationReference(sourceId: String(id))
                        let rendered = CoreBridge.shared.renderCitation(source: source, reference: ref, style: activeCitationStyle)
                        rawText += " \(rendered)"
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
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView(isPresented: $showCommandPalette, commands: paletteCommands)
        }
        .onAppear {
            runLinter()
        }
    }

    // MARK: - Tool Actions
    private func handleToolAction(_ tool: StudioTool) {
        switch tool {
        case .select:
            showToast("Selection Mode active")
        case .text:
            rawText += "\n\n## New Section Heading\nType section body text here..."
            showToast("✓ Inserted Text Frame")
        case .table:
            rawText += "\n\n| Item | Q1 Revenue | Q2 Revenue | Total (=Q1+Q2) |\n| :--- | :--- | :--- | :--- |\n| Core Platform | $1,200 | $2,400 | $3,600 |\n| AI Gateway | $800 | $1,600 | $2,400 |\n"
            showToast("✓ Inserted Smart Table")
        case .citation:
            showingAddSourceSheet = true
        case .style:
            activePersona = .write
            showInspector = true
            runLinter()
            showToast("✓ Scanned style rules")
        case .copilot:
            activePersona = .aiStudio
            showInspector = true
            showToast("✓ Opened AI Copilot")
        case .pan:
            showToast("Canvas Pan tool active")
        }
    }

    private func insertCitationForSelection() {
        showingAddSourceSheet = true
    }

    private var paletteCommands: [CommandItem] {
        [
            CommandItem(title: "Save as Word Document (.docx)", subtitle: "Generate native lossless DOCX file", icon: "doc.fill", shortcut: "⌘S") {
                saveDocumentAsDocx()
            },
            CommandItem(title: "Export as Markdown (.md)", subtitle: "Save clean markdown text", icon: "doc.text", shortcut: "⌘⇧S") {
                saveDocumentAsMarkdown()
            },
            CommandItem(title: "Insert Smart Table", subtitle: "Embed interactive calculation table", icon: "tablecells", shortcut: "⌘T") {
                handleToolAction(.table)
            },
            CommandItem(title: "Add Linked Source", subtitle: "Open citation metadata manager", icon: "quote.opening", shortcut: "⌘C") {
                showingAddSourceSheet = true
            },
            CommandItem(title: "Toggle AI Assistant", subtitle: "Open BYOK Copilot companion", icon: "sparkles", shortcut: "⌘J") {
                activePersona = .aiStudio
                showInspector = true
            },
            CommandItem(title: "Switch Citation Style to APA 7", subtitle: "Re-render all citations to APA standard", icon: "quote.opening") {
                activeCitationStyle = .apa7
            },
            CommandItem(title: "Switch Citation Style to Chicago", subtitle: "Re-render all citations to Chicago Author-Date", icon: "quote.opening") {
                activeCitationStyle = .chicagoDate
            },
            CommandItem(title: "Switch Citation Style to Bluebook", subtitle: "Legal citation profile", icon: "building.columns") {
                activeCitationStyle = .bluebook
            },
            CommandItem(title: "Run Style & Tone Check", subtitle: "Lint document against active style profile", icon: "checkmark.shield") {
                runLinter()
                activePersona = .write
                showInspector = true
            }
        ]
    }

    private func runLinter() {
        lintIssues = CoreBridge.shared.lint(text: rawText, profile: "academic")
    }

    public func saveDocumentAsDocx() {
        guard let docxData = CoreBridge.shared.exportDocx(title: documentTitle, text: rawText) else {
            showToast("⚠️ Could not generate DOCX")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Word Document"
        panel.nameFieldStringValue = "\(documentTitle.replacingOccurrences(of: " ", with: "_")).docx"
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

    public func saveDocumentAsMarkdown() {
        let panel = NSSavePanel()
        panel.title = "Save Markdown"
        panel.nameFieldStringValue = "\(documentTitle.replacingOccurrences(of: " ", with: "_")).md"
        if let type = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try rawText.write(to: url, atomically: true, encoding: .utf8)
                showToast("✓ Saved \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write file: \(error.localizedDescription)")
            }
        }
    }

    private func showToast(_ msg: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                if toastMessage == msg {
                    toastMessage = nil
                }
            }
        }
    }
}
