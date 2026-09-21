import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

public struct MainEditorView: View {
    @StateObject private var editorController = EditorActionController()
    @StateObject private var documentController = LettersDocumentController()
    
    @State private var activeTool: StudioTool = .select
    @State private var activePersona: StudioPersona = .write
    @State private var selectedPage: Int = 1
    @State private var selectedText: String = ""
    @State private var selectionRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showInspector: Bool = true
    @State private var showCommandPalette: Bool = false
    @State private var lintIssues: [StyleLintMatch] = []
    @State private var toastMessage: String? = nil
    @State private var zoomScale: Double = 1.15
    @State private var showingAddSourceSheet: Bool = false
    @State private var showingAddVideoSheet: Bool = false
    @State private var newVideoURLInput: String = ""
    @State private var showFindReplace: Bool = false
    @State private var showInlineAI: Bool = false
    @State private var showingSettingsSheet: Bool = false

    // New Source form states
    @State private var newSourceTitle: String = ""
    @State private var newSourceAuthor: String = ""
    @State private var newSourceYear: String = ""
    @State private var newSourceType: SourceType = .journalArticle

    // Page Setup & Margins State
    @State private var showMarginGuides: Bool = true
    @State private var showCropMarks: Bool = true

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

    @State private var showAIDrawer: Bool = false
    @State private var showOutlineDrawer: Bool = false

    // Modern Dark Floating Island & Cover Banner States
        @State private var showIslandSidebar: Bool = true
    @State private var showDocumentTimeline: Bool = false
    @State private var showPageDesignInspector: Bool = false

    public init() {}

    private var wordCount: Int {
        EditorPerformanceCache.countWords(in: documentController.rawText)
    }

    private var characterCount: Int {
        documentController.rawText.count
    }

    private var readingTimeMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 200.0)))
    }

    private var currentSheetWidth: CGFloat {
        documentController.pageSize.dimensions.width
    }

    private var currentSheetHeight: CGFloat {
        documentController.pageSize.dimensions.height
    }

    // Dynamic Document Page Slicing (Continuous flow across physical sheets + explicit pagebreaks)
    private var documentPageSlices: [DocumentPageSlice] {
        DocumentPaginator.paginate(
            rawText: documentController.rawText,
            richTextData: documentController.richTextData,
            sheetHeight: currentSheetHeight,
            sheetWidth: currentSheetWidth,
            margins: documentController.margins,
            fontFamily: documentController.fontFamily,
            fontSize: documentController.fontSize,
            isBold: isBold,
            isItalic: isItalic,
            lineSpacing: documentController.lineSpacing,
            paragraphSpacing: documentController.paragraphSpacing,
            alignment: documentController.textAlignment
        )
    }

    private var documentPages: [String] {
        documentPageSlices.map { $0.text }
    }

    private func getPageText(pageIndex: Int) -> String {
        let slices = documentPageSlices
        guard pageIndex < slices.count else { return "" }
        return slices[pageIndex].text
    }

    private func getPageAttributedText(pageIndex: Int) -> NSAttributedString? {
        let slices = documentPageSlices
        guard pageIndex < slices.count else { return nil }
        return slices[pageIndex].attributedText
    }

    private func getPageSliceRange(pageIndex: Int) -> NSRange? {
        let slices = documentPageSlices
        guard pageIndex < slices.count else { return nil }
        return slices[pageIndex].range
    }

    private func setPageText(pageIndex: Int, newText: String) {
        if let activeSize = editorController.currentSelectionAttributes()?.fontSize,
           activeSize > 0,
           abs(activeSize - documentController.fontSize) > 0.5,
           !documentController.rawText.contains("# ") {
            documentController.fontSize = activeSize
        }

        let oldPageCount = documentPageSlices.count
        let slices = documentPageSlices
        guard pageIndex < slices.count else {
            documentController.rawText += (documentController.rawText.isEmpty ? "" : "\n\n") + newText
            return
        }
        let slice = slices[pageIndex]
        let ns = documentController.rawText as NSString
        let loc = slice.range.location
        let len = slice.range.length
        if loc <= ns.length && loc + len <= ns.length {
            documentController.rawText = ns.replacingCharacters(in: slice.range, with: newText)
        } else {
            documentController.rawText = newText
        }

        let newSlices = documentPageSlices
        if newSlices.count > pageIndex + 1 && newText.count > newSlices[pageIndex].text.count {
            let overflowLength = max(1, newText.count - newSlices[pageIndex].text.count)
            editorController.focusPage(pageIndex + 1, at: overflowLength)
        } else if newSlices.count > oldPageCount && pageIndex + 1 < newSlices.count {
            editorController.focusPage(pageIndex + 1, at: 0)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Sleek Minimalist Glass Top Navigation Bar
            HStack(spacing: 16) {
                // Left Island Sidebar Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showIslandSidebar.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(showIslandSidebar ? .accentColor : .primary.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(showIslandSidebar ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                        .symbolEffect(.bounce, value: showIslandSidebar)
                }
                .buttonStyle(.plain)
                .help("Toggle Instruments Toolbar (⌥⌘1)")

                // Document Title
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))

                    TextField("Document Title", text: $documentController.title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(minWidth: 140, maxWidth: 220)
                }
                
                Divider().frame(height: 20)

                // Word-Style Font Formatting Controls
                HStack(spacing: 8) {
                    // Font Family
                    Menu {
                        ForEach(["System", "Georgia", "Helvetica Neue", "Times New Roman", "Menlo", "Courier New", "Avenir Next", "Baskerville", "Palatino", "Charter"], id: \.self) { fam in
                            Button(fam) { setFontFamilyAction(fam) }
                        }
                    } label: {
                        HStack {
                            Text(selectionAttributes?.fontFamily ?? documentController.fontFamily)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 100, alignment: .leading)
                            Image(systemName: "chevron.down").font(.system(size: 10))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06)).cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Font Size
                    HStack(spacing: 2) {
                        Button(action: { setFontSizeAction((selectionAttributes?.fontSize ?? documentController.fontSize) - 1) }) {
                            Image(systemName: "minus")
                        }.frame(width: 24, height: 26).background(Color.primary.opacity(0.06)).cornerRadius(4)
                        
                        Text("\(Int(selectionAttributes?.fontSize ?? documentController.fontSize))")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, alignment: .center)
                            
                        Button(action: { setFontSizeAction((selectionAttributes?.fontSize ?? documentController.fontSize) + 1) }) {
                            Image(systemName: "plus")
                        }.frame(width: 24, height: 26).background(Color.primary.opacity(0.06)).cornerRadius(4)
                    }.buttonStyle(.plain)
                    
                    Divider().frame(height: 16)
                    
                    // Bold, Italic, Underline
                    Button(action: { toggleBoldAction() }) {
                        Image(systemName: "b.square")
                            .font(.system(size: 15, weight: (selectionAttributes?.isBold ?? isBold) ? .bold : .regular))
                            .foregroundColor((selectionAttributes?.isBold ?? isBold) ? .accentColor : .primary)
                    }.buttonStyle(.plain)
                    Button(action: { toggleItalicAction() }) {
                        Image(systemName: "i.square")
                            .font(.system(size: 15, weight: (selectionAttributes?.isItalic ?? isItalic) ? .bold : .regular))
                            .foregroundColor((selectionAttributes?.isItalic ?? isItalic) ? .accentColor : .primary)
                    }.buttonStyle(.plain)
                    Button(action: { toggleUnderlineAction() }) {
                        Image(systemName: "u.square")
                            .font(.system(size: 15, weight: (selectionAttributes?.isUnderline ?? isUnderline) ? .bold : .regular))
                            .foregroundColor((selectionAttributes?.isUnderline ?? isUnderline) ? .accentColor : .primary)
                    }.buttonStyle(.plain)
                    
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
                            .font(.system(size: 15))
                            .padding(6)
                            .background(Color.primary.opacity(0.06)).cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Quick Action Center (AI, Timeline, Command)
                HStack(spacing: 12) {
                    // Timeline
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showDocumentTimeline.toggle()
                        }
                    }) {
                        Image(systemName: showDocumentTimeline ? "chart.bar.doc.horizontal.fill" : "chart.bar.doc.horizontal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(showDocumentTimeline ? StudioTheme.luminousCyan : .primary)
                            .padding(8)
                            .background(showDocumentTimeline ? StudioTheme.luminousCyan.opacity(0.18) : Color.primary.opacity(0.06))
                            .cornerRadius(8)
                            .symbolEffect(.bounce, value: showDocumentTimeline)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Reading Flow Timeline (⌥⌘T)")
                    
                    // AI Copilot Toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAIDrawer.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Copilot")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(showAIDrawer ? StudioTheme.luminousPurple.opacity(0.2) : Color.primary.opacity(0.06))
                        .foregroundColor(showAIDrawer ? StudioTheme.luminousPurple : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    // Command Center Button
                    Button(action: { showCommandPalette.toggle() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .padding(8)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
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

            // 2. Wide Main Workspace Canvas with Floating Islands & Timeline
            HStack(spacing: 0) {
                // Center Canvas & Multi-Page Viewport
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        ScrollView([.vertical, .horizontal]) {
                            VStack(spacing: 36) {

                                // Multi-Page Sheet Rendering
                                ForEach(0..<documentPages.count, id: \.self) { pageIndex in
                                    documentPageSheet(pageIndex: pageIndex)
                                }
                            }
                            .padding(.top, 28)
                            .padding(.bottom, 120)
                            .frame(minWidth: max(geometry.size.width, currentSheetWidth * zoomScale + 120), alignment: .center)
                        }
                        .background(StudioTheme.canvasBackground)

                        // Floating Left Island Sidebar Overlay
                        if showIslandSidebar {
                            VStack {
                                StudioFloatingSidebar(
                                    isPresented: $showIslandSidebar,
                                    rawText: $documentController.rawText,
                                    documentPages: documentPages,
                                    selectedPage: $selectedPage,
                                    sources: $documentController.document.sources,
                                    tables: $documentController.tables,
                                    images: $documentController.images,
                                    videos: $documentController.videos,
                                    showAIDrawer: $showAIDrawer,
                                    showCommandPalette: $showCommandPalette,
                                    onInsertSection: { handleToolAction(.text) },
                                    onInsertTable: { handleToolAction(.table) },
                                    onAddSource: { showingAddSourceSheet = true },
                                    onInsertPageBreak: { insertPageBreakAction() },
                                    onToast: { msg in showToast(msg) }
                                )
                                Spacer()
                            }
                            .padding(.leading, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            .zIndex(10)
                        }

                        // Floating Right Document Timeline Overlay
                        if showDocumentTimeline {
                            VStack {
                                HStack {
                                    Spacer()
                                    StudioDocumentTimelineView(
                                        isPresented: $showDocumentTimeline,
                                        rawText: $documentController.rawText,
                                        wordCount: wordCount,
                                        characterCount: characterCount,
                                        readingTimeMinutes: readingTimeMinutes,
                                        onSelectHeading: { heading in
                                            showToast("Jumped to: \(heading)")
                                        }
                                    )
                                }
                                Spacer()
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .zIndex(10)
                        }

                        // 3. Floating Draggable Header & Footer / Page Numbering HUD (Double-click activation)
                        if isEditingHeaderFooter {
                            VStack {
                                StudioHeaderFooterToolbar(
                                    config: $documentController.headerFooter,
                                    isEditing: $isEditingHeaderFooter,
                                    activeTarget: $activeHeaderFooterTarget
                                )
                                .padding(.top, 16)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .zIndex(20)
                        }

                        // 4. Inline AI Canvas Editor (shows when text selected, no format buttons since they are in top bar)
                        if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isEditingHeaderFooter {
                            VStack {
                                Spacer()
                                if showInlineAI {
                                    InlineAICanvasEditorView(
                                        selectedText: selectedText,
                                        fullDocumentContext: documentController.rawText,
                                        onAccept: { newText in
                                            replaceSelection(with: newText)
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showInlineAI = false
                                            }
                                        },
                                        onInsertBelow: { newText in
                                            insertBelowSelection(newText: newText)
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showInlineAI = false
                                            }
                                        },
                                        onDismiss: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showInlineAI = false
                                            }
                                        }
                                    )
                                    .padding(.bottom, 74)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.94).combined(with: .opacity).combined(with: .offset(y: 12)),
                                        removal: .opacity.combined(with: .scale(scale: 0.96))
                                    ))
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .zIndex(20)
                        }

                        // 5. Floating Find & Replace Bar Overlay
                        if showFindReplace {
                            VStack {
                                Spacer()
                                FindReplaceBar(
                                    isPresented: $showFindReplace,
                                    rawText: $documentController.rawText,
                                    onToast: { msg in showToast(msg) }
                                )
                                .padding(.bottom, 80)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(18)
                        }

                        // Bottom Edge Hover Detection Strip (triggers bottom bar reveal)
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 64)
                                .contentShape(Rectangle())
                                .onHover { hovered in
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        isBottomBarHovered = hovered
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .zIndex(12)

                        // Floating Studio Bottom Bar (Stats, Citations, Scale, AI) - Auto-hides when pointer is not at the bottom
                        VStack {
                            Spacer()
                            StudioFloatingBottomBar(
                                wordCount: wordCount,
                                characterCount: characterCount,
                                readingTimeMinutes: readingTimeMinutes,
                                citationStyle: $documentController.citationStyle,
                                zoomScale: $zoomScale,
                                showAIDrawer: $showAIDrawer,
                                onToast: { msg in showToast(msg) }
                            )
                            .padding(.bottom, 20)
                            .opacity(isBottomBarHovered ? 1.0 : 0.0)
                            .offset(y: isBottomBarHovered ? 0 : 25)
                            .scaleEffect(isBottomBarHovered ? 1.0 : 0.96)
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isBottomBarHovered)
                            .onHover { hovered in
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    isBottomBarHovered = hovered
                                }
                            }
                            .allowsHitTesting(isBottomBarHovered)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .zIndex(14)

                        // Floating Right AI Copilot Companion Island
                        if showAIDrawer {
                            HStack {
                                Spacer()
                                AssistantSidebarView(
                                    rawText: $documentController.rawText,
                                    selectedText: $selectedText,
                                    onInsertTable: { table in
                                        documentController.tables.append(table)
                                        let marker = "\n\n[[table:\(table.id.uuidString)]]\n\n"
                                        if selectionRange.location <= (documentController.rawText as NSString).length {
                                            let ns = documentController.rawText as NSString
                                            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
                                        } else {
                                            documentController.rawText += marker
                                        }
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
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .zIndex(15)
                        }

                        
                        // Floating Toast Notification
                        if let msg = toastMessage {
                            VStack {
                                Spacer()
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
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(25)
                        }
                    }
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
                        documentController.videos.append(block)
                        let marker = "\n\n[[video:\(block.id.uuidString)]]\n\n"
                        if selectionRange.location <= (documentController.rawText as NSString).length {
                            let ns = documentController.rawText as NSString
                            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
                        } else {
                            documentController.rawText += marker
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
        .modifier(EditorFileNotificationsModifier(
            onNew: newDocumentAction,
            onOpen: openDocument,
            onImportWordOrPDF: importWordOrPDF,
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
                    if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            showInlineAI.toggle()
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAIDrawer.toggle()
                        }
                    }
                }) { EmptyView() }
                    .keyboardShortcut("j", modifiers: [.command])
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showIslandSidebar.toggle()
                    }
                }) { EmptyView() }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showDocumentTimeline.toggle()
                    }
                }) { EmptyView() }
                    .keyboardShortcut("t", modifiers: [.command, .option])
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        documentController.coverBanner.isEnabled.toggle()
                    }
                }) { EmptyView() }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showPageDesignInspector.toggle()
                    }
                }) { EmptyView() }
                    .keyboardShortcut("d", modifiers: [.command, .option])
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
                
                // Global Command+A routing
                Button(action: {
                    NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
                }) { EmptyView() }
                    .keyboardShortcut("a", modifiers: [.command])
            }

            .opacity(0)
            .allowsHitTesting(false)
        )
        .onAppear {
            runLinter()
            
            editorController.onSelectAllRequested = {
                let totalLength = documentPageSlices.last.map { $0.range.location + $0.range.length } ?? (documentController.rawText as NSString).length
                self.selectionRange = NSRange(location: 0, length: totalLength)
            }
            
            editorController.onImportFile = { url in
                self.importFileNatively(url: url)
            }
        }
    }

    private func calculateEditorHeight(for textContent: String) -> CGFloat {
        let font = resolveFontNamed(family: documentController.fontFamily, size: documentController.fontSize, bold: isBold, italic: isItalic)
        let paragraphStyle = NSMutableParagraphStyle()
        switch documentController.textAlignment {
        case .leading: paragraphStyle.alignment = .left
        case .center: paragraphStyle.alignment = .center
        case .trailing: paragraphStyle.alignment = .right
        }
        paragraphStyle.lineHeightMultiple = documentController.lineSpacing
        paragraphStyle.paragraphSpacing = documentController.paragraphSpacing
        let availableWidth = max(100, currentSheetWidth - documentController.margins.left - documentController.margins.right)
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
        documentController.tables.indices.filter { idx in
            let idStr = documentController.tables[idx].id.uuidString
            let hasBudgetMarker = (idx == 0 && documentController.rawText.contains("[[table:budget]]"))
            return !documentController.rawText.contains("[[table:\(idStr)]]") && !hasBudgetMarker
        }
    }

    private var unreferencedImageIndices: [Int] {
        documentController.images.indices.filter { idx in
            let idStr = documentController.images[idx].id.uuidString
            return !documentController.rawText.contains("[[image:\(idStr)]]")
        }
    }

    private var unreferencedVideoIndices: [Int] {
        documentController.videos.indices.filter { idx in
            let idStr = documentController.videos[idx].id.uuidString
            return !documentController.rawText.contains("[[video:\(idStr)]]")
        }
    }

    // MARK: - Actions
    private func newDocumentAction() {
        documentController.title = "Untitled Document"
        documentController.rawText = "Start writing your documentController.document here..."
        documentController.tables = []
        documentController.images = []
        documentController.videos = []
        documentController.document.sources = [:]
        selectionAttributes = nil
        showToast("✓ Created New Document")
    }

    private func handleToolAction(_ tool: StudioTool) {
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

            documentController.tables.append(newTable)
            let marker = "\n\n[[table:\(newTable.id.uuidString)]]\n\n"
            if selectionRange.location <= (documentController.rawText as NSString).length {
                let ns = documentController.rawText as NSString
                documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
            } else {
                documentController.rawText += marker
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
                documentController.images.append(block)
                let marker = "\n\n[[image:\(block.id.uuidString)]]\n\n"
                if selectionRange.location <= (documentController.rawText as NSString).length {
                    let ns = documentController.rawText as NSString
                    documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
                } else {
                    documentController.rawText += marker
                }
                showToast("✓ Inserted Image Figure")
            }
        }
    }

    private func insertPageBreakAction() {
        documentController.rawText += "\n\n---pagebreak---\n\n"
        showToast("✓ Inserted Page Break (Page \(documentPages.count))")
    }

    private func insertTOCAction() {
        let marker = "\n\n[[toc]]\n\n"
        if selectionRange.location <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
        } else {
            documentController.rawText += marker
        }
        showToast("✓ Inserted Table of Contents")
    }

    private func insertBibliographyAction() {
        let marker = "\n\n[[bibliography]]\n\n"
        if selectionRange.location <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: marker)
        } else {
            documentController.rawText += marker
        }
        showToast("✓ Inserted Bibliography / Works Cited")
    }

    private func toggleStrikethroughAction() {
        editorController.toggleStrikethrough()
        showToast("✓ Strikethrough toggled")
    }

    private func insertSectionHeadingAction(level: Int = 1, customTitle: String? = nil) {
        let title = customTitle ?? (level == 1 ? "Title" : level == 2 ? "Section Heading" : "Subsection")
        let hashes = String(repeating: "#", count: max(1, min(6, level)))
        let item = "\(hashes) \(title)"
        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: item)
        } else if documentController.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            documentController.rawText = item
        } else {
            documentController.rawText = documentController.rawText.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + item
        }
        showToast("✓ Inserted Heading \(level)")
    }

    private func insertChecklistAction() {
        let item = "\n- [ ] Task item\n"
        if selectionRange.location <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: item)
        } else {
            documentController.rawText += item
        }
        showToast("✓ Inserted Checklist Item")
    }

    private func insertBlockquoteAction() {
        let item = "\n> Quoted text block\n"
        if selectionRange.location <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: item)
        } else {
            documentController.rawText += item
        }
        showToast("✓ Inserted Blockquote")
    }

    private func insertCodeBlockAction() {
        let item = "\n```swift\n// Code snippet\n```\n"
        if selectionRange.location <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: item)
        } else {
            documentController.rawText += item
        }
        showToast("✓ Inserted Code Block")
    }

    private func insertDividerAction() {
        let item = "\n\n---\n\n"
        if selectionRange.location <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: item)
        } else {
            documentController.rawText += item
        }
        showToast("✓ Inserted Horizontal Divider")
    }

    private func insertDateTimeAction() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let str = formatter.string(from: Date())
        if selectionRange.location <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: str)
        } else {
            documentController.rawText += str
        }
        showToast("✓ Inserted Date/Time: \(str)")
    }

    private func transformTextSelection(mode: String) {
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

    private func setLineSpacingAction(_ spacing: CGFloat) {
        documentController.lineSpacing = spacing
        editorController.applyLineSpacing(spacing, paragraphSpacing: documentController.paragraphSpacing)
        showToast("✓ Line Spacing: \(String(format: "%.2g", spacing))")
    }

    private func setParagraphSpacingAction(_ spacing: CGFloat) {
        documentController.paragraphSpacing = spacing
        editorController.applyLineSpacing(documentController.lineSpacing, paragraphSpacing: spacing)
        showToast("✓ Paragraph Spacing: \(spacing > 0 ? "Added" : "Removed")")
    }

    private func insertBulletListAction() {
        let item = "\n• "
        if selectionRange.location <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: item)
        } else {
            documentController.rawText += item
        }
        showToast("✓ Inserted Bullet Item")
    }

    private func insertNumberedListAction() {
        let item = "\n1. "
        if selectionRange.location <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: item)
        } else {
            documentController.rawText += item
        }
        showToast("✓ Inserted Numbered List")
    }

    private func toggleBoldAction() {
        editorController.toggleBold()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isBold ? "✓ Bold enabled" : "Bold disabled")
        } else {
            isBold.toggle()
            showToast(isBold ? "✓ Bold enabled" : "Bold disabled")
        }
    }

    private func toggleItalicAction() {
        editorController.toggleItalic()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isItalic ? "✓ Italic enabled" : "Italic disabled")
        } else {
            isItalic.toggle()
            showToast(isItalic ? "✓ Italic enabled" : "Italic disabled")
        }
    }

    private func toggleUnderlineAction() {
        editorController.toggleUnderline()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isUnderline ? "✓ Underline enabled" : "Underline disabled")
        } else {
            isUnderline.toggle()
            showToast(isUnderline ? "✓ Underline enabled" : "Underline disabled")
        }
    }

    private func setAlignmentAction(_ align: TextAlignment) {
        documentController.textAlignment = align
        editorController.applyAlignment(align, lineSpacing: documentController.lineSpacing, paragraphSpacing: documentController.paragraphSpacing)
        let name = align == .leading ? "Left" : align == .center ? "Center" : "Right"
        showToast("✓ Alignment: \(name)")
    }

    private func setFontFamilyAction(_ font: String) {
        documentController.fontFamily = font
        let sizeToApply = selectionAttributes?.fontSize ?? documentController.fontSize
        editorController.applyFontFamily(font, size: sizeToApply)
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        showToast("✓ Font: \(font)")
    }

    private func setFontSizeAction(_ size: CGFloat) {
        documentController.fontSize = size
        editorController.applyFontSize(size)
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        showToast("✓ Font Size: \(Int(size)) pt")
    }

    private func insertCitationForSelection() {
        showingAddSourceSheet = true
    }

    private func executeDirectCLICommand(_ query: String) -> Bool {
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

    private var paletteCommands: [CommandItem] {
        [
            // === File & Document Operations ===
            CommandItem(title: "Save Native .letters Package", subtitle: "Lossless Project Letters documentController.document archive", icon: "tray.and.arrow.down.fill", category: .file, shortcut: "⌘S", keywords: ["save", "native", "package", "store"]) {
                saveDocumentAsLetters()
            },
            CommandItem(title: "Open Existing Document", subtitle: "Open .letters, .docx, or .md file from disk", icon: "folder", category: .file, shortcut: "⌘O", keywords: ["open", "import", "browse", "load"]) {
                openDocument()
            },
            CommandItem(title: "Export as Word Document (.docx)", subtitle: "Generate native lossless Microsoft Word documentController.document", icon: "doc.fill", category: .file, shortcut: "⌘⇧S", keywords: ["export", "word", "docx", "microsoft"]) {
                saveDocumentAsDocx()
            },
            CommandItem(title: "Export as Vector PDF (.pdf)", subtitle: "High resolution publication PDF ready for printing", icon: "arrow.down.doc", category: .file, shortcut: "⌘⌥E", keywords: ["pdf", "vector", "export", "print"]) {
                exportDocumentAsPDF()
            },
            CommandItem(title: "Print Document", subtitle: "Open native macOS Print setup & pagination dialog", icon: "printer", category: .file, shortcut: "⌘P", keywords: ["print", "paper", "dialog"]) {
                printDocument()
            },
            CommandItem(title: "Document Statistics & Word Count", subtitle: "\(wordCount) words, \(characterCount) chars, \(documentPages.count) pages", icon: "chart.bar.doc.horizontal", category: .file, shortcut: "⌘I", keywords: ["stats", "words", "count", "info"]) {
                showToast("📊 \(wordCount) words • \(characterCount) chars • \(documentPages.count) pages")
            },
            CommandItem(title: "Clear Document (New File)", subtitle: "Reset text, tables, figures, and sources", icon: "trash", category: .file, keywords: ["clear", "reset", "empty", "new"]) {
                newDocumentAction()
            },

            // === Formatting & Typography ===
            CommandItem(title: "Toggle Bold", subtitle: "Make selected text bold", icon: "bold", category: .format, shortcut: "⌘B", keywords: ["bold", "weight", "heavy"]) {
                toggleBoldAction()
            },
            CommandItem(title: "Toggle Italic", subtitle: "Make selected text italic", icon: "italic", category: .format, shortcut: "⌘I", keywords: ["italic", "oblique", "slant"]) {
                toggleItalicAction()
            },
            CommandItem(title: "Toggle Underline", subtitle: "Underline selected text", icon: "underline", category: .format, shortcut: "⌘U", keywords: ["underline"]) {
                toggleUnderlineAction()
            },
            CommandItem(title: "Toggle Strikethrough", subtitle: "Cross out selected text", icon: "strikethrough", category: .format, shortcut: "⇧⌘X", keywords: ["strike", "strikethrough", "cross"]) {
                toggleStrikethroughAction()
            },
            CommandItem(title: "Align Left", subtitle: "Set text alignment to leading edge", icon: "text.alignleft", category: .format, shortcut: "⌘{", keywords: ["align", "left", "leading"]) {
                setAlignmentAction(.leading)
            },
            CommandItem(title: "Align Center", subtitle: "Center text horizontally", icon: "text.aligncenter", category: .format, shortcut: "⌘|", keywords: ["align", "center"]) {
                setAlignmentAction(.center)
            },
            CommandItem(title: "Align Right", subtitle: "Set text alignment to trailing edge", icon: "text.alignright", category: .format, shortcut: "⌘}", keywords: ["align", "right", "trailing"]) {
                setAlignmentAction(.trailing)
            },
            CommandItem(title: "Line Spacing: 1.0 (Single)", subtitle: "Compact single line spacing", icon: "arrow.up.and.down.text.horizontal", category: .format, keywords: ["spacing", "single", "leading"]) {
                setLineSpacingAction(1.0)
            },
            CommandItem(title: "Line Spacing: 1.15 (Standard)", subtitle: "Default modern documentController.document spacing", icon: "arrow.up.and.down.text.horizontal", category: .format, keywords: ["spacing", "standard", "leading"]) {
                setLineSpacingAction(1.15)
            },
            CommandItem(title: "Line Spacing: 1.5 (1.5x)", subtitle: "Academic 1.5x line spacing", icon: "arrow.up.and.down.text.horizontal", category: .format, keywords: ["spacing", "academic", "leading"]) {
                setLineSpacingAction(1.5)
            },
            CommandItem(title: "Line Spacing: 2.0 (Double)", subtitle: "Double line spacing for manuscripts", icon: "arrow.up.and.down.text.horizontal", category: .format, keywords: ["spacing", "double", "leading"]) {
                setLineSpacingAction(2.0)
            },
            CommandItem(title: "Font: Georgia (Default Serif)", subtitle: "Classic editorial serif typeface", icon: "textformat", category: .format, keywords: ["font", "georgia", "serif"]) {
                setFontFamilyAction("Default Serif (Georgia)")
            },
            CommandItem(title: "Font: SF Pro (San Francisco)", subtitle: "Clean modern Apple sans-serif", icon: "textformat", category: .format, keywords: ["font", "sf pro", "sans"]) {
                setFontFamilyAction("SF Pro")
            },
            CommandItem(title: "Font: Times New Roman", subtitle: "Standard academic journal typeface", icon: "textformat", category: .format, keywords: ["font", "times", "academic"]) {
                setFontFamilyAction("Times New Roman")
            },
            CommandItem(title: "Font: Helvetica Neue", subtitle: "Swiss modernist sans-serif", icon: "textformat", category: .format, keywords: ["font", "helvetica", "swiss"]) {
                setFontFamilyAction("Helvetica")
            },
            CommandItem(title: "Font: Charter", subtitle: "High readability Bitstream serif", icon: "textformat", category: .format, keywords: ["font", "charter", "serif"]) {
                setFontFamilyAction("Charter")
            },
            CommandItem(title: "Font: Menlo Monospace", subtitle: "Fixed-width code and tabular font", icon: "character.textbox", category: .format, keywords: ["font", "menlo", "mono", "code"]) {
                setFontFamilyAction("Menlo (Monospace)")
            },
            CommandItem(title: "Transform to UPPERCASE", subtitle: "Convert selection to uppercase letters", icon: "textformat.size.larger", category: .format, keywords: ["case", "upper", "capitalize"]) {
                transformTextSelection(mode: "upper")
            },
            CommandItem(title: "Transform to lowercase", subtitle: "Convert selection to lowercase letters", icon: "textformat.size.smaller", category: .format, keywords: ["case", "lower"]) {
                transformTextSelection(mode: "lower")
            },
            CommandItem(title: "Transform to Title Case", subtitle: "Capitalize first letter of each word", icon: "textformat", category: .format, keywords: ["case", "title", "capitalize"]) {
                transformTextSelection(mode: "capitalized")
            },

            // === Insert Structural Elements ===
            CommandItem(title: "Insert Heading 1 (Title)", subtitle: "Top level documentController.document section title (#)", icon: "text.quote", category: .insert, shortcut: "⌘⌥1", keywords: ["h1", "title", "heading"]) {
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
            CommandItem(title: "Embed Video Card", subtitle: "Add YouTube or Vimeo player card", icon: "play.rectangle", category: .insert, keywords: ["video", "youtube", "vimeo", "media"]) {
                showingAddVideoSheet = true
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
            CommandItem(title: "Insert Page Break", subtitle: "Force documentController.document onto new page sheet", icon: "pagebreak", category: .insert, shortcut: "⌘↵", keywords: ["page", "break", "sheet"]) {
                insertPageBreakAction()
            },
            CommandItem(title: "Insert Horizontal Divider", subtitle: "Visual separator rule (---)", icon: "divide", category: .insert, keywords: ["divider", "line", "rule", "separator"]) {
                insertDividerAction()
            },
            CommandItem(title: "Insert Current Date & Time", subtitle: "Stamp current timestamp into documentController.document", icon: "clock", category: .insert, keywords: ["date", "time", "stamp", "now"]) {
                insertDateTimeAction()
            },

            // === Page Setup & Layout ===
            CommandItem(title: "Page Format: A4 (210 × 297 mm)", subtitle: "International standard documentController.document size", icon: "doc", category: .layout, keywords: ["a4", "format", "size", "iso"]) {
                documentController.pageSize = .a4
                showToast("✓ Page Format: A4")
            },
            CommandItem(title: "Page Format: US Letter (8.5 × 11 in)", subtitle: "North American standard paper size", icon: "doc", category: .layout, keywords: ["letter", "format", "size", "us"]) {
                documentController.pageSize = .letter
                showToast("✓ Page Format: US Letter")
            },
            CommandItem(title: "Page Format: US Legal (8.5 × 14 in)", subtitle: "Extended legal documentController.document format", icon: "doc", category: .layout, keywords: ["legal", "format", "size"]) {
                documentController.pageSize = .legal
                showToast("✓ Page Format: US Legal")
            },
            CommandItem(title: "Page Format: Executive", subtitle: "Compact 7.25 × 10.5 in executive format", icon: "doc", category: .layout, keywords: ["executive", "format", "size"]) {
                documentController.pageSize = .executive
                showToast("✓ Page Format: Executive")
            },
            CommandItem(title: "Margins: Standard (1 inch / 72 pt)", subtitle: "Balanced standard print documentController.margins", icon: "doc.viewfinder", category: .layout, keywords: ["margin", "standard", "1 inch"]) {
                documentController.marginPreset = .normal
                showToast("✓ Margins: Standard (72 pt)")
            },
            CommandItem(title: "Margins: Narrow (0.5 inch / 36 pt)", subtitle: "Maximized printable canvas area", icon: "doc.viewfinder", category: .layout, keywords: ["margin", "narrow", "0.5 inch"]) {
                documentController.marginPreset = .narrow
                showToast("✓ Margins: Narrow (36 pt)")
            },
            CommandItem(title: "Margins: Wide (1.5 inch / 108 pt)", subtitle: "Spacious documentController.margins for annotations and notes", icon: "doc.viewfinder", category: .layout, keywords: ["margin", "wide", "spacious"]) {
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
            CommandItem(title: "Toggle Different First Page", subtitle: "Suppress running headers and footers on documentController.document title cover", icon: "doc.text", category: .layout, keywords: ["first page", "cover", "title page", "suppress", "header", "footer"]) {
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
            CommandItem(title: "AI Generate Table of Contents", subtitle: "Analyze documentController.document and build hierarchical TOC", icon: "sparkles.rectangle.stack", category: .ai, keywords: ["ai", "toc", "structure", "outline"]) {
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

    private func buildDocumentAIContext() -> String {
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

    private func runLinter() {
        lintIssues = CoreBridge.shared.lint(text: documentController.rawText, profile: "academic")
    }

    // MARK: - Native .letters / .ltt Lossless Package Save & Open
    public func saveDocumentAsLetters() {
        let bundle = LettersDocumentBundle(
            title: documentController.title,
            rawText: documentController.rawText,
            richTextData: documentController.richTextData,
            tables: documentController.tables,
            images: documentController.images,
            videos: documentController.videos,
            sources: documentController.document.sources,
            citationStyle: documentController.citationStyle,
            pageSizePreset: documentController.pageSize,
            marginPreset: documentController.marginPreset,
            margins: documentController.margins,
            fontFamily: documentController.fontFamily,
            fontSize: Double(documentController.fontSize),
            lineSpacing: Double(documentController.lineSpacing),
            paragraphSpacing: Double(documentController.paragraphSpacing),
            headerFooter: documentController.headerFooter,
            coverBanner: documentController.coverBanner
        )

        guard let data = try? bundle.encodeToData() else {
            showToast("⚠️ Could not encode .letters bundle")
            return
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
                    documentController.title = bundle.title
                    documentController.rawText = bundle.rawText
                    documentController.richTextData = bundle.richTextData
                    documentController.tables = bundle.tables
                    documentController.images = bundle.images
                    documentController.videos = bundle.videos
                    documentController.document.sources = bundle.sources
                    documentController.citationStyle = bundle.citationStyle
                    documentController.pageSize = bundle.pageSizePreset
                    documentController.marginPreset = bundle.marginPreset
                    documentController.margins = bundle.margins
                    documentController.fontFamily = bundle.fontFamily
                    documentController.fontSize = CGFloat(bundle.fontSize)
                    documentController.lineSpacing = CGFloat(bundle.lineSpacing)
                    documentController.paragraphSpacing = CGFloat(bundle.paragraphSpacing)
                    documentController.headerFooter = bundle.headerFooter
                    documentController.coverBanner = bundle.coverBanner
                    showToast("✓ Opened .letters document: \(url.lastPathComponent)")
                } else if ext == "md" || ext == "txt" {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    documentController.title = url.deletingPathExtension().lastPathComponent
                    documentController.rawText = content
                    showToast("✓ Opened file: \(url.lastPathComponent)")
                } else if ext == "docx" {
                    let attrStr = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.officeOpenXML], documentAttributes: nil)
                    documentController.title = url.deletingPathExtension().lastPathComponent
                    documentController.rawText = attrStr.string
                    if let data = try? NSKeyedArchiver.archivedData(withRootObject: attrStr, requiringSecureCoding: false) {
                        documentController.richTextData = data
                    }
                    showToast("✓ Opened Word file natively: \(url.lastPathComponent)")
                }
            } catch {
                showToast("⚠️ Could not open document: \(error.localizedDescription)")
            }
        }
    }

    public func importWordOrPDF() {
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

    private func importFileNatively(url: URL) {
        let ext = url.pathExtension.lowercased()
        do {
            if ext == "docx" {
                    let attrStr = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.officeOpenXML], documentAttributes: nil)
                    
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
                        if selectionRange.location <= (documentController.rawText as NSString).length {
                            let ns = documentController.rawText as NSString
                            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: text)
                        } else {
                            documentController.rawText += text
                        }
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
    public func saveDocumentAsDocx() {
        var fullExport = documentController.rawText
        if !documentController.tables.isEmpty {
            fullExport += "\n\n" + documentController.tables.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !documentController.images.isEmpty {
            fullExport += "\n\n" + documentController.images.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !documentController.videos.isEmpty {
            fullExport += "\n\n" + documentController.videos.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }

        guard let docxData = CoreBridge.shared.exportDocx(title: documentController.title, text: fullExport) else {
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

    public func exportDocumentAsPDF() {
        let panel = NSSavePanel()
        panel.title = "Export Vector PDF"
        panel.nameFieldStringValue = "\(documentController.title.replacingOccurrences(of: " ", with: "_")).pdf"
        if let type = UTType(filenameExtension: "pdf") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            let paperSize = NSSize(width: documentController.pageSize.dimensions.width, height: documentController.pageSize.dimensions.height)
            let printInfo = NSPrintInfo.shared
            printInfo.paperSize = paperSize
            printInfo.topMargin = documentController.margins.top
            printInfo.bottomMargin = documentController.margins.bottom
            printInfo.leftMargin = documentController.margins.left
            printInfo.rightMargin = documentController.margins.right
            printInfo.orientation = .portrait

            let textView = NSTextView(frame: NSRect(origin: .zero, size: paperSize))
            textView.string = documentController.rawText
            textView.font = resolveFontNamed(family: documentController.fontFamily, size: documentController.fontSize, bold: isBold, italic: isItalic)
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
        let paperSize = NSSize(width: documentController.pageSize.dimensions.width, height: documentController.pageSize.dimensions.height)
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = paperSize
        printInfo.topMargin = documentController.margins.top
        printInfo.bottomMargin = documentController.margins.bottom
        printInfo.leftMargin = documentController.margins.left
        printInfo.rightMargin = documentController.margins.right

        let textView = NSTextView(frame: NSRect(origin: .zero, size: paperSize))
        textView.string = documentController.rawText
        textView.font = resolveFontNamed(family: documentController.fontFamily, size: documentController.fontSize, bold: isBold, italic: isItalic)

        let op = NSPrintOperation(view: textView, printInfo: printInfo)
        op.showsPrintPanel = true
        op.run()
    }

    public func saveDocumentAsMarkdown() {
        var fullExport = documentController.rawText
        if !documentController.tables.isEmpty {
            fullExport += "\n\n" + documentController.tables.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !documentController.images.isEmpty {
            fullExport += "\n\n" + documentController.images.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !documentController.videos.isEmpty {
            fullExport += "\n\n" + documentController.videos.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }

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
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(documentController.pageSize.rawValue) • \(documentController.marginPreset.rawValue)")
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
                    .onTapGesture {
                        editorController.focusPage(pageIndex, at: (getPageText(pageIndex: pageIndex) as NSString).length)
                    }

                // 2. Running Header (Title, Subtitle & Interactive In-Place Double-Click Editor)
                StudioHeaderView(
                    config: $documentController.headerFooter,
                    pageIndex: pageIndex,
                    totalPages: documentPages.count,
                    documentTitle: documentController.title,
                    margins: documentController.margins,
                    sheetWidth: currentSheetWidth,
                    isEditing: $isEditingHeaderFooter,
                    activeTarget: $activeHeaderFooterTarget
                )

                // 3. Margin Guides Overlay
                if showMarginGuides {
                    PaperMarginGuidesView(
                        width: currentSheetWidth,
                        height: currentSheetHeight,
                        margins: documentController.margins
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

                // 6. Running Footer (Page Numbers & Interactive In-Place Double-Click Editor)
                StudioFooterView(
                    config: $documentController.headerFooter,
                    pageIndex: pageIndex,
                    totalPages: documentPages.count,
                    documentTitle: documentController.title,
                    margins: documentController.margins,
                    sheetWidth: currentSheetWidth,
                    sheetHeight: currentSheetHeight,
                    isEditing: $isEditingHeaderFooter,
                    activeTarget: $activeHeaderFooterTarget
                )
            }
            .environment(\.colorScheme, .light)
            .frame(width: currentSheetWidth, height: currentSheetHeight)
            .scaleEffect(zoomScale, anchor: .top)
            .frame(width: currentSheetWidth * zoomScale, height: currentSheetHeight * zoomScale, alignment: .top)
        }
    }

    @ViewBuilder
    private func documentCanvasContent(pageIndex: Int) -> some View {
        let pageStr = pageIndex < documentPages.count ? documentPages[pageIndex] : documentController.rawText
        let segments = parseCanvasSegments(for: pageStr, pageIndex: pageIndex)
        let printableWidth = max(100, currentSheetWidth - documentController.margins.left - documentController.margins.right)
        let printableHeight = max(100, currentSheetHeight - documentController.margins.top - documentController.margins.bottom)

        Group {
            if segments.count == 1, case .text = segments[0] {
                // Clean Single-Block Text Editor for this page (No inner spacing bugs)
                TextKit2EditorView(
                    text: Binding(
                        get: {
                            getPageText(pageIndex: pageIndex)
                        },
                        set: { newVal in
                            setPageText(pageIndex: pageIndex, newText: newVal)
                        }
                    ),
                    richTextData: $documentController.richTextData,
                    selectedText: $selectedText,
                    selectionRange: $selectionRange,
                    attributedText: getPageAttributedText(pageIndex: pageIndex),
                    sliceRange: getPageSliceRange(pageIndex: pageIndex),
                    controller: editorController,
                    fontFamily: documentController.fontFamily,
                    fontSize: documentController.fontSize,
                    isBold: isBold,
                    isItalic: isItalic,
                    isUnderline: isUnderline,
                    alignment: documentController.textAlignment,
                    lineSpacing: documentController.lineSpacing,
                    paragraphSpacing: documentController.paragraphSpacing,
                    margins: PageMargins(),
                    pageIndex: pageIndex,
                    onSelectionChanged: { _, _, attrs in
                        self.selectionAttributes = attrs
                    }
                )
                .frame(width: printableWidth, height: printableHeight, alignment: .topLeading)
            } else {
                // Multi-Segment Page (Interleaved text and embedded figures/tables)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(segments) { segment in
                        switch segment {
                        case .text(id: _, textIndex: let textIdx, initialContent: let initialChunk):
                            let displayChunk = getTextChunk(pageIndex: pageIndex, textIndex: textIdx)
                            let h = calculateEditorHeight(for: displayChunk.isEmpty ? initialChunk : displayChunk)

                            TextKit2EditorView(
                                text: Binding(
                                    get: {
                                        getTextChunk(pageIndex: pageIndex, textIndex: textIdx)
                                    },
                                    set: { newVal in
                                        setTextChunk(pageIndex: pageIndex, textIndex: textIdx, newText: newVal)
                                    }
                                ),
                                richTextData: $documentController.richTextData,
                                selectedText: $selectedText,
                                selectionRange: $selectionRange,
                                attributedText: getPageAttributedText(pageIndex: pageIndex),
                                sliceRange: getPageSliceRange(pageIndex: pageIndex),
                                controller: editorController,
                                fontFamily: documentController.fontFamily,
                                fontSize: documentController.fontSize,
                                isBold: isBold,
                                isItalic: isItalic,
                                isUnderline: isUnderline,
                                alignment: documentController.textAlignment,
                                lineSpacing: documentController.lineSpacing,
                                paragraphSpacing: documentController.paragraphSpacing,
                                margins: PageMargins(),
                                pageIndex: pageIndex,
                                onSelectionChanged: { _, _, attrs in
                                    self.selectionAttributes = attrs
                                }
                            )
                            .frame(width: printableWidth, height: h, alignment: .topLeading)

                        case .table(id: _, tableId: let tableId):
                            if let idx = documentController.tables.firstIndex(where: { $0.id == tableId }) {
                                SmartTableView(
                                    store: documentController, tableId: tableId, fontFamily: documentController.fontFamily,
                                    onDelete: {
                                        let idStr = documentController.tables[idx].id.uuidString
                                        documentController.tables.remove(at: idx)
                                        documentController.rawText = documentController.rawText.replacingOccurrences(of: "[[table:\(idStr)]]", with: "")
                                        documentController.rawText = documentController.rawText.replacingOccurrences(of: "[[table:budget]]", with: "")
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

                        case .image(id: _, imageId: let imageId):
                            if let idx = documentController.images.firstIndex(where: { $0.id == imageId }) {
                                StudioImageView(
                                    imageBlock: $documentController.images[idx],
                                    onDelete: {
                                        let idStr = documentController.images[idx].id.uuidString
                                        documentController.images.remove(at: idx)
                                        documentController.rawText = documentController.rawText.replacingOccurrences(of: "[[image:\(idStr)]]", with: "")
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

                        case .video(id: _, videoId: let videoId):
                            if let idx = documentController.videos.firstIndex(where: { $0.id == videoId }) {
                                StudioVideoView(
                                    videoBlock: $documentController.videos[idx],
                                    onDelete: {
                                        let idStr = documentController.videos[idx].id.uuidString
                                        documentController.videos.remove(at: idx)
                                        documentController.rawText = documentController.rawText.replacingOccurrences(of: "[[video:\(idStr)]]", with: "")
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

                        case .bibliography(id: _):
                            DynamicBibliographyView(
                                sources: documentController.document.sources,
                                activeStyle: $documentController.citationStyle,
                                onDelete: {
                                    documentController.rawText = documentController.rawText.replacingOccurrences(of: "[[bibliography]]", with: "")
                                    showToast("✓ Deleted Bibliography section")
                                },
                                onToast: { msg in
                                    showToast(msg)
                                }
                            )

                        case .tableOfContents(id: _):
                            DynamicTOCView(
                                rawText: documentController.rawText,
                                onDelete: {
                                    documentController.rawText = documentController.rawText.replacingOccurrences(of: "[[toc]]", with: "")
                                    showToast("✓ Deleted Table of Contents")
                                },
                                onToast: { msg in
                                    showToast(msg)
                                }
                            )
                        }
                    }
                }
            }
        }
        .frame(width: printableWidth, height: printableHeight, alignment: .topLeading)
        .clipped()
        .offset(x: documentController.margins.left, y: documentController.margins.top)
    }

    @ViewBuilder
    private var floatingSelectionActionMenu: some View {
        FloatingActionMenu(
            selectedText: selectedText,
            fontFamily: selectionAttributes?.fontFamily ?? documentController.fontFamily,
            fontSize: selectionAttributes?.fontSize ?? documentController.fontSize,
            isBold: selectionAttributes?.isBold ?? isBold,
            isItalic: selectionAttributes?.isItalic ?? isItalic,
            isUnderline: selectionAttributes?.isUnderline ?? isUnderline,
            textAlignment: selectionAttributes?.alignment ?? documentController.textAlignment,
            lineSpacing: documentController.lineSpacing,
            onBold: {
                toggleBoldAction()
            },
            onItalic: {
                toggleItalicAction()
            },
            onUnderline: {
                toggleUnderlineAction()
            },
            onStrikethrough: {
                toggleStrikethroughAction()
            },
            onSetFontFamily: { fam in
                setFontFamilyAction(fam)
            },
            onSetFontSize: { sz in
                setFontSizeAction(sz)
            },
            onSetAlignment: { align in
                setAlignmentAction(align)
            },
            onSetLineSpacing: { sp in
                setLineSpacingAction(sp)
            },
            onSetParagraphSpacing: { sp in
                setParagraphSpacingAction(sp)
            },
            onAskAI: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    showInlineAI = true
                }
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
                        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
                            let ns = documentController.rawText as NSString
                            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: res)
                        } else {
                            documentController.rawText = documentController.rawText.replacingOccurrences(of: selectedText, with: res)
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
            },
            onCommandPalette: {
                showCommandPalette = true
            }
        )
    }

    private func replaceSelection(with newText: String) {
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

    private func insertBelowSelection(newText: String) {
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

    private func extractTextChunks(from pageContent: String) -> [String] {
        let regex = EditorPerformanceCache.shared.canvasChunkMarkerRegex
        let ns = pageContent as NSString
        let matches = regex.matches(in: pageContent, options: [], range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty {
            return [pageContent]
        }
        var chunks: [String] = []
        var lastLoc = 0
        for match in matches {
            let len = match.range.location - lastLoc
            chunks.append(ns.substring(with: NSRange(location: lastLoc, length: max(0, len))))
            lastLoc = match.range.location + match.range.length
        }
        if lastLoc <= ns.length {
            chunks.append(ns.substring(with: NSRange(location: lastLoc, length: ns.length - lastLoc)))
        }
        return chunks
    }

    private func replaceTextChunk(in pageContent: String, textIndex: Int, with newText: String) -> String {
        let regex = EditorPerformanceCache.shared.canvasChunkMarkerRegex
        let ns = pageContent as NSString
        let matches = regex.matches(in: pageContent, options: [], range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty {
            return newText
        }

        var result = ""
        var lastLoc = 0
        var currentTextIdx = 0

        for match in matches {
            let chunk = ns.substring(with: NSRange(location: lastLoc, length: max(0, match.range.location - lastLoc)))
            let marker = ns.substring(with: match.range)
            if currentTextIdx == textIndex {
                result += newText
            } else {
                result += chunk
            }
            result += marker
            currentTextIdx += 1
            lastLoc = match.range.location + match.range.length
        }

        if lastLoc <= ns.length {
            let tail = ns.substring(with: NSRange(location: lastLoc, length: ns.length - lastLoc))
            if currentTextIdx == textIndex {
                result += newText
            } else {
                result += tail
            }
        }

        return result
    }

    private func getTextChunk(pageIndex: Int, textIndex: Int) -> String {
        let pages = documentPages
        guard pageIndex < pages.count else { return "" }
        let pageContent = pages[pageIndex]
        let chunks = extractTextChunks(from: pageContent)
        guard textIndex < chunks.count else { return "" }
        return chunks[textIndex]
    }

    private func setTextChunk(pageIndex: Int, textIndex: Int, newText: String) {
        var pages = documentPages
        guard pageIndex < pages.count else { return }
        let pageContent = pages[pageIndex]
        let updatedPage = replaceTextChunk(in: pageContent, textIndex: textIndex, with: newText)
        pages[pageIndex] = updatedPage
        documentController.rawText = pages.joined(separator: "\n\n---pagebreak---\n\n")
    }

    private func parseCanvasSegments(for pageContent: String, pageIndex: Int = 0) -> [DocumentCanvasSegment] {
        let regex = EditorPerformanceCache.shared.canvasSegmentRegex
        let nsContent = pageContent as NSString
        let matches = regex.matches(in: pageContent, options: [], range: NSRange(location: 0, length: nsContent.length))

        if matches.isEmpty {
            return [DocumentCanvasSegment.text(id: "p\(pageIndex)-text-0", textIndex: 0, initialContent: pageContent)]
        }

        var segments: [DocumentCanvasSegment] = []
        var lastLocation = 0
        var textIdx = 0
        var blockIdx = 0

        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastLocation {
                let textRange = NSRange(location: lastLocation, length: matchRange.location - lastLocation)
                let chunkText = nsContent.substring(with: textRange)
                segments.append(DocumentCanvasSegment.text(id: "p\(pageIndex)-text-\(textIdx)", textIndex: textIdx, initialContent: chunkText))
                textIdx += 1
            }

            if match.numberOfRanges >= 2 {
                let kind = nsContent.substring(with: match.range(at: 1))
                let idStr = (match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound) ? nsContent.substring(with: match.range(at: 2)) : ""

                if kind == "bibliography" {
                    segments.append(DocumentCanvasSegment.bibliography(id: "p\(pageIndex)-bib-\(blockIdx)"))
                    blockIdx += 1
                } else if kind == "toc" {
                    segments.append(DocumentCanvasSegment.tableOfContents(id: "p\(pageIndex)-toc-\(blockIdx)"))
                    blockIdx += 1
                } else if kind == "table" {
                    if let uuid = UUID(uuidString: idStr), documentController.tables.contains(where: { $0.id == uuid }) {
                        segments.append(DocumentCanvasSegment.table(id: "p\(pageIndex)-table-\(uuid.uuidString)", tableId: uuid))
                        blockIdx += 1
                    } else if idStr.lowercased() == "budget", let firstTable = documentController.tables.first {
                        segments.append(DocumentCanvasSegment.table(id: "p\(pageIndex)-table-\(firstTable.id.uuidString)", tableId: firstTable.id))
                        blockIdx += 1
                    } else if let found = documentController.tables.first(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) {
                        segments.append(DocumentCanvasSegment.table(id: "p\(pageIndex)-table-\(found.id.uuidString)", tableId: found.id))
                        blockIdx += 1
                    }
                } else if kind == "image" {
                    if let uuid = UUID(uuidString: idStr), documentController.images.contains(where: { $0.id == uuid }) {
                        segments.append(DocumentCanvasSegment.image(id: "p\(pageIndex)-image-\(uuid.uuidString)", imageId: uuid))
                        blockIdx += 1
                    } else if let found = documentController.images.first(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) {
                        segments.append(DocumentCanvasSegment.image(id: "p\(pageIndex)-image-\(found.id.uuidString)", imageId: found.id))
                        blockIdx += 1
                    }
                } else if kind == "video" {
                    if let uuid = UUID(uuidString: idStr), documentController.videos.contains(where: { $0.id == uuid }) {
                        segments.append(DocumentCanvasSegment.video(id: "p\(pageIndex)-video-\(uuid.uuidString)", videoId: uuid))
                        blockIdx += 1
                    } else if let found = documentController.videos.first(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) {
                        segments.append(DocumentCanvasSegment.video(id: "p\(pageIndex)-video-\(found.id.uuidString)", videoId: found.id))
                        blockIdx += 1
                    }
                }
            }

            lastLocation = matchRange.location + matchRange.length
        }

        if lastLocation < nsContent.length {
            let textRange = NSRange(location: lastLocation, length: nsContent.length - lastLocation)
            let chunkText = nsContent.substring(with: textRange)
            segments.append(DocumentCanvasSegment.text(id: "p\(pageIndex)-text-\(textIdx)", textIndex: textIdx, initialContent: chunkText))
        }

        return segments
    }
}

// MARK: - Document Canvas Segment Model
public enum DocumentCanvasSegment: Identifiable {
    case text(id: String, textIndex: Int, initialContent: String)
    case table(id: String, tableId: UUID)
    case image(id: String, imageId: UUID)
    case video(id: String, videoId: UUID)
    case bibliography(id: String)
    case tableOfContents(id: String)

    public var id: String {
        switch self {
        case .text(let id, _, _): return id
        case .table(let id, _): return id
        case .image(let id, _): return id
        case .video(let id, _): return id
        case .bibliography(let id): return id
        case .tableOfContents(let id): return id
        }
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
        .frame(width: width, height: height, alignment: .topLeading)
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
    let onImportWordOrPDF: () -> Void
    let onSave: () -> Void
    let onExportDocx: () -> Void
    let onExportPDF: () -> Void
    let onPrint: () -> Void
    let onSettings: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .lettersNewDocument)) { _ in onNew() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersOpenDocument)) { _ in onOpen() }
            .onReceive(NotificationCenter.default.publisher(for: .lettersImportWordOrPDF)) { _ in onImportWordOrPDF() }
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


@MainActor
public class LettersDocumentController: ObservableObject {
    @Published public var title: String
    @Published public var rawText: String
    @Published public var richTextData: Data?
    
    @Published public var document: DocumentModel
    @Published public var tables: [StudioTableData]
    @Published public var images: [StudioImageBlock]
    @Published public var videos: [StudioVideoBlock]
    @Published public var citationStyle: CitationStyle
    
    @Published public var pageSize: PageSizePreset
    @Published public var marginPreset: MarginPreset
    @Published public var margins: PageMargins
    @Published public var coverBanner: CoverBannerConfig
    @Published public var headerFooter: HeaderFooterConfig
    
    @Published public var fontFamily: String
    @Published public var fontSize: CGFloat
    @Published public var lineSpacing: CGFloat
    @Published public var paragraphSpacing: CGFloat
    @Published public var textAlignment: TextAlignment
    
    public init(
        title: String = "Untitled Document",
        rawText: String = "",
        richTextData: Data? = nil,
        document: DocumentModel = DocumentModel(title: "Untitled", blocks: [], sources: [String: Source](), pageSize: .letter, margins: PageMargins(top: 72, bottom: 72, left: 72, right: 72)),
        tables: [StudioTableData] = [],
        images: [StudioImageBlock] = [],
        videos: [StudioVideoBlock] = [],
        citationStyle: CitationStyle = .apa7,
        pageSize: PageSizePreset = .letter,
        marginPreset: MarginPreset = .normal,
        margins: PageMargins = PageMargins(top: 72, bottom: 72, left: 72, right: 72),
        coverBanner: CoverBannerConfig = CoverBannerConfig(),
        headerFooter: HeaderFooterConfig = HeaderFooterConfig(),
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        lineSpacing: CGFloat = 1.15,
        paragraphSpacing: CGFloat = 12.0,
        textAlignment: TextAlignment = .leading
    ) {
        self.title = title
        self.rawText = rawText
        self.richTextData = richTextData
        self.document = document
        self.tables = tables
        self.images = images
        self.videos = videos
        self.citationStyle = citationStyle
        self.pageSize = pageSize
        self.marginPreset = marginPreset
        self.margins = margins
        self.coverBanner = coverBanner
        self.headerFooter = headerFooter
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.textAlignment = textAlignment
    }
    
    private var activeUndoManager: UndoManager? {
        NSApp.keyWindow?.undoManager ?? NSApp.mainWindow?.undoManager
    }
    
    public func performMutation<Value>(
        keyPath: ReferenceWritableKeyPath<LettersDocumentController, Value>,
        newValue: Value,
        actionName: String? = nil
    ) {
        let oldValue = self[keyPath: keyPath]
        let um = activeUndoManager
        
        self[keyPath: keyPath] = newValue
        
        um?.registerUndo(withTarget: self) { target in
            target.performMutation(keyPath: keyPath, newValue: oldValue, actionName: actionName)
        }
        
        if let actionName = actionName {
            um?.setActionName(actionName)
        }
    }

    public func mutateTable(id: UUID, actionName: String? = nil, mutation: (inout StudioTableData) -> Void) {
        guard let index = tables.firstIndex(where: { $0.id == id }) else { return }
        
        let oldTable = tables[index]
        var newTable = oldTable
        mutation(&newTable)
        
        let um = activeUndoManager
        self.tables[index] = newTable
        
        if let actionName = actionName {
            um?.registerUndo(withTarget: self) { target in
                target.mutateTable(id: id, actionName: actionName) { data in
                    data = oldTable
                }
            }
            um?.setActionName(actionName)
        }
    }
    
    public func addTable(_ table: StudioTableData) {
        let um = activeUndoManager
        um?.registerUndo(withTarget: self) { target in
            target.removeTable(id: table.id)
        }
        um?.setActionName("Insert Table")
        tables.append(table)
    }
    
    public func removeTable(id: UUID) {
        guard let index = tables.firstIndex(where: { $0.id == id }) else { return }
        let table = tables[index]
        let um = activeUndoManager
        
        um?.registerUndo(withTarget: self) { target in
            target.insertTable(table, at: index)
        }
        um?.setActionName("Delete Table")
        tables.remove(at: index)
    }
    
    public func insertTable(_ table: StudioTableData, at index: Int) {
        let um = activeUndoManager
        um?.registerUndo(withTarget: self) { target in
            target.removeTable(id: table.id)
        }
        um?.setActionName("Insert Table")
        tables.insert(table, at: index)
    }
}
