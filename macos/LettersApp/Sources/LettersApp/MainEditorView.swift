import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct MainEditorView: View {
    @State private var document = DocumentModel(
        title: "Executive Summary & Research Report",
        blocks: [
            .heading(level: .heading1, runs: [TextRun(text: "Executive Summary", bold: true)]),
            .paragraph(runs: [
                TextRun(text: "Letters is a high-performance document processor combining native DOCX fidelity, linked source management, and dynamic style verification.")
            ], alignment: "left"),
            .heading(level: .heading2, runs: [TextRun(text: "Key Capabilities", bold: true)]),
            .bulletItem(runs: [TextRun(text: "Headless Rust Core for lossless OpenXML parsing")], indentLevel: 0),
            .bulletItem(runs: [TextRun(text: "Native TextKit 2 viewport rendering for massive documents")], indentLevel: 0),
            .bulletItem(runs: [TextRun(text: "Universal BYOK AI gateway with streaming assistant")], indentLevel: 0)
        ]
    )

    @State private var rawText: String = """
    # Executive Summary
    Letters is a high-performance document processor combining native DOCX fidelity, linked source management, and dynamic style verification.

    ## Key Capabilities
    * Headless Rust Core for lossless OpenXML parsing
    * Native TextKit 2 viewport rendering for massive documents
    * Universal BYOK AI gateway with streaming assistant
    """

    @State private var selectedBlockIndex: Int? = 0
    @State private var selectedText: String = ""
    @State private var selectionRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showInspector: Bool = true
    @State private var activeInspectorTab: InspectorTab = .assistant
    @State private var activeCitationStyle: CitationStyle = .apa7
    @State private var showCommandPalette: Bool = false
    @State private var lintIssues: [StyleLintMatch] = []

    enum InspectorTab: String, CaseIterable {
        case assistant = "Copilot"
        case sources = "Sources"
        case linter = "Style Lint"
    }

    public init() {}

    public var body: some View {
        NavigationSplitView {
            DocumentOutlineView(document: $document, selectedBlockIndex: $selectedBlockIndex)
                .frame(minWidth: 200, idealWidth: 220)
        } detail: {
            HSplitView {
                // Main Document Canvas
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        // Document Canvas
                        TextKit2EditorView(
                            text: $rawText,
                            selectedText: $selectedText,
                            selectionRange: $selectionRange,
                            onSelectionChanged: { _, _ in
                                // Selection updated asynchronously
                            }
                        )
                        .background(Color(NSColor.textBackgroundColor))
                    }

                    // Floating selection menu
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
                                activeInspectorTab = .assistant
                                showInspector = true
                            },
                            onCite: {
                                activeInspectorTab = .sources
                                showInspector = true
                            }
                        )
                        .padding(.top, 24)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(minWidth: 400)

                // Right Inspector (AI Assistant / Sources / Style Linter)
                if showInspector {
                    VStack(spacing: 0) {
                        Picker("Tab", selection: $activeInspectorTab) {
                            ForEach(InspectorTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(10)

                        Divider()

                        switch activeInspectorTab {
                        case .assistant:
                            AssistantSidebarView {
                                rawText
                            }
                        case .sources:
                            SourceManagerView(sources: $document.sources, activeStyle: $activeCitationStyle)
                        case .linter:
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Style & Tone Warnings (\(lintIssues.count))")
                                        .font(.caption.bold())
                                    Spacer()
                                    Button("Check") {
                                        runLinter()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(12)

                                Divider()

                                List(lintIssues) { issue in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .font(.caption)
                                            Text(issue.ruleId)
                                                .font(.caption.bold())
                                        }
                                        Text(issue.message)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let sugg = issue.suggestion {
                                            Text("Suggestion: \(sugg)")
                                                .font(.caption2)
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showCommandPalette.toggle()
                } label: {
                    Label("Command Palette", systemImage: "command")
                }
                .help("Command Palette (Cmd+K)")

                Button {
                    exportDocx()
                } label: {
                    Label("Export DOCX", systemImage: "arrow.down.doc")
                }
                .help("Export Native DOCX")

                Button {
                    showInspector.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle AI & Citations Sidebar")
            }
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView(isPresented: $showCommandPalette, commands: paletteCommands)
        }
        .onAppear {
            runLinter()
        }
    }

    private var paletteCommands: [CommandItem] {
        [
            CommandItem(title: "Export to Word (.docx)", subtitle: "Generate native lossless DOCX container", icon: "doc.fill", shortcut: "⌘E") {
                exportDocx()
            },
            CommandItem(title: "Toggle AI Assistant", subtitle: "Open BYOK Copilot companion", icon: "sparkles", shortcut: "⌘J") {
                activeInspectorTab = .assistant
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
                activeInspectorTab = .linter
                showInspector = true
            }
        ]
    }

    private func runLinter() {
        lintIssues = CoreBridge.shared.lint(text: rawText, profile: "academic")
    }

    private func exportDocx() {
        if let data = CoreBridge.shared.exportDocx(document: document) {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.init(filenameExtension: "docx")!]
            panel.nameFieldStringValue = "Document.docx"
            if panel.runModal() == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }
}
