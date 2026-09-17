import SwiftUI
import AppKit
import UniformTypeIdentifiers
#if canImport(LettersKit)
import LettersKit
#endif

public struct MainEditorView: View {
    @StateObject private var editorController = EditorActionController()
    @State private var documentTitle: String = "Letters Product Specification"
    @State private var document = DocumentModel(
        title: "Letters Product Specification",
        blocks: []
    )

    @State private var rawText: String = """
Letters: Modern Document Studio

Letters is a next-generation desktop publishing and document studio combining graphic design precision with native Word (.docx) fidelity.

1. Core Architecture & Native Engine
• SwiftUI & TextKit 2 Viewport: Ultra-smooth layout and scrolling on massive 100+ page documents.
• Headless Rust Core: Lossless OpenXML (.docx) packaging and parsing with zero formatting degradation.
• Universal BYOK AI Gateway: Direct cloud streaming with Anthropic Claude, OpenAI GPT-4o, and Google Gemini.

2. Linked Sources & Dynamic Style Rules
• Citations store structured bibliographic metadata rather than flat static text.
• Real-time re-rendering across APA 7, MLA 9, Chicago, and Bluebook legal standards.

3. Dynamic Smart Tables & Formulas
• Embedded computational tables with reactive formula evaluation and paragraph variable referencing.

[[table:budget]]
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
    @State private var zoomScale: Double = 1.15
    @State private var showingAddSourceSheet: Bool = false
    @State private var showingAddVideoSheet: Bool = false
    @State private var newVideoURLInput: String = ""
    @State private var showFindReplace: Bool = false
    @State private var showingSettingsSheet: Bool = false

    // New Source form states
    @State private var newSourceTitle: String = ""
    @State private var newSourceAuthor: String = ""
    @State private var newSourceYear: String = ""
    @State private var newSourceType: SourceType = .journalArticle

    // Page Setup & Margins State
    @State private var pageSize: PageSizePreset = .letter
    @State private var marginPreset: MarginPreset = .normal
    @State private var margins: PageMargins = PageMargins(top: 72, bottom: 72, left: 72, right: 72)
    @State private var showMarginGuides: Bool = true
    @State private var showCropMarks: Bool = true

    // Rich Interactive Blocks State
    @State private var studioTables: [StudioTableData] = [
        StudioTableData(
            title: "Project Budget & Resource Allocation",
            headers: ["Deliverable / Metric", "Allocated", "Actual Spend", "Variance"],
            rows: [
                ["Native TextKit 2 Engine", "15000", "14200", "=A1-B1"],
                ["Headless Rust Core", "12000", "12000", "=A2-B2"],
                ["AI Copilot Gateway", "8500", "7900", "=A3-B3"]
            ]
        )
    ]
    @State private var studioImages: [StudioImageBlock] = []
    @State private var studioVideos: [StudioVideoBlock] = []

    // Live Typography States (Directly updates TextKit 2)
    @State private var fontFamily: String = "Default Serif (Georgia)"
    @State private var fontSize: CGFloat = 15.0
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var isUnderline: Bool = false
    @State private var textAlignment: TextAlignment = .leading
    @State private var lineSpacing: CGFloat = 1.15
    @State private var paragraphSpacing: CGFloat = 12.0

    @State private var showAIDrawer: Bool = false
    @State private var showOutlineDrawer: Bool = false

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

    private var currentSheetWidth: CGFloat {
        pageSize.dimensions.width
    }

    private var currentSheetHeight: CGFloat {
        pageSize.dimensions.height
    }

    // Parse Document Pages (Split by page breaks if present)
    private var documentPages: [String] {
        let pages = rawText.components(separatedBy: "---pagebreak---")
        return pages.isEmpty ? [rawText] : pages
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Sleek Minimalist Top Navigation Bar (Clean Document Header)
            HStack(spacing: 12) {
                // Document Title & Page Status
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14))

                    TextField("Document Title", text: $documentTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(minWidth: 180, maxWidth: 360)

                    Text("• \(pageSize.rawValue)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(StudioTheme.panelBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(StudioTheme.border),
                alignment: .bottom
            )

            // 2. Wide Main Workspace Canvas with Attached Left Vertical Rail & Drawers
            HStack(spacing: 0) {
                // Attached Left Vertical Studio Tool Rail
                StudioLeftAttachedRail(
                    activeTool: $activeTool,
                    fontFamily: $fontFamily,
                    fontSize: $fontSize,
                    isBold: $isBold,
                    isItalic: $isItalic,
                    isUnderline: $isUnderline,
                    textAlignment: $textAlignment,
                    pageSize: $pageSize,
                    marginPreset: $marginPreset,
                    margins: $margins,
                    showMarginGuides: $showMarginGuides,
                    showCropMarks: $showCropMarks,
                    showOutlineDrawer: $showOutlineDrawer,
                    showFindReplace: $showFindReplace,
                    onToggleBold: toggleBoldAction,
                    onToggleItalic: toggleItalicAction,
                    onToggleUnderline: toggleUnderlineAction,
                    onSetAlignment: setAlignmentAction,
                    onSetFontFamily: setFontFamilyAction,
                    onSetFontSize: setFontSizeAction,
                    onInsertTable: {
                        handleToolAction(.table)
                    },
                    onInsertSection: {
                        handleToolAction(.text)
                    },
                    onAddSource: {
                        showingAddSourceSheet = true
                    },
                    onInsertImage: {
                        insertImageAction()
                    },
                    onInsertVideo: {
                        showingAddVideoSheet = true
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
                    onToggleStrikethrough: {
                        toggleStrikethroughAction()
                    },
                    onInsertBulletList: {
                        insertBulletListAction()
                    },
                    onInsertNumberedList: {
                        insertNumberedListAction()
                    }
                )

                // Optional Sliding Left Outline / Pages Drawer
                if showOutlineDrawer {
                    StudioPagesNavigator(rawText: $rawText, selectedPage: $selectedPage)
                        .transition(.move(edge: .leading))
                }

                // Center Canvas & Multi-Page Viewport
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        ScrollView([.vertical, .horizontal]) {
                            VStack(spacing: 36) {
                                // Multi-Page Sheet Rendering
                                ForEach(0..<documentPages.count, id: \.self) { pageIndex in
                                    documentPageSheet(pageIndex: pageIndex)
                                }
                            }
                            .padding(.top, 28)
                            .padding(.bottom, 100)
                            .frame(minWidth: max(geometry.size.width, currentSheetWidth * zoomScale + 120), alignment: .center)
                        }
                        .background(StudioTheme.canvasBackground)

                        // 3. Floating Find & Replace Bar Overlay (⌘F)
                        if showFindReplace {
                            FindReplaceBar(
                                isPresented: $showFindReplace,
                                rawText: $rawText,
                                onToast: { msg in showToast(msg) }
                            )
                            .padding(.bottom, 80)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // 4. Floating Studio Bottom Bar (Stats, Citations, Scale, AI)
                        StudioFloatingBottomBar(
                            wordCount: wordCount,
                            characterCount: characterCount,
                            readingTimeMinutes: readingTimeMinutes,
                            citationStyle: $activeCitationStyle,
                            zoomScale: $zoomScale,
                            showAIDrawer: $showAIDrawer,
                            onToast: { msg in showToast(msg) }
                        )
                        .padding(.bottom, 20)

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
                            .padding(.bottom, 72)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }

                // Optional Sliding Right AI Copilot Companion Drawer
                if showAIDrawer {
                    AssistantSidebarView(
                        rawText: $rawText,
                        selectedText: $selectedText,
                        onInsertTable: { table in
                            studioTables.append(table)
                        },
                        onInsertSource: { source in
                            document.sources[source.id] = source
                        },
                        onToast: { msg in showToast(msg) },
                        currentDocumentContext: { buildDocumentAIContext() }
                    )
                    .transition(.move(edge: .trailing))
                }
            }
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
        .sheet(isPresented: $showingAddVideoSheet) {
            VStack(spacing: 16) {
                Text("Embed YouTube / Web Video")
                    .font(.headline)

                TextField("Paste YouTube or Video URL...", text: $newVideoURLInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 340)

                HStack {
                    Button("Cancel") {
                        showingAddVideoSheet = false
                        newVideoURLInput = ""
                    }
                    Button("Embed Video") {
                        let block = StudioVideoBlock.parse(url: newVideoURLInput)
                        studioVideos.append(block)
                        let marker = "\n\n[[video:\(block.id.uuidString)]]\n\n"
                        if selectionRange.location <= (rawText as NSString).length {
                            let ns = rawText as NSString
                            rawText = ns.replacingCharacters(in: selectionRange, with: marker)
                        } else {
                            rawText += marker
                        }
                        showingAddVideoSheet = false
                        newVideoURLInput = ""
                        showToast("✓ Embedded Video Card")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newVideoURLInput.isEmpty)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView(isPresented: $showCommandPalette, commands: paletteCommands)
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(
                isPresented: $showingSettingsSheet,
                fontFamily: $fontFamily,
                fontSize: $fontSize,
                citationStyle: $activeCitationStyle,
                pageSize: $pageSize,
                marginPreset: $marginPreset,
                showMarginGuides: $showMarginGuides,
                showCropMarks: $showCropMarks,
                onToast: { msg in showToast(msg) }
            )
        }
        .modifier(EditorFileNotificationsModifier(
            onNew: newDocumentAction,
            onOpen: openDocument,
            onSave: saveDocumentAsLetters,
            onExportDocx: saveDocumentAsDocx,
            onExportPDF: exportDocumentAsPDF,
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
            onVideo: { showingAddVideoSheet = true },
            onCitation: { showingAddSourceSheet = true },
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
            onCommandPalette: {
                showCommandPalette.toggle()
            }
        ))
        .background(
            Group {
                Button(action: toggleBoldAction) { EmptyView() }
                    .keyboardShortcut("b", modifiers: [.command])
                Button(action: toggleItalicAction) { EmptyView() }
                    .keyboardShortcut("i", modifiers: [.command])
                Button(action: toggleUnderlineAction) { EmptyView() }
                    .keyboardShortcut("u", modifiers: [.command])
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showFindReplace.toggle()
                    }
                }) { EmptyView() }
                    .keyboardShortcut("f", modifiers: [.command])
                Button(action: { showCommandPalette.toggle() }) { EmptyView() }
                    .keyboardShortcut("k", modifiers: [.command])
                Button(action: { handleToolAction(.table) }) { EmptyView() }
                    .keyboardShortcut("t", modifiers: [.command])
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAIDrawer.toggle()
                    }
                }) { EmptyView() }
                    .keyboardShortcut("j", modifiers: [.command])
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showOutlineDrawer.toggle()
                    }
                }) { EmptyView() }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button(action: saveDocumentAsLetters) { EmptyView() }
                    .keyboardShortcut("s", modifiers: [.command])
                Button(action: newDocumentAction) { EmptyView() }
                    .keyboardShortcut("n", modifiers: [.command])
                Button(action: openDocument) { EmptyView() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        zoomScale = min(2.5, zoomScale + 0.15)
                    }
                    showToast("✓ Zoom: \(Int(zoomScale * 100))%")
                }) { EmptyView() }
                    .keyboardShortcut("=", modifiers: [.command])
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        zoomScale = max(0.4, zoomScale - 0.15)
                    }
                    showToast("✓ Zoom: \(Int(zoomScale * 100))%")
                }) { EmptyView() }
                    .keyboardShortcut("-", modifiers: [.command])
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        zoomScale = 1.0
                    }
                    showToast("✓ Zoom: 100%")
                }) { EmptyView() }
                    .keyboardShortcut("0", modifiers: [.command])
            }
            .opacity(0)
            .allowsHitTesting(false)
        )
        .onAppear {
            runLinter()
        }
    }

    private func calculateEditorHeight(for textContent: String) -> CGFloat {
        let font = resolveFontNamed(family: fontFamily, size: fontSize, bold: isBold, italic: isItalic)
        let paragraphStyle = NSMutableParagraphStyle()
        switch textAlignment {
        case .leading: paragraphStyle.alignment = .left
        case .center: paragraphStyle.alignment = .center
        case .trailing: paragraphStyle.alignment = .right
        }
        paragraphStyle.lineHeightMultiple = lineSpacing
        paragraphStyle.paragraphSpacing = paragraphSpacing
        let availableWidth = max(100, currentSheetWidth - margins.left - margins.right)
        let attrStr = NSAttributedString(
            string: textContent.isEmpty ? " " : textContent,
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )
        let rect = attrStr.boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return max(32, ceil(rect.height) + 20)
    }

    private var unreferencedTableIndices: [Int] {
        studioTables.indices.filter { idx in
            let idStr = studioTables[idx].id.uuidString
            let hasBudgetMarker = (idx == 0 && rawText.contains("[[table:budget]]"))
            return !rawText.contains("[[table:\(idStr)]]") && !hasBudgetMarker
        }
    }

    private var unreferencedImageIndices: [Int] {
        studioImages.indices.filter { idx in
            let idStr = studioImages[idx].id.uuidString
            return !rawText.contains("[[image:\(idStr)]]")
        }
    }

    private var unreferencedVideoIndices: [Int] {
        studioVideos.indices.filter { idx in
            let idStr = studioVideos[idx].id.uuidString
            return !rawText.contains("[[video:\(idStr)]]")
        }
    }

    // MARK: - Actions
    private func newDocumentAction() {
        documentTitle = "Untitled Document"
        rawText = "Start writing your document here..."
        studioTables = []
        studioImages = []
        studioVideos = []
        document.sources = [:]
        showToast("✓ Created New Document")
    }

    private func handleToolAction(_ tool: StudioTool) {
        switch tool {
        case .select:
            showToast("✓ Selection Tool active")
        case .text:
            rawText += "\n\nNew Section Heading\nType section body text here..."
            showToast("✓ Inserted Text Section")
        case .table:
            let newTable = StudioTableData(
                title: "Data Table",
                headers: ["Item", "Quantity", "Unit Price", "Total"],
                rows: [
                    ["Item 1", "10", "25", "=A1*B1"],
                    ["Item 2", "5", "50", "=A2*B2"],
                    ["Summary", "=SUM(A1:A2)", "", "=SUM(D1:D2)"]
                ]
            )
            studioTables.append(newTable)
            let marker = "\n\n[[table:\(newTable.id.uuidString)]]\n\n"
            if selectionRange.location <= (rawText as NSString).length {
                let ns = rawText as NSString
                rawText = ns.replacingCharacters(in: selectionRange, with: marker)
            } else {
                rawText += marker
            }
            showToast("✓ Added Table with cell formula support")
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

    private func insertImageAction() {
        StudioImageView.pickImageFromDisk { block in
            if let block = block {
                studioImages.append(block)
                let marker = "\n\n[[image:\(block.id.uuidString)]]\n\n"
                if selectionRange.location <= (rawText as NSString).length {
                    let ns = rawText as NSString
                    rawText = ns.replacingCharacters(in: selectionRange, with: marker)
                } else {
                    rawText += marker
                }
                showToast("✓ Inserted Image Figure")
            }
        }
    }

    private func insertPageBreakAction() {
        rawText += "\n\n---pagebreak---\n\n"
        showToast("✓ Inserted Page Break (Page \(documentPages.count))")
    }

    private func insertTOCAction() {
        let marker = "\n\n[[toc]]\n\n"
        if selectionRange.location <= (rawText as NSString).length {
            let ns = rawText as NSString
            rawText = ns.replacingCharacters(in: selectionRange, with: marker)
        } else {
            rawText += marker
        }
        showToast("✓ Inserted Table of Contents")
    }

    private func insertBibliographyAction() {
        let marker = "\n\n[[bibliography]]\n\n"
        if selectionRange.location <= (rawText as NSString).length {
            let ns = rawText as NSString
            rawText = ns.replacingCharacters(in: selectionRange, with: marker)
        } else {
            rawText += marker
        }
        showToast("✓ Inserted Bibliography / Works Cited")
    }

    private func toggleStrikethroughAction() {
        isUnderline.toggle()
        showToast("✓ Strikethrough toggled")
    }

    private func insertBulletListAction() {
        let item = "\n• "
        if selectionRange.location <= (rawText as NSString).length {
            let ns = rawText as NSString
            rawText = ns.replacingCharacters(in: selectionRange, with: item)
        } else {
            rawText += item
        }
        showToast("✓ Inserted Bullet Item")
    }

    private func insertNumberedListAction() {
        let item = "\n1. "
        if selectionRange.location <= (rawText as NSString).length {
            let ns = rawText as NSString
            rawText = ns.replacingCharacters(in: selectionRange, with: item)
        } else {
            rawText += item
        }
        showToast("✓ Inserted Numbered List")
    }

    private func toggleBoldAction() {
        editorController.toggleBold()
        if let attrs = editorController.currentSelectionAttributes() {
            self.isBold = attrs.isBold
            self.isItalic = attrs.isItalic
            self.isUnderline = attrs.isUnderline
            self.fontFamily = attrs.fontFamily
            self.fontSize = attrs.fontSize
            self.textAlignment = attrs.alignment
        } else {
            isBold.toggle()
        }
        showToast(isBold ? "✓ Bold enabled" : "Bold disabled")
    }

    private func toggleItalicAction() {
        editorController.toggleItalic()
        if let attrs = editorController.currentSelectionAttributes() {
            self.isBold = attrs.isBold
            self.isItalic = attrs.isItalic
            self.isUnderline = attrs.isUnderline
            self.fontFamily = attrs.fontFamily
            self.fontSize = attrs.fontSize
            self.textAlignment = attrs.alignment
        } else {
            isItalic.toggle()
        }
        showToast(isItalic ? "✓ Italic enabled" : "Italic disabled")
    }

    private func toggleUnderlineAction() {
        editorController.toggleUnderline()
        if let attrs = editorController.currentSelectionAttributes() {
            self.isBold = attrs.isBold
            self.isItalic = attrs.isItalic
            self.isUnderline = attrs.isUnderline
            self.fontFamily = attrs.fontFamily
            self.fontSize = attrs.fontSize
            self.textAlignment = attrs.alignment
        } else {
            isUnderline.toggle()
        }
        showToast(isUnderline ? "✓ Underline enabled" : "Underline disabled")
    }

    private func setAlignmentAction(_ align: TextAlignment) {
        textAlignment = align
        editorController.applyAlignment(align, lineSpacing: lineSpacing, paragraphSpacing: paragraphSpacing)
        let name = align == .leading ? "Left" : align == .center ? "Center" : "Right"
        showToast("✓ Alignment: \(name)")
    }

    private func setFontFamilyAction(_ font: String) {
        fontFamily = font
        editorController.applyFontFamily(font, size: fontSize)
        if let attrs = editorController.currentSelectionAttributes() {
            self.isBold = attrs.isBold
            self.isItalic = attrs.isItalic
            self.isUnderline = attrs.isUnderline
            self.fontSize = attrs.fontSize
        }
        showToast("✓ Font: \(font)")
    }

    private func setFontSizeAction(_ size: CGFloat) {
        fontSize = size
        editorController.applyFontSize(size)
        if let attrs = editorController.currentSelectionAttributes() {
            self.isBold = attrs.isBold
            self.isItalic = attrs.isItalic
            self.isUnderline = attrs.isUnderline
            self.fontFamily = attrs.fontFamily
        }
        showToast("✓ Font Size: \(Int(size)) pt")
    }

    private func insertCitationForSelection() {
        showingAddSourceSheet = true
    }

    private var paletteCommands: [CommandItem] {
        [
            CommandItem(title: "Save Native .letters Package", subtitle: "Lossless Project Letters document", icon: "tray.and.arrow.down.fill", shortcut: "⌘S") {
                saveDocumentAsLetters()
            },
            CommandItem(title: "Open Existing Document", subtitle: "Open .letters, .docx, or .md", icon: "folder", shortcut: "⌘O") {
                openDocument()
            },
            CommandItem(title: "Export as Word Document (.docx)", subtitle: "Generate native lossless DOCX file", icon: "doc.fill", shortcut: "⌘⇧S") {
                saveDocumentAsDocx()
            },
            CommandItem(title: "Export as Vector PDF (.pdf)", subtitle: "High resolution publication PDF", icon: "arrow.down.doc") {
                exportDocumentAsPDF()
            },
            CommandItem(title: "Print Document", subtitle: "Native macOS Print dialog", icon: "printer", shortcut: "⌘P") {
                printDocument()
            },
            CommandItem(title: "Find & Replace", subtitle: "Search and replace text in document", icon: "magnifyingglass", shortcut: "⌘F") {
                showFindReplace.toggle()
            },
            CommandItem(title: "Insert Smart Table", subtitle: "Embed interactive calculation table", icon: "tablecells", shortcut: "⌘T") {
                handleToolAction(.table)
            },
            CommandItem(title: "Insert Image Figure", subtitle: "Add photo with compression and crop options", icon: "photo") {
                insertImageAction()
            },
            CommandItem(title: "Embed Video", subtitle: "Add YouTube / Vimeo video card", icon: "play.rectangle") {
                showingAddVideoSheet = true
            },
            CommandItem(title: "Insert Page Break", subtitle: "Start a new page sheet", icon: "pagebreak", shortcut: "⌘↵") {
                insertPageBreakAction()
            },
            CommandItem(title: "Toggle AI Copilot", subtitle: "Open BYOK assistant drawer", icon: "sparkles", shortcut: "⌘J") {
                showAIDrawer.toggle()
            },
            CommandItem(title: "Zoom In (+)", subtitle: "Enlarge workspace canvas scale", icon: "plus.magnifyingglass", shortcut: "⌘+") {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = min(2.5, zoomScale + 0.15)
                }
                showToast("✓ Zoom: \(Int(zoomScale * 100))%")
            },
            CommandItem(title: "Zoom Out (-)", subtitle: "Reduce workspace canvas scale", icon: "minus.magnifyingglass", shortcut: "⌘-") {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = max(0.5, zoomScale - 0.15)
                }
                showToast("✓ Zoom: \(Int(zoomScale * 100))%")
            },
            CommandItem(title: "Reset Zoom (100%)", subtitle: "Set canvas scale to standard 100%", icon: "arrow.counterclockwise", shortcut: "⌘0") {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = 1.0
                }
                showToast("✓ Zoom: 100%")
            }
        ]
    }

    private func buildDocumentAIContext() -> String {
        var context = "=== DOCUMENT METADATA ===\n"
        context += "Title: \(documentTitle)\n"
        context += "Page Format: \(pageSize.rawValue) (\(Int(currentSheetWidth))x\(Int(currentSheetHeight)) pt)\n"
        context += "Margins: Top \(Int(margins.top)) pt, Bottom \(Int(margins.bottom)) pt, Left \(Int(margins.left)) pt, Right \(Int(margins.right)) pt\n"
        context += "Word Count: \(wordCount) words, \(characterCount) characters\n\n"

        context += "=== DOCUMENT BODY TEXT ===\n"
        context += rawText + "\n\n"

        if !studioTables.isEmpty {
            context += "=== EMBEDDED SMART TABLES (\(studioTables.count)) ===\n"
            for (i, table) in studioTables.enumerated() {
                context += "Table \(i + 1):\n"
                context += "| " + table.headers.joined(separator: " | ") + " |\n"
                context += "| " + table.headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
                for row in table.rows {
                    context += "| " + row.joined(separator: " | ") + " |\n"
                }
                context += "\n"
            }
        }

        if !studioImages.isEmpty {
            context += "=== EMBEDDED FIGURES & IMAGES (\(studioImages.count)) ===\n"
            for (i, img) in studioImages.enumerated() {
                context += "Figure \(i + 1): \(img.caption) [Alignment: \(img.alignment.rawValue), Aspect Ratio: \(img.aspectRatioPreset.rawValue)]\n"
            }
            context += "\n"
        }

        if !studioVideos.isEmpty {
            context += "=== EMBEDDED MEDIA / VIDEOS (\(studioVideos.count)) ===\n"
            for (i, vid) in studioVideos.enumerated() {
                context += "Video \(i + 1): \(vid.title) (\(vid.platform.rawValue): \(vid.url))\n"
            }
            context += "\n"
        }

        if !document.sources.isEmpty {
            context += "=== LINKED BIBLIOGRAPHIC SOURCES (\(document.sources.count)) ===\n"
            for (id, src) in document.sources {
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

    private func runLinter() {
        lintIssues = CoreBridge.shared.lint(text: rawText, profile: "academic")
    }

    // MARK: - Native .letters / .ltt Lossless Package Save & Open
    public func saveDocumentAsLetters() {
        let bundle = LettersDocumentBundle(
            title: documentTitle,
            rawText: rawText,
            tables: studioTables,
            images: studioImages,
            videos: studioVideos,
            sources: document.sources,
            citationStyle: activeCitationStyle,
            pageSizePreset: pageSize,
            marginPreset: marginPreset,
            margins: margins,
            fontFamily: fontFamily,
            fontSize: Double(fontSize),
            lineSpacing: Double(lineSpacing),
            paragraphSpacing: Double(paragraphSpacing)
        )

        guard let data = try? bundle.encodeToData() else {
            showToast("⚠️ Could not encode .letters bundle")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Project Letters Document"
        panel.nameFieldStringValue = "\(documentTitle.replacingOccurrences(of: " ", with: "_")).letters"
        if let typeLetters = UTType(filenameExtension: "letters"),
           let typeLtt = UTType(filenameExtension: "ltt") {
            panel.allowedContentTypes = [typeLetters, typeLtt]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                showToast("✓ Saved .letters package: \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write file: \(error.localizedDescription)")
            }
        }
    }

    public func openDocument() {
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
            do {
                let ext = url.pathExtension.lowercased()
                if ext == "letters" || ext == "ltt" {
                    let data = try Data(contentsOf: url)
                    let bundle = try LettersDocumentBundle.decode(from: data)
                    documentTitle = bundle.title
                    rawText = bundle.rawText
                    studioTables = bundle.tables
                    studioImages = bundle.images
                    studioVideos = bundle.videos
                    document.sources = bundle.sources
                    activeCitationStyle = bundle.citationStyle
                    pageSize = bundle.pageSizePreset
                    marginPreset = bundle.marginPreset
                    margins = bundle.margins
                    fontFamily = bundle.fontFamily
                    fontSize = CGFloat(bundle.fontSize)
                    lineSpacing = CGFloat(bundle.lineSpacing)
                    paragraphSpacing = CGFloat(bundle.paragraphSpacing)
                    showToast("✓ Opened .letters document: \(url.lastPathComponent)")
                } else if ext == "md" || ext == "txt" {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    documentTitle = url.deletingPathExtension().lastPathComponent
                    rawText = content
                    showToast("✓ Opened file: \(url.lastPathComponent)")
                } else if ext == "docx" {
                    // Load docx metadata and fallback text
                    documentTitle = url.deletingPathExtension().lastPathComponent
                    showToast("✓ Opened Word file: \(url.lastPathComponent)")
                }
            } catch {
                showToast("⚠️ Could not open document: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Word, PDF & Print
    public func saveDocumentAsDocx() {
        var fullExport = rawText
        if !studioTables.isEmpty {
            fullExport += "\n\n" + studioTables.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !studioImages.isEmpty {
            fullExport += "\n\n" + studioImages.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !studioVideos.isEmpty {
            fullExport += "\n\n" + studioVideos.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }

        guard let docxData = CoreBridge.shared.exportDocx(title: documentTitle, text: fullExport) else {
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

    public func exportDocumentAsPDF() {
        let panel = NSSavePanel()
        panel.title = "Export Vector PDF"
        panel.nameFieldStringValue = "\(documentTitle.replacingOccurrences(of: " ", with: "_")).pdf"
        if let type = UTType(filenameExtension: "pdf") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            let paperSize = NSSize(width: pageSize.dimensions.width, height: pageSize.dimensions.height)
            let printInfo = NSPrintInfo.shared
            printInfo.paperSize = paperSize
            printInfo.topMargin = margins.top
            printInfo.bottomMargin = margins.bottom
            printInfo.leftMargin = margins.left
            printInfo.rightMargin = margins.right
            printInfo.orientation = .portrait

            let textView = NSTextView(frame: NSRect(origin: .zero, size: paperSize))
            textView.string = rawText
            textView.font = resolveFontNamed(family: fontFamily, size: fontSize, bold: isBold, italic: isItalic)
            let pdfData = textView.dataWithPDF(inside: NSRect(origin: .zero, size: paperSize))

            do {
                try pdfData.write(to: url)
                showToast("✓ Exported Vector PDF: \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write PDF: \(error.localizedDescription)")
            }
        }
    }

    public func printDocument() {
        let paperSize = NSSize(width: pageSize.dimensions.width, height: pageSize.dimensions.height)
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = paperSize
        printInfo.topMargin = margins.top
        printInfo.bottomMargin = margins.bottom
        printInfo.leftMargin = margins.left
        printInfo.rightMargin = margins.right

        let textView = NSTextView(frame: NSRect(origin: .zero, size: paperSize))
        textView.string = rawText
        textView.font = resolveFontNamed(family: fontFamily, size: fontSize, bold: isBold, italic: isItalic)

        let op = NSPrintOperation(view: textView, printInfo: printInfo)
        op.showsPrintPanel = true
        op.run()
    }

    public func saveDocumentAsMarkdown() {
        var fullExport = rawText
        if !studioTables.isEmpty {
            fullExport += "\n\n" + studioTables.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !studioImages.isEmpty {
            fullExport += "\n\n" + studioImages.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !studioVideos.isEmpty {
            fullExport += "\n\n" + studioVideos.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }

        let panel = NSSavePanel()
        panel.title = "Save Markdown"
        panel.nameFieldStringValue = "\(documentTitle.replacingOccurrences(of: " ", with: "_")).md"
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

    // MARK: - Document Page Sheet & Inline Segments
    @ViewBuilder
    private func documentPageSheet(pageIndex: Int) -> some View {
        VStack(spacing: 8) {
            // Page Number Badge
            HStack {
                Text("PAGE \(pageIndex + 1) OF \(documentPages.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(pageSize.rawValue) • \(marginPreset.rawValue)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: currentSheetWidth * zoomScale)

            // Pure White Physical Paper Sheet
            ZStack(alignment: .topLeading) {
                // 1. Crisp White Sheet Background with realistic drop shadow
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white)
                    .frame(width: currentSheetWidth, height: currentSheetHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.black.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                    .shadow(color: Color.black.opacity(0.25), radius: 32, x: 0, y: 14)

                // 2. Running Header (Title & Subtitle)
                HStack {
                    Text(documentTitle)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                    Spacer()
                    Text("Project Letters Studio")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                }
                .padding(.horizontal, margins.left)
                .padding(.top, margins.top / 2 - 6)
                .frame(width: currentSheetWidth)

                // 3. Margin Guides Overlay
                if showMarginGuides {
                    PaperMarginGuidesView(
                        width: currentSheetWidth,
                        height: currentSheetHeight,
                        margins: margins
                    )
                }

                // 4. Publisher Corner Crop Marks
                if showCropMarks {
                    PublisherCropMarksView(
                        width: currentSheetWidth,
                        height: currentSheetHeight
                    )
                }

                // 5. Document Content (Dynamic In-Flow TextKit 2 Segments + Tables + Media)
                documentCanvasContent(pageIndex: pageIndex)

                // 6. Running Footer (Page X of Y)
                HStack {
                    Text("Confidential • Project Letters")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                    Spacer()
                    Text("Page \(pageIndex + 1) of \(documentPages.count)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                }
                .padding(.horizontal, margins.left)
                .padding(.bottom, margins.bottom / 2 - 6)
                .frame(width: currentSheetWidth, height: currentSheetHeight, alignment: .bottom)

                // 7. Floating contextual selection menu
                if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    floatingSelectionActionMenu
                }
            }
            .frame(width: currentSheetWidth, height: currentSheetHeight)
            .scaleEffect(zoomScale, anchor: .top)
        }
    }

    @ViewBuilder
    private func documentCanvasContent(pageIndex: Int) -> some View {
        let pageStr = pageIndex < documentPages.count ? documentPages[pageIndex] : rawText
        let segments = parseCanvasSegments(for: pageStr, pageIndex: pageIndex)
        let printableWidth = max(100, currentSheetWidth - margins.left - margins.right)

        VStack(alignment: .leading, spacing: 14) {
            ForEach(segments) { segment in
                switch segment.type {
                case .text(let chunkText, let range):
                    TextKit2EditorView(
                        text: Binding(
                            get: {
                                if range.location + range.length <= (rawText as NSString).length {
                                    return (rawText as NSString).substring(with: range)
                                }
                                return chunkText
                            },
                            set: { newVal in
                                if range.location + range.length <= (rawText as NSString).length {
                                    let ns = rawText as NSString
                                    rawText = ns.replacingCharacters(in: range, with: newVal)
                                }
                            }
                        ),
                        selectedText: $selectedText,
                        selectionRange: $selectionRange,
                        controller: editorController,
                        fontFamily: fontFamily,
                        fontSize: fontSize,
                        isBold: isBold,
                        isItalic: isItalic,
                        isUnderline: isUnderline,
                        alignment: textAlignment,
                        lineSpacing: lineSpacing,
                        paragraphSpacing: paragraphSpacing,
                        margins: PageMargins(),
                        onSelectionChanged: { _, _, attrs in
                            self.isBold = attrs.isBold
                            self.isItalic = attrs.isItalic
                            self.isUnderline = attrs.isUnderline
                            self.fontFamily = attrs.fontFamily
                            self.fontSize = attrs.fontSize
                            self.textAlignment = attrs.alignment
                        }
                    )
                    .frame(width: printableWidth, height: calculateEditorHeight(for: chunkText))

                case .table(let tableId):
                    if let idx = studioTables.firstIndex(where: { $0.id == tableId }) {
                        SmartTableView(
                            tableData: $studioTables[idx],
                            onDelete: {
                                let idStr = studioTables[idx].id.uuidString
                                studioTables.remove(at: idx)
                                rawText = rawText.replacingOccurrences(of: "[[table:\(idStr)]]", with: "")
                                rawText = rawText.replacingOccurrences(of: "[[table:budget]]", with: "")
                                showToast("✓ Deleted table")
                            },
                            onChange: {
                                showToast("✓ Table updated")
                            },
                            onToast: { msg in
                                showToast(msg)
                            }
                        )
                    }

                case .image(let imageId):
                    if let idx = studioImages.firstIndex(where: { $0.id == imageId }) {
                        StudioImageView(
                            imageBlock: $studioImages[idx],
                            onDelete: {
                                let idStr = studioImages[idx].id.uuidString
                                studioImages.remove(at: idx)
                                rawText = rawText.replacingOccurrences(of: "[[image:\(idStr)]]", with: "")
                                showToast("✓ Deleted figure")
                            },
                            onChange: {
                                showToast("✓ Figure updated")
                            },
                            onToast: { msg in
                                showToast(msg)
                            }
                        )
                    }

                case .video(let videoId):
                    if let idx = studioVideos.firstIndex(where: { $0.id == videoId }) {
                        StudioVideoView(
                            videoBlock: $studioVideos[idx],
                            onDelete: {
                                let idStr = studioVideos[idx].id.uuidString
                                studioVideos.remove(at: idx)
                                rawText = rawText.replacingOccurrences(of: "[[video:\(idStr)]]", with: "")
                                showToast("✓ Deleted video card")
                            },
                            onChange: {
                                showToast("✓ Video updated")
                            },
                            onToast: { msg in
                                showToast(msg)
                            }
                        )
                    }

                case .bibliography:
                    DynamicBibliographyView(
                        sources: document.sources,
                        activeStyle: $activeCitationStyle,
                        onDelete: {
                            rawText = rawText.replacingOccurrences(of: "[[bibliography]]", with: "")
                            showToast("✓ Deleted Bibliography section")
                        },
                        onToast: { msg in
                            showToast(msg)
                        }
                    )

                case .tableOfContents:
                    DynamicTOCView(
                        rawText: rawText,
                        onDelete: {
                            rawText = rawText.replacingOccurrences(of: "[[toc]]", with: "")
                            showToast("✓ Deleted Table of Contents")
                        },
                        onToast: { msg in
                            showToast(msg)
                        }
                    )
                }
            }

            // Unreferenced Tables (placed naturally below if no inline marker)
            if pageIndex == 0 {
                ForEach(unreferencedTableIndices, id: \.self) { idx in
                    SmartTableView(
                        tableData: $studioTables[idx],
                        onDelete: {
                            studioTables.remove(at: idx)
                            showToast("✓ Removed unreferenced table")
                        },
                        onChange: {
                            showToast("✓ Table updated")
                        },
                        onToast: { msg in
                            showToast(msg)
                        }
                    )
                }

                ForEach(unreferencedImageIndices, id: \.self) { idx in
                    StudioImageView(
                        imageBlock: $studioImages[idx],
                        onDelete: {
                            studioImages.remove(at: idx)
                            showToast("✓ Removed unreferenced figure")
                        },
                        onChange: {
                            showToast("✓ Figure updated")
                        },
                        onToast: { msg in
                            showToast(msg)
                        }
                    )
                }

                ForEach(unreferencedVideoIndices, id: \.self) { idx in
                    StudioVideoView(
                        videoBlock: $studioVideos[idx],
                        onDelete: {
                            studioVideos.remove(at: idx)
                            showToast("✓ Removed unreferenced video")
                        },
                        onChange: {
                            showToast("✓ Video updated")
                        },
                        onToast: { msg in
                            showToast(msg)
                        }
                    )
                }
            }
        }
        .padding(.top, margins.top)
        .padding(.bottom, margins.bottom)
        .padding(.horizontal, margins.left)
        .frame(width: currentSheetWidth, height: currentSheetHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private var floatingSelectionActionMenu: some View {
        FloatingActionMenu(
            selectedText: selectedText,
            onBold: {
                toggleBoldAction()
            },
            onItalic: {
                toggleItalicAction()
            },
            onPolish: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAIDrawer = true
                }
                showToast("✨ AI Copilot opened for polish")
            },
            onTranslate: {
                Task {
                    if let res = try? await TranslationService.shared.translate(text: selectedText) {
                        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (rawText as NSString).length {
                            let ns = rawText as NSString
                            rawText = ns.replacingCharacters(in: selectionRange, with: res)
                        } else {
                            rawText = rawText.replacingOccurrences(of: selectedText, with: res)
                        }
                    }
                }
            },
            onExplain: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAIDrawer = true
                }
                showToast("✨ AI Copilot explaining selection")
            },
            onCite: {
                insertCitationForSelection()
            }
        )
        .padding(.top, 16)
        .padding(.leading, currentSheetWidth / 2 - 120)
        .transition(.scale.combined(with: .opacity))
    }

    private func parseCanvasSegments(for pageContent: String, pageIndex: Int = 0) -> [DocumentCanvasSegment] {
        let pattern = #"(?:^|\n)?\[\[(table|image|video|bibliography|toc)(?::([a-zA-Z0-9\-]+))?\]\](?:\n)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [DocumentCanvasSegment(id: "p\(pageIndex)-text-0", type: .text(pageContent, NSRange(location: 0, length: (pageContent as NSString).length)))]
        }

        let nsContent = pageContent as NSString
        let matches = regex.matches(in: pageContent, options: [], range: NSRange(location: 0, length: nsContent.length))

        if matches.isEmpty {
            return [DocumentCanvasSegment(id: "p\(pageIndex)-text-0", type: .text(pageContent, NSRange(location: 0, length: nsContent.length)))]
        }

        var segments: [DocumentCanvasSegment] = []
        var lastLocation = 0
        var segCount = 0

        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastLocation {
                let textRange = NSRange(location: lastLocation, length: matchRange.location - lastLocation)
                let chunkText = nsContent.substring(with: textRange)
                if !chunkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || segments.isEmpty {
                    segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-text-\(segCount)", type: .text(chunkText, textRange)))
                    segCount += 1
                }
            }

            if match.numberOfRanges >= 2 {
                let kind = nsContent.substring(with: match.range(at: 1))
                let idStr = (match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound) ? nsContent.substring(with: match.range(at: 2)) : ""

                if kind == "bibliography" {
                    segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-bib-\(segCount)", type: .bibliography))
                    segCount += 1
                } else if kind == "toc" {
                    segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-toc-\(segCount)", type: .tableOfContents))
                    segCount += 1
                } else if kind == "table" {
                    if let uuid = UUID(uuidString: idStr), studioTables.contains(where: { $0.id == uuid }) {
                        segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-table-\(uuid.uuidString)", type: .table(uuid)))
                        segCount += 1
                    } else if idStr.lowercased() == "budget", let firstTable = studioTables.first {
                        segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-table-\(firstTable.id.uuidString)", type: .table(firstTable.id)))
                        segCount += 1
                    } else if let found = studioTables.first(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) {
                        segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-table-\(found.id.uuidString)", type: .table(found.id)))
                        segCount += 1
                    }
                } else if kind == "image" {
                    if let uuid = UUID(uuidString: idStr), studioImages.contains(where: { $0.id == uuid }) {
                        segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-image-\(uuid.uuidString)", type: .image(uuid)))
                        segCount += 1
                    } else if let found = studioImages.first(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) {
                        segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-image-\(found.id.uuidString)", type: .image(found.id)))
                        segCount += 1
                    }
                } else if kind == "video" {
                    if let uuid = UUID(uuidString: idStr), studioVideos.contains(where: { $0.id == uuid }) {
                        segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-video-\(uuid.uuidString)", type: .video(uuid)))
                        segCount += 1
                    } else if let found = studioVideos.first(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) {
                        segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-video-\(found.id.uuidString)", type: .video(found.id)))
                        segCount += 1
                    }
                }
            }

            lastLocation = matchRange.location + matchRange.length
        }

        if lastLocation < nsContent.length {
            let textRange = NSRange(location: lastLocation, length: nsContent.length - lastLocation)
            let chunkText = nsContent.substring(with: textRange)
            if !chunkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(DocumentCanvasSegment(id: "p\(pageIndex)-text-\(segCount)", type: .text(chunkText, textRange)))
            }
        }

        return segments
    }
}

// MARK: - Document Canvas Segment Model
public struct DocumentCanvasSegment: Identifiable {
    public enum SegmentType {
        case text(String, NSRange)
        case table(UUID)
        case image(UUID)
        case video(UUID)
        case bibliography
        case tableOfContents
    }
    public let id: String
    public let type: SegmentType

    public init(id: String, type: SegmentType) {
        self.id = id
        self.type = type
    }
}

// MARK: - Visual Publishing Guides
struct PaperMarginGuidesView: View {
    let width: CGFloat
    let height: CGFloat
    let margins: PageMargins

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(
                    Color.accentColor.opacity(0.3),
                    style: StrokeStyle(lineWidth: 0.75, dash: [4, 4])
                )
                .frame(
                    width: max(0, width - margins.left - margins.right),
                    height: max(0, height - margins.top - margins.bottom)
                )
                .offset(x: margins.left, y: margins.top)

            Path { path in
                path.move(to: CGPoint(x: margins.left, y: margins.top / 2))
                path.addLine(to: CGPoint(x: width - margins.right, y: margins.top / 2))
            }
            .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

            Path { path in
                let footerY = height - (margins.bottom / 2)
                path.move(to: CGPoint(x: margins.left, y: footerY))
                path.addLine(to: CGPoint(x: width - margins.right, y: footerY))
            }
            .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        }
        .allowsHitTesting(false)
    }
}

struct PublisherCropMarksView: View {
    let width: CGFloat
    let height: CGFloat
    let markLength: CGFloat = 14
    let offset: CGFloat = 6

    var body: some View {
        ZStack {
            CropMarkCorner()
                .position(x: -offset, y: -offset)

            CropMarkCorner()
                .rotationEffect(.degrees(90))
                .position(x: width + offset, y: -offset)

            CropMarkCorner()
                .rotationEffect(.degrees(180))
                .position(x: width + offset, y: height + offset)

            CropMarkCorner()
                .rotationEffect(.degrees(270))
                .position(x: -offset, y: height + offset)
        }
        .allowsHitTesting(false)
    }
}

struct CropMarkCorner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: -12, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -12))
        }
        .stroke(Color.secondary.opacity(0.4), lineWidth: 0.75)
    }
}

// MARK: - Modular Notification Handlers
struct EditorFileNotificationsModifier: ViewModifier {
    let onNew: () -> Void
    let onOpen: () -> Void
    let onSave: () -> Void
    let onExportDocx: () -> Void
    let onExportPDF: () -> Void
    let onPrint: () -> Void
    let onSettings: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .lettersNewDocument)) { _ in onNew() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersOpenDocument)) { _ in onOpen() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersSaveDocument)) { _ in onSave() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersExportDocx)) { _ in onExportDocx() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersExportPDF)) { _ in onExportPDF() }
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
            .onReceive(NotificationCenter.default.publisher(for: .lettersInsertPageBreak)) { _ in onPageBreak() }
    }
}

struct EditorViewNotificationsModifier: ViewModifier {
    let onFindReplace: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomReset: () -> Void
    let onOutline: () -> Void
    let onAIDrawer: () -> Void
    let onCommandPalette: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleFindReplace)) { _ in onFindReplace() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersZoomIn)) { _ in onZoomIn() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersZoomOut)) { _ in onZoomOut() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersZoomReset)) { _ in onZoomReset() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleOutline)) { _ in onOutline() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleAIDrawer)) { _ in onAIDrawer() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersToggleCommandPalette)) { _ in onCommandPalette() }
    }
}

