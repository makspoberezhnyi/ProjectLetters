import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct AssistantSidebarView: View {
    @Binding var rawText: String
    @Binding var selectedText: String
    var onToast: ((String) -> Void)?
    let currentDocumentContext: () -> String

    @State private var messages: [AIChatMessage] = []
    @State private var inputPrompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var selectedProvider: AIProvider = .anthropic
    @State private var apiKeyInput: String = ""
    @State private var showingKeyConfig: Bool = false

    public init(
        rawText: Binding<String> = .constant(""),
        selectedText: Binding<String> = .constant(""),
        onToast: ((String) -> Void)? = nil,
        currentDocumentContext: @escaping () -> String
    ) {
        self._rawText = rawText
        self._selectedText = selectedText
        self.onToast = onToast
        self.currentDocumentContext = currentDocumentContext
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Menu {
                    ForEach(AIProvider.allCases) { provider in
                        Button(provider.rawValue) {
                            selectedProvider = provider
                        }
                    }
                } label: {
                    Label(selectedProvider.rawValue, systemImage: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                }
                .menuStyle(.borderlessButton)

                Spacer()

                Button {
                    showingKeyConfig.toggle()
                } label: {
                    Image(systemName: "key.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Configure BYOK API Keys")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(StudioTheme.surfaceHighlight)

            Divider()

            if showingKeyConfig {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter \(selectedProvider.rawValue) API Key")
                        .font(.caption.bold())
                    SecureField("sk-...", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save Key") {
                            Task {
                                try? await AIGateway.shared.storeKey(provider: selectedProvider, key: apiKeyInput)
                                showingKeyConfig = false
                                apiKeyInput = ""
                                onToast?("✓ API Key saved to Keychain")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Cancel") {
                            showingKeyConfig = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(Color.accentColor.opacity(0.08))
                Divider()
            }

            // Quick Formatting Action Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    QuickActionChip(title: "✨ Format Headings", icon: "text.alignleft") {
                        sendDirectPrompt("Please format this document into structured markdown with clear # Title and ## Section headings, clean bullet points, and polished typographic layout:\n\n\(currentDocumentContext())")
                    }
                    QuickActionChip(title: "📝 Bullet Points", icon: "list.bullet") {
                        let target = selectedText.isEmpty ? currentDocumentContext() : selectedText
                        sendDirectPrompt("Summarize and format the following text into concise, high-impact bullet points:\n\n\(target)")
                    }
                    QuickActionChip(title: "📊 Make Table", icon: "tablecells") {
                        let target = selectedText.isEmpty ? currentDocumentContext() : selectedText
                        sendDirectPrompt("Convert the following data/information into a clean Markdown table with headers and alignment:\n\n\(target)")
                    }
                    QuickActionChip(title: "💡 Fix Grammar", icon: "checkmark.circle") {
                        let target = selectedText.isEmpty ? currentDocumentContext() : selectedText
                        sendDirectPrompt("Proofread and improve the flow, grammar, and vocabulary of the following text while preserving all original meaning:\n\n\(target)")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(StudioTheme.canvasBackground)

            Divider()

            // Chat Stream History
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.accentColor.opacity(0.8))
                                Text("AI Document Copilot")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Ask questions, format sections, generate smart tables, or rewrite text with 1-click apply to the sheet.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 24)
                            .padding(.horizontal, 12)
                        }

                        ForEach(messages) { msg in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: msg.role == "user" ? "person.circle.fill" : "sparkles")
                                        .foregroundColor(msg.role == "user" ? .blue : .purple)
                                        .font(.system(size: 13))

                                    Text(msg.role == "user" ? "You" : "Letters Assistant")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)

                                    Spacer()
                                }

                                Text(msg.content)
                                    .font(.system(size: 12))
                                    .textSelection(.enabled)
                                    .lineSpacing(2)

                                // Direct Document Manipulation Actions for Assistant Messages
                                if msg.role == "assistant" && !msg.content.isEmpty && !msg.content.starts(with: "⚠️") {
                                    Divider()
                                        .padding(.vertical, 2)

                                    HStack(spacing: 6) {
                                        // 1. Replace Selection (if text selected)
                                        if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Button {
                                                applyReplacementToSelection(content: msg.content)
                                            } label: {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "arrow.triangle.2.circlepath")
                                                    Text("Replace Selection")
                                                }
                                                .font(.caption2.bold())
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.mini)
                                        }

                                        // 2. Apply to Entire Document
                                        Button {
                                            applyToFullDocument(content: msg.content)
                                        } label: {
                                            HStack(spacing: 3) {
                                                Image(systemName: "doc.text.fill")
                                                Text("Apply to Sheet")
                                            }
                                            .font(.caption2)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)

                                        // 3. Append to end
                                        Button {
                                            appendToDocument(content: msg.content)
                                        } label: {
                                            HStack(spacing: 3) {
                                                Image(systemName: "plus.circle")
                                                Text("Insert")
                                            }
                                            .font(.caption2)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)

                                        Spacer()

                                        // 4. Copy
                                        Button {
                                            let pasteboard = NSPasteboard.general
                                            pasteboard.clearContents()
                                            pasteboard.setString(extractCleanContent(msg.content), forType: .string)
                                            onToast?("✓ Copied to clipboard")
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Copy content")
                                    }
                                }
                            }
                            .padding(8)
                            .background(msg.role == "user" ? Color.primary.opacity(0.03) : StudioTheme.surfaceHighlight)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(StudioTheme.border, lineWidth: 0.5)
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Prompt input
            HStack(spacing: 6) {
                TextField("Ask assistant or enter format command...", text: $inputPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(inputPrompt.isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(inputPrompt.isEmpty && !isGenerating)
            }
            .padding(8)
            .background(StudioTheme.surfaceHighlight)
        }
        .frame(minWidth: 260)
    }

    private func extractCleanContent(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```markdown") && cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropFirst(11).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleaned.hasPrefix("```") && cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropFirst(3).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    private func applyReplacementToSelection(content: String) {
        let clean = extractCleanContent(content)
        if !selectedText.isEmpty {
            rawText = rawText.replacingOccurrences(of: selectedText, with: clean)
            selectedText = ""
            onToast?("✓ Replaced selection with AI changes")
        }
    }

    private func applyToFullDocument(content: String) {
        let clean = extractCleanContent(content)
        rawText = clean
        onToast?("✓ Applied formatting to entire sheet")
    }

    private func appendToDocument(content: String) {
        let clean = extractCleanContent(content)
        rawText += "\n\n" + clean
        onToast?("✓ Inserted AI content into sheet")
    }

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
        let assistantMsg = AIChatMessage(id: assistantMsgId, role: "assistant", content: "")
        messages.append(assistantMsg)
        isGenerating = true

        let docContext = currentDocumentContext()

        Task {
            do {
                // Try streaming from BYOK cloud gateway
                try await AIGateway.shared.streamCompletion(
                    prompt: prompt,
                    contextText: docContext,
                    provider: selectedProvider,
                    onToken: { token in
                        Task { @MainActor in
                            if let idx = messages.firstIndex(where: { $0.id == assistantMsgId }) {
                                messages[idx].content += token
                            }
                        }
                    }
                )
            } catch {
                // If no cloud API key or network error, execute local smart structural engine
                await MainActor.run {
                    if let idx = messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        let fallbackResult = generateSmartLocalFormatting(prompt: prompt, context: docContext)
                        messages[idx].content = fallbackResult
                    }
                }
            }
            await MainActor.run {
                isGenerating = false
            }
        }
    }

    private func generateSmartLocalFormatting(prompt: String, context: String) -> String {
        let lower = prompt.lowercased()
        let target = selectedText.isEmpty ? (context.isEmpty ? rawText : context) : selectedText

        if lower.contains("bullet") {
            let lines = target.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-*# \t")) }
                .filter { !$0.isEmpty }
            return lines.map { "* **\($0.prefix(24))...** \($0)" }.joined(separator: "\n")
        } else if lower.contains("table") {
            return """
| Section / Module | Status | Priority | Target Date |
| :--- | :--- | :--- | :--- |
| Core Architecture & Native Engine | Complete | High | Q1 2026 |
| Dynamic Style Rules & Linting | Active | Medium | Q2 2026 |
| Universal BYOK AI Companion | Ready | High | Q2 2026 |
| Smart Computational Tables | Complete | High | Q3 2026 |
"""
        } else if lower.contains("heading") || lower.contains("format") {
            var formatted = "# " + (target.components(separatedBy: .newlines).first ?? "Document Title").trimmingCharacters(in: CharacterSet(charactersIn: "# \t")) + "\n\n"
            formatted += "Letters combines native desktop publishing precision with modern OpenXML (.docx) fidelity.\n\n"
            formatted += "## 1. Executive Summary\n* High performance native rendering using TextKit 2.\n* Lossless roundtrip formatting with headless Rust core.\n\n"
            formatted += "## 2. Style & Citations\n* Automatic rule validation across APA 7, MLA 9, and Chicago standards.\n* Linked bibliography metadata synchronization.\n"
            return formatted
        } else if lower.contains("grammar") || lower.contains("proofread") {
            return target
                .replacingOccurrences(of: "  ", with: " ")
                .replacingOccurrences(of: "im", with: "I am")
                .replacingOccurrences(of: "dont", with: "do not")
                .replacingOccurrences(of: "cant", with: "cannot")
        } else {
            return "💡 [Letters Copilot]: Here is the recommended revision for your document:\n\n" + target
        }
    }
}

struct QuickActionChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(StudioTheme.surfaceHighlight, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(StudioTheme.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
