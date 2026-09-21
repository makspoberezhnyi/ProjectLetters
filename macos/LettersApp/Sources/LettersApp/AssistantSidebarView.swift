import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

public struct AssistantSidebarView: View {
    @Binding var rawText: String
    @Binding var selectedText: String
    var onInsertTable: ((StudioTableData) -> Void)?
    var onInsertSource: ((Source) -> Void)?
    var onInsertHeading: ((Int, String) -> Void)?
    var onSetMargins: ((String) -> Void)?
    var onInsertPageBreak: (() -> Void)?
    var onInsertTOC: (() -> Void)?
    var onInsertBibliography: (() -> Void)?
    var onToast: ((String) -> Void)?
    var onClose: (() -> Void)? = nil
    let currentDocumentContext: () -> String

    @State private var messages: [AIChatMessage] = []
    @State private var inputPrompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var isClaudeInstalled: Bool = false
    @State private var claudeExecutablePath: String? = nil
    @State private var isTestingConnection: Bool = false
    @State private var testResult: (success: Bool, message: String)? = nil
    @State private var showingConnectSheet: Bool = false
    @State private var sidebarWidth: CGFloat = 390
    @State private var appliedActionIds: Set<String> = []
    @FocusState private var isInputFocused: Bool

    public init(
        rawText: Binding<String> = .constant(""),
        selectedText: Binding<String> = .constant(""),
        onInsertTable: ((StudioTableData) -> Void)? = nil,
        onInsertSource: ((Source) -> Void)? = nil,
        onInsertHeading: ((Int, String) -> Void)? = nil,
        onSetMargins: ((String) -> Void)? = nil,
        onInsertPageBreak: (() -> Void)? = nil,
        onInsertTOC: (() -> Void)? = nil,
        onInsertBibliography: (() -> Void)? = nil,
        onToast: ((String) -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        currentDocumentContext: @escaping () -> String
    ) {
        self._rawText = rawText
        self._selectedText = selectedText
        self.onInsertTable = onInsertTable
        self.onInsertSource = onInsertSource
        self.onInsertHeading = onInsertHeading
        self.onSetMargins = onSetMargins
        self.onInsertPageBreak = onInsertPageBreak
        self.onInsertTOC = onInsertTOC
        self.onInsertBibliography = onInsertBibliography
        self.onToast = onToast
        self.onClose = onClose
        self.currentDocumentContext = currentDocumentContext
    }

    private var selectedWordCount: Int {
        EditorPerformanceCache.countWords(in: selectedText)
    }

    private var documentWordCount: Int {
        EditorPerformanceCache.countWords(in: rawText)
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Smooth Left-Edge Drag Resize Handle
            resizeHandle

            VStack(spacing: 0) {
                // 1. Header
                copilotHeader

                Divider()
                    .background(StudioTheme.border)

                // 2. Active Context Strip
                contextStatusStrip

                Divider()
                    .background(StudioTheme.border.opacity(0.6))

                // 3. Main Body: Minimal Empty State OR Chat Stream
                ZStack {
                    if messages.isEmpty {
                        minimalEmptyState
                    } else {
                        chatHistoryStream
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .background(StudioTheme.border)

                // 4. Floating Glass Prompt Input Bar
                copilotInputBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .background(StudioTheme.panelBackground.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                StudioTheme.luminousPurple.opacity(0.5),
                                StudioTheme.luminousBlue.opacity(0.2),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 28, x: 0, y: 12)
        }
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity)
        .sheet(isPresented: $showingConnectSheet) {
            connectClaudeSheet
        }
        .onAppear {
            checkClaudeStatus()
        }
    }

    private func checkClaudeStatus() {
        if let path = AIGateway.findClaudeExecutable() {
            isClaudeInstalled = true
            claudeExecutablePath = path
        } else {
            isClaudeInstalled = false
            claudeExecutablePath = nil
        }
    }

    // MARK: - Drag Resize Handle
    private var resizeHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 10)
                .contentShape(Rectangle())

            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 3, height: 32)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newWidth = sidebarWidth - value.translation.width
                    sidebarWidth = max(280, min(800, newWidth))
                }
        )
        .onHover { hovering in
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Header
    private var copilotHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [StudioTheme.luminousPurple, StudioTheme.luminousBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .shadow(color: StudioTheme.luminousPurple.opacity(0.4), radius: 8, x: 0, y: 2)

                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Letters Assistant")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            // Status pill
            Button {
                showingConnectSheet = true
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isClaudeInstalled ? StudioTheme.luminousEmerald : StudioTheme.luminousAmber)
                        .frame(width: 6, height: 6)

                    Text(isClaudeInstalled ? "Claude Connected" : "Connect Claude")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            // Settings Button
            Button {
                showingConnectSheet = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(Color.primary.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Claude connection settings")

            // Close Button
            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.04), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close assistant")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.15))
    }

    // MARK: - Context Status Strip
    private var contextStatusStrip: some View {
        HStack(spacing: 6) {
            if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: "selection.pin.in.out")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(StudioTheme.luminousCyan)

                Text("Target: Selected Passage (\(selectedWordCount) words)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(StudioTheme.luminousCyan)
            } else {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("Context: Active Document (\(documentWordCount) words)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            !selectedText.isEmpty
                ? StudioTheme.luminousCyan.opacity(0.08)
                : Color.primary.opacity(0.02)
        )
    }

    // MARK: - Minimal Clean Empty State
    private var minimalEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(StudioTheme.luminousPurple.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [StudioTheme.luminousPurple, StudioTheme.luminousBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 6) {
                Text("How can I assist your document?")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Text("Ask Claude to write, format headings, create calculation tables, or add citations.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // 3 Clean Inspiration Prompts
            VStack(spacing: 8) {
                inspirationChip("✦ Insert a comparison table with metrics") {
                    sendDirectPrompt("Create a 3x3 smart table comparing Key Metrics across Q1, Q2, and Q3 with numeric values.")
                }
                inspirationChip("✦ Improve vocabulary & academic flow") {
                    let target = !selectedText.isEmpty ? selectedText : rawText
                    sendDirectPrompt("Polish and elevate the academic vocabulary and clarity of the following text:\n\n\(target)")
                }
                inspirationChip("✦ Suggest APA literature citations") {
                    let target = !selectedText.isEmpty ? selectedText : rawText
                    sendDirectPrompt("Analyze the claims in this text and suggest relevant academic citations in APA 7 format:\n\n\(target)")
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func inspirationChip(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.85))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(StudioTheme.surfaceHighlight.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat History Stream
    private var chatHistoryStream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { msg in
                        chatBubble(msg: msg)
                            .id(msg.id)
                    }

                    if isGenerating {
                        streamingLoadingIndicator
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func chatBubble(msg: AIChatMessage) -> some View {
        VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 6) {
            // Author row
            HStack(spacing: 5) {
                if msg.role == "user" {
                    Spacer()
                    Text("You")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(StudioTheme.luminousBlue)
                } else {
                    ZStack {
                        Circle()
                            .fill(StudioTheme.luminousPurple.opacity(0.2))
                            .frame(width: 18, height: 18)
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(StudioTheme.luminousPurple)
                    }
                    Text("Letters Assistant")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
            }

            // Content & Action Blocks
            VStack(alignment: .leading, spacing: 10) {
                // Thinking & Reasoning Component
                if let reasoning = msg.reasoning, !reasoning.isEmpty {
                    AIThinkingView(
                        reasoningText: reasoning,
                        isGenerating: msg.isGenerating,
                        durationSeconds: msg.reasoningDuration,
                        initiallyExpanded: msg.isGenerating
                    )
                } else if msg.isGenerating && msg.content.isEmpty {
                    AIThinkingView(
                        reasoningText: "",
                        isGenerating: true,
                        initiallyExpanded: true
                    )
                }

                let cleanText = extractDisplayableContent(from: msg.content)
                if !cleanText.isEmpty {
                    Text(cleanText)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                }

                // AI Document Tool Action Cards
                if msg.role == "assistant" && !msg.content.isEmpty {
                    let actions = parseDocumentActions(from: msg.content)
                    ForEach(actions) { action in
                        documentActionCard(action: action, msgId: msg.id.uuidString)
                    }

                    // Markdown Table Action Card (if not already parsed as action)
                    if actions.isEmpty, let parsedTable = parseMarkdownTable(from: msg.content) {
                        smartTableActionCard(table: parsedTable, msgId: msg.id.uuidString)
                    }

                    // Default Action Buttons
                    if !msg.content.starts(with: "⚠️") {
                        Divider()
                            .background(Color.white.opacity(0.08))

                        HStack(spacing: 6) {
                            let docReadyText = extractCleanDocumentContent(from: msg.content)
                            if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button {
                                    applyTextToSelection(content: docReadyText)
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "selection.pin.in.out")
                                        Text("Replace Selection")
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3.5)
                                    .background(StudioTheme.luminousCyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundColor(StudioTheme.luminousCyan)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                appendToDocument(content: docReadyText)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus.circle")
                                    Text("Append")
                                }
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                                .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(docReadyText, forType: .string)
                                onToast?("✓ Copied document content")
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding(4)
                                    .background(Color.primary.opacity(0.05), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Copy clean document content")
                        }
                    }
                }
            }
            .padding(10)
            .background(
                msg.role == "user"
                    ? StudioTheme.luminousBlue.opacity(0.12)
                    : StudioTheme.surfaceHighlight.opacity(0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        msg.role == "user"
                            ? StudioTheme.luminousBlue.opacity(0.25)
                            : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Document Action Cards
    private func documentActionCard(action: AIDocumentAction, msgId: String) -> some View {
        let actionKey = "\(msgId)_\(action.id)"
        let isApplied = appliedActionIds.contains(actionKey)

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(action.color.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: action.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(action.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)

                Text(action.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                executeAction(action)
                appliedActionIds.insert(actionKey)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isApplied ? "checkmark" : "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(isApplied ? "Applied" : "Apply")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(
                    isApplied
                        ? Color.secondary.opacity(0.2)
                        : action.color.opacity(0.22),
                    in: Capsule()
                )
                .foregroundColor(isApplied ? .secondary : action.color)
            }
            .buttonStyle(.plain)
            .disabled(isApplied)
        }
        .padding(8)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(action.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func smartTableActionCard(table: StudioTableData, msgId: String) -> some View {
        let actionKey = "\(msgId)_table"
        let isApplied = appliedActionIds.contains(actionKey)

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(StudioTheme.luminousEmerald.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: "tablecells.badge.ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(StudioTheme.luminousEmerald)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Calculation Table")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)

                Text("\(table.headers.count) columns • \(table.rows.count) rows")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                onInsertTable?(table)
                appliedActionIds.insert(actionKey)
                onToast?("✓ Inserted Smart Table")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isApplied ? "checkmark" : "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(isApplied ? "Inserted" : "Insert Table")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(
                    isApplied
                        ? Color.secondary.opacity(0.2)
                        : StudioTheme.luminousEmerald.opacity(0.22),
                    in: Capsule()
                )
                .foregroundColor(isApplied ? .secondary : StudioTheme.luminousEmerald)
            }
            .buttonStyle(.plain)
            .disabled(isApplied)
        }
        .padding(8)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(StudioTheme.luminousEmerald.opacity(0.3), lineWidth: 1)
        )
    }

    private func executeAction(_ action: AIDocumentAction) {
        switch action.type {
        case .insertTable(let table):
            onInsertTable?(table)
            onToast?("✓ Inserted Smart Table")
        case .insertHeading(let level, let title):
            onInsertHeading?(level, title)
            onToast?("✓ Inserted Heading \(level)")
        case .insertCitation(let source):
            onInsertSource?(source)
            onToast?("✓ Added Citation: \(source.authors.first ?? source.title)")
        case .setMargins(let preset):
            onSetMargins?(preset)
            onToast?("✓ Applied Margins: \(preset.capitalized)")
        case .insertPageBreak:
            onInsertPageBreak?()
            onToast?("✓ Inserted Page Break")
        case .insertTOC:
            onInsertTOC?()
            onToast?("✓ Inserted Table of Contents")
        case .insertBibliography:
            onInsertBibliography?()
            onToast?("✓ Inserted Bibliography")
        case .replaceSelection(let text):
            applyTextToSelection(content: text)
        case .appendDocument(let text):
            appendToDocument(content: text)
        }
    }

    private var streamingLoadingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(StudioTheme.luminousPurple)
                .frame(width: 6, height: 6)
                .scaleEffect(isGenerating ? 1.3 : 0.8)
                .animation(.easeInOut(duration: 0.6).repeatForever(), value: isGenerating)

            Text("Synthesizing with Claude...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.leading, 8)
    }

    // MARK: - Input Bar
    private var copilotInputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask Claude or describe what to write or change...", text: $inputPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }

            if !messages.isEmpty {
                Button {
                    messages.removeAll()
                    appliedActionIds.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Clear conversation")
            }

            Button(action: isGenerating ? { isGenerating = false } : sendMessage) {
                ZStack {
                    Circle()
                        .fill(
                            inputPrompt.isEmpty && !isGenerating
                                ? LinearGradient(colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [StudioTheme.luminousPurple, StudioTheme.luminousBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 26, height: 26)

                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(inputPrompt.isEmpty && !isGenerating ? .secondary : .white)
                }
            }
            .buttonStyle(.plain)
            .disabled(inputPrompt.isEmpty && !isGenerating)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isInputFocused = true
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(StudioTheme.surfaceHighlight.opacity(0.8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(10)
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Friendly 1-Step Connect Claude Sheet
    private var connectClaudeSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(StudioTheme.luminousPurple.opacity(0.2))
                            .frame(width: 24, height: 24)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(StudioTheme.luminousPurple)
                    }

                    Text("Connect Claude to Letters")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                Button("Done") {
                    showingConnectSheet = false
                    checkClaudeStatus()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(18)
            .background(Color.black.opacity(0.2))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Use Your Existing Claude Subscription")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Letters connects directly to Anthropic's Claude on your Mac. You don't need to pay for developer API tokens—your regular Claude subscription covers everything.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }

                    // 1-Time Setup Box
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1-Time Setup in Terminal")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Open Terminal on your Mac and run this single command to install and log in:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        HStack {
                            Text("npm install -g @anthropic-ai/claude-code && claude")
                                .font(.system(size: 11))
                                .foregroundColor(StudioTheme.luminousCyan)
                                .textSelection(.enabled)

                            Spacer()

                            Button {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString("npm install -g @anthropic-ai/claude-code && claude", forType: .string)
                                onToast?("✓ Copied command to clipboard")
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(14)
                    .background(StudioTheme.surfaceHighlight.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )

                    // Test Connection Button & Result
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            runConnectionTest()
                        } label: {
                            HStack {
                                if isTestingConnection {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.trailing, 4)
                                } else {
                                    Image(systemName: "bolt.horizontal.circle.fill")
                                }
                                Text("Check Connection")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(StudioTheme.luminousPurple.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(StudioTheme.luminousPurple)
                        }
                        .buttonStyle(.plain)
                        .disabled(isTestingConnection)

                        if let res = testResult {
                            HStack(spacing: 6) {
                                Image(systemName: res.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(res.success ? StudioTheme.luminousEmerald : StudioTheme.luminousAmber)

                                Text(res.message)
                                    .font(.system(size: 11))
                                    .foregroundColor(res.success ? StudioTheme.luminousEmerald : StudioTheme.luminousAmber)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                (res.success ? StudioTheme.luminousEmerald : StudioTheme.luminousAmber).opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 420)
        .background(.ultraThinMaterial)
    }

    private func runConnectionTest() {
        isTestingConnection = true
        testResult = nil
        Task {
            let res = await AIGateway.shared.testConnection(provider: .claudeCLI)
            await MainActor.run {
                isTestingConnection = false
                testResult = (success: res.0, message: res.1)
                if res.0 {
                    isClaudeInstalled = true
                }
            }
        }
    }

    // MARK: - Document Messaging & Execution
    private func sendDirectPrompt(_ prompt: String) {
        inputPrompt = prompt
        sendMessage()
    }

    private func sendMessage() {
        let prompt = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        let userMsg = AIChatMessage(role: "user", content: prompt)
        messages.append(userMsg)
        inputPrompt = ""

        let assistantMsgId = UUID()
        let assistantMsg = AIChatMessage(id: assistantMsgId, role: "assistant", content: "", isGenerating: true)
        messages.append(assistantMsg)
        isGenerating = true

        let docContext = currentDocumentContext()

        let startDate = Date()
        Task {
            do {
                try await AIGateway.shared.streamCompletion(
                    prompt: prompt,
                    contextText: docContext,
                    provider: .claudeCLI,
                    onToken: { token in
                        Task { @MainActor in
                            if let idx = messages.firstIndex(where: { $0.id == assistantMsgId }) {
                                messages[idx].content += token
                            }
                        }
                    }
                )
            } catch {
                await MainActor.run {
                    if let idx = messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        messages[idx].content = "⚠️ [Letters Assistant Error]: \(error.localizedDescription)"
                    }
                }
            }
            await MainActor.run {
                isGenerating = false
                if let idx = messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    messages[idx].isGenerating = false
                    messages[idx].reasoningDuration = abs(startDate.timeIntervalSinceNow)
                }
            }
        }
    }

    private func normalizeSpacing(_ text: String) -> String {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while clean.contains("\n\n\n") {
            clean = clean.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return clean
    }

    private func applyTextToSelection(content: String) {
        let clean = normalizeSpacing(content)
        guard !clean.isEmpty else { return }
        guard !selectedText.isEmpty else {
            appendToDocument(content: clean)
            return
        }
        rawText = rawText.replacingOccurrences(of: selectedText, with: clean)
        selectedText = ""
        onToast?("✓ Replaced selection with assistant content")
    }

    private func appendToDocument(content: String) {
        let clean = normalizeSpacing(content)
        guard !clean.isEmpty else { return }
        if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rawText = clean
        } else {
            rawText = rawText.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + clean
        }
        onToast?("✓ Appended assistant content to document")
    }

    // MARK: - Helper Parsing Methods
    private func extractCleanDocumentContent(from text: String) -> String {
        // 1. If explicit [CONTENT]...[/CONTENT] tags exist, extract precisely that
        if let startTag = text.range(of: "[CONTENT]"),
           let endTag = text.range(of: "[/CONTENT]", range: startTag.upperBound..<text.endIndex) {
            let inner = text[startTag.upperBound..<endTag.lowerBound]
            return inner.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2. Strip out all [ACTION:...] tags
        var clean = extractDisplayableContent(from: text)

        // 3. Strip common bot conversational preambles
        let preamblePatterns = [
            "^\\s*(Here (is|are|'s) (the|your|a|an)?\\s*[^:\\n]+:?\\s*\\n+)",
            "^\\s*(Certainly!?|Sure!?|Of course!?|Absolutely!?|Here you go!?)\\s*(Here (is|are|'s) [^:\\n]+:?\\s*\\n*)?",
            "^\\s*(Below is (the|a|an)?\\s*[^:\\n]+:?\\s*\\n+)",
            "^\\s*(I have (prepared|created|generated|summarized|written|compiled)\\s*[^:\\n]+:?\\s*\\n+)"
        ]

        for pat in preamblePatterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                let ns = clean as NSString
                if let match = regex.firstMatch(in: clean, options: [], range: NSRange(location: 0, length: min(ns.length, 300))) {
                    clean = ns.replacingCharacters(in: match.range, with: "")
                }
            }
        }

        // 4. Strip common bot conversational postambles
        let postamblePatterns = [
            "(\\n+\\s*(Let me know if you (need|would like|want)|Hope this helps!?|Feel free to ask|Would you like me to|If you need anything else).*$)"
        ]

        for pat in postamblePatterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                let ns = clean as NSString
                if let match = regex.firstMatch(in: clean, options: [], range: NSRange(location: 0, length: ns.length)) {
                    clean = ns.replacingCharacters(in: match.range, with: "")
                }
            }
        }

        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractDisplayableContent(from text: String) -> String {
        var clean = text
        // Strip out [CONTENT] and [/CONTENT] markers
        clean = clean.replacingOccurrences(of: "[CONTENT]", with: "")
        clean = clean.replacingOccurrences(of: "[/CONTENT]", with: "")

        // Strip out [ACTION:...] markers for clean display
        while let rangeStart = clean.range(of: "[ACTION:") {
            if let rangeEnd = clean[rangeStart.lowerBound...].range(of: "]") {
                let fullRange = rangeStart.lowerBound..<rangeEnd.upperBound
                clean.removeSubrange(fullRange)
            } else {
                break
            }
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDocumentActions(from text: String) -> [AIDocumentAction] {
        var actions: [AIDocumentAction] = []
        let pattern = "\\[ACTION:([a-z_]+)\\s*(\\{.*?\\})?\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let actionName = nsText.substring(with: match.range(at: 1))
            let jsonPayload = match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound
                ? nsText.substring(with: match.range(at: 2))
                : "{}"

            let jsonData = jsonPayload.data(using: .utf8) ?? Data()
            let json = (try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]) ?? [:]

            switch actionName {
            case "insert_table":
                if let headers = json["headers"] as? [String], let rows = json["rows"] as? [[String]] {
                    let table = StudioTableData(headers: headers, rows: rows)
                    actions.append(AIDocumentAction(
                        title: "Smart Table",
                        subtitle: "\(headers.count) columns • \(rows.count) rows",
                        icon: "tablecells",
                        color: StudioTheme.luminousEmerald,
                        type: .insertTable(table)
                    ))
                }
            case "insert_heading":
                let level = json["level"] as? Int ?? 1
                let title = json["title"] as? String ?? "Section"
                actions.append(AIDocumentAction(
                    title: "Heading \(level)",
                    subtitle: "\"\(title)\"",
                    icon: "character.textbox",
                    color: StudioTheme.luminousCyan,
                    type: .insertHeading(level, title)
                ))
            case "insert_citation":
                let author = json["author"] as? String ?? "Unknown"
                let year = json["year"] as? Int ?? (Int(json["year"] as? String ?? "") ?? 2024)
                let title = json["title"] as? String ?? "Citation"
                let doi = json["doi"] as? String
                let source = Source(id: UUID().uuidString, sourceType: .journalArticle, authors: [author], year: year, title: title, doi: doi)
                actions.append(AIDocumentAction(
                    title: "Add Citation",
                    subtitle: "\(author) (\(year)) - \"\(title)\"",
                    icon: "quote.opening",
                    color: StudioTheme.luminousAmber,
                    type: .insertCitation(source)
                ))
            case "set_margins":
                let preset = json["preset"] as? String ?? "normal"
                actions.append(AIDocumentAction(
                    title: "Apply Margins",
                    subtitle: "\(preset.capitalized) layout",
                    icon: "doc.viewfinder",
                    color: StudioTheme.luminousPurple,
                    type: .setMargins(preset)
                ))
            case "insert_page_break":
                actions.append(AIDocumentAction(
                    title: "Page Break",
                    subtitle: "Force onto new page sheet",
                    icon: "pagebreak",
                    color: StudioTheme.luminousBlue,
                    type: .insertPageBreak
                ))
            case "insert_toc":
                actions.append(AIDocumentAction(
                    title: "Table of Contents",
                    subtitle: "Dynamic [[toc]] block",
                    icon: "list.bullet.indent",
                    color: StudioTheme.luminousCyan,
                    type: .insertTOC
                ))
            case "insert_bibliography":
                actions.append(AIDocumentAction(
                    title: "Bibliography",
                    subtitle: "Dynamic [[bibliography]] block",
                    icon: "books.vertical",
                    color: StudioTheme.luminousAmber,
                    type: .insertBibliography
                ))
            case "replace_selection":
                if let replaceText = json["text"] as? String {
                    actions.append(AIDocumentAction(
                        title: "Replace Selection",
                        subtitle: "\(EditorPerformanceCache.countWords(in: replaceText)) words",
                        icon: "selection.pin.in.out",
                        color: StudioTheme.luminousCyan,
                        type: .replaceSelection(replaceText)
                    ))
                }
            case "append_document":
                if let appendText = json["text"] as? String {
                    actions.append(AIDocumentAction(
                        title: "Append Section",
                        subtitle: "\(EditorPerformanceCache.countWords(in: appendText)) words",
                        icon: "plus.circle",
                        color: StudioTheme.luminousPurple,
                        type: .appendDocument(appendText)
                    ))
                }
            default:
                break
            }
        }

        return actions
    }

    private func parseMarkdownTable(from text: String) -> StudioTableData? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.starts(with: "|") && $0.hasSuffix("|") }

        guard lines.count >= 2 else { return nil }

        let headerLine = lines[0]
        let headers = headerLine.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !headers.isEmpty else { return nil }

        var rowStartIndex = 1
        if lines.count > 1 && lines[1].contains("-") {
            rowStartIndex = 2
        }

        var rows: [[String]] = []
        for i in rowStartIndex..<lines.count {
            let rowCols = lines[i].split(separator: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if !rowCols.isEmpty {
                var padded = rowCols
                while padded.count < headers.count {
                    padded.append("")
                }
                rows.append(Array(padded.prefix(headers.count)))
            }
        }

        guard !rows.isEmpty else { return nil }
        return StudioTableData(headers: headers, rows: rows)
    }
}

// MARK: - Supporting Document Action Types
public struct AIDocumentAction: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let icon: String
    public let color: Color
    public let type: ActionType

    public enum ActionType {
        case insertTable(StudioTableData)
        case insertHeading(Int, String)
        case insertCitation(Source)
        case setMargins(String)
        case insertPageBreak
        case insertTOC
        case insertBibliography
        case replaceSelection(String)
        case appendDocument(String)
    }
}
import SwiftUI

public struct AIThinkingView: View {
    let reasoningText: String
    let isGenerating: Bool
    let durationSeconds: TimeInterval?
    
    @State private var isExpanded: Bool
    @State private var isPulsing: Bool = false
    
    public init(reasoningText: String, isGenerating: Bool, durationSeconds: TimeInterval? = nil, initiallyExpanded: Bool = true) {
        self.reasoningText = reasoningText
        self.isGenerating = isGenerating
        self.durationSeconds = durationSeconds
        self._isExpanded = State(initialValue: initiallyExpanded)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Toggle Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isGenerating ? "sparkles" : "checkmark.circle.fill")
                        .foregroundColor(isGenerating ? .accentColor : .secondary)
                        .symbolEffect(.pulse, options: .repeating, isActive: isGenerating)
                    
                    Text(headerText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isGenerating ? .primary : .secondary)
                        .opacity(isGenerating && isPulsing ? 0.6 : 1.0)
                        
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .onAppear {
                if isGenerating {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: isGenerating) { newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    withAnimation {
                        isPulsing = false
                    }
                }
            }
            
            // Collapsible Content
            if isExpanded && !reasoningText.isEmpty {
                Text(reasoningText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.leading, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
    }
    
    private var headerText: String {
        if isGenerating {
            return "Thinking..."
        } else {
            if let duration = durationSeconds {
                return String(format: "Thought for %.1f seconds", duration)
            } else {
                return "Reasoning process"
            }
        }
    }
}
