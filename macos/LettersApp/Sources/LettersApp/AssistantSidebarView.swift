import SwiftUI
import LettersKit

public struct AssistantSidebarView: View {
    @State private var messages: [AIChatMessage] = []
    @State private var inputPrompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var selectedProvider: AIProvider = .anthropic
    @State private var apiKeyInput: String = ""
    @State private var showingKeyConfig: Bool = false
    let currentDocumentContext: () -> String

    public init(currentDocumentContext: @escaping () -> String) {
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
                        .font(.headline)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                Button {
                    showingKeyConfig.toggle()
                } label: {
                    Image(systemName: "key.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Configure BYOK API Keys")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if showingKeyConfig {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter \(selectedProvider.rawValue) API Key")
                        .font(.caption.bold())
                    SecureField("sk-...", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save to Keychain") {
                            Task {
                                try? await AIGateway.shared.storeKey(provider: selectedProvider, key: apiKeyInput)
                                showingKeyConfig = false
                                apiKeyInput = ""
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
                .padding(12)
                .background(Color.accentColor.opacity(0.08))
                Divider()
            }

            // Chat stream history
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Ask Letters Copilot")
                                    .font(.headline)
                                Text("Summarize sections, improve flow, generate citations, or refine style.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                            .padding(.horizontal)
                        }

                        ForEach(messages) { msg in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: msg.role == "user" ? "person.circle.fill" : "sparkles.rectangle.stack.fill")
                                    .foregroundColor(msg.role == "user" ? .blue : .purple)
                                    .font(.system(size: 16))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(msg.role == "user" ? "You" : "Letters Assistant")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    Text(msg.content)
                                        .font(.system(size: 13))
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(10)
                            .background(msg.role == "user" ? Color.primary.opacity(0.03) : Color.accentColor.opacity(0.06))
                            .cornerRadius(8)
                            .id(msg.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Prompt input
            HStack(spacing: 8) {
                TextField("Ask assistant...", text: $inputPrompt)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(inputPrompt.isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(inputPrompt.isEmpty && !isGenerating)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 260)
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
                await MainActor.run {
                    if let idx = messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        messages[idx].content = "⚠️ [Error]: \(error.localizedDescription)"
                    }
                }
            }
            await MainActor.run {
                isGenerating = false
            }
        }
    }
}
