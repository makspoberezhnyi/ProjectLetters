import SwiftUI
import AppKit
import UniformTypeIdentifiers
#if canImport(LettersKit)
import LettersKit
#endif

public struct MainEditorView: View {
    @State private var documentTitle: String = "Untitled Document"
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

## 1. Core Architecture
* **Headless Rust Core:** Beneath the UI runs a headless Rust engine for lossless OpenXML (.docx) generation.
* **TextKit 2 Viewport Rendering:** Ensures smooth scrolling and rendering on massive 100+ page documents.
* **Universal BYOK AI Gateway:** Connect personal API keys for Claude, GPT-4o, and Gemini with macOS Keychain security.

## 2. Linked Citations & Style Profiles
* Citations store raw fields (authors, year, DOI, publisher) rather than flat text.
* Switching between APA 7, MLA 9, Chicago, and Bluebook is a real-time re-render, never a rewrite.

## 3. Dynamic Smart Tables
* Tables support formulas (=A1 + B1) and inline variable referencing throughout the text.
"""

    @State private var selectedBlockIndex: Int? = 0
    @State private var selectedText: String = ""
    @State private var selectionRange: NSRange = NSRange(location: 0, length: 0)
    @State private var showInspector: Bool = true
    @State private var activeInspectorTab: InspectorTab = .assistant
    @State private var activeCitationStyle: CitationStyle = .apa7
    @State private var showCommandPalette: Bool = false
    @State private var lintIssues: [StyleLintMatch] = []
    @State private var toastMessage: String? = nil
    @State private var zoomScale: CGFloat = 1.0

    enum InspectorTab: String, CaseIterable {
        case assistant = "Copilot"
        case sources = "Sources"
        case linter = "Style Lint"
    }

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
        NavigationSplitView {
            DocumentOutlineView(document: $document, selectedBlockIndex: $selectedBlockIndex)
                .frame(minWidth: 200, idealWidth: 220)
        } detail: {
            HSplitView {
                // Workspace Canvas
                ZStack(alignment: .bottom) {
                    ScrollView([.vertical, .horizontal]) {
                        VStack(spacing: 24) {
                            // Top Document Title Header
                            HStack {
                                TextField("Document Title", text: $documentTitle)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 20, weight: .bold, design: .default))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: 500)

                                Spacer()

                                HStack(spacing: 8) {
                                    Button(action: saveDocumentAsDocx) {
                                        Label("Save as Word (.docx)", systemImage: "arrow.down.doc.fill")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                    Button(action: saveDocumentAsMarkdown) {
                                        Label("Save Markdown", systemImage: "doc.text")
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .frame(width: 816)
                            .padding(.top, 28)

                            // Realistic Paper Sheet Canvas
                            ZStack(alignment: .top) {
                                TextKit2EditorView(
                                    text: $rawText,
                                    selectedText: $selectedText,
                                    selectionRange: $selectionRange,
                                    onSelectionChanged: { _, _ in }
                                )
                                .frame(width: 816)
                                .frame(minHeight: 1056)
                                .background(Color(NSColor.textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                // Multi-layered realistic paper drop shadow
                                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                                .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 12)

                                // Floating selection contextual menu
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
                                    .padding(.top, 16)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.bottom, 64)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(NSColor.underPageBackgroundColor))

                    // Bottom Studio Status Bar Pill
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.alignleft")
                                .font(.caption2)
                            Text("\(wordCount) words")
                                .font(.caption.monospacedDigit())
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "character.cursor.ibeam")
                                .font(.caption2)
                            Text("\(characterCount) chars")
                                .font(.caption.monospacedDigit())
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("~\(readingTimeMinutes) min read")
                                .font(.caption)
                        }

                        Divider()
                            .frame(height: 12)

                        HStack(spacing: 4) {
                            Image(systemName: "quote.opening")
                                .font(.caption2)
                            Text(activeCitationStyle.displayName)
                                .font(.caption.bold())
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                    .padding(.bottom, 16)

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
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
                        .padding(.bottom, 64)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(minWidth: 500)

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
                Button(action: saveDocumentAsDocx) {
                    Label("Save as DOCX", systemImage: "arrow.down.doc.fill")
                }
                .help("Save Native Word .docx (Cmd+S)")
                .keyboardShortcut("s", modifiers: .command)

                Button {
                    showCommandPalette.toggle()
                } label: {
                    Label("Command Palette", systemImage: "command")
                }
                .help("Command Palette (Cmd+K)")

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
            CommandItem(title: "Save as Word Document (.docx)", subtitle: "Generate native lossless DOCX file", icon: "doc.fill", shortcut: "⌘S") {
                saveDocumentAsDocx()
            },
            CommandItem(title: "Export as Markdown (.md)", subtitle: "Save clean markdown text", icon: "doc.text", shortcut: "⌘⇧S") {
                saveDocumentAsMarkdown()
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
