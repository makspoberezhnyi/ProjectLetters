import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

public struct InlineAICanvasEditorView: View {
    let selectedText: String
    let fullDocumentContext: String
    var onAccept: (String) -> Void
    var onInsertBelow: (String) -> Void
    var onDismiss: () -> Void

    @State private var userPrompt: String = ""
    @State private var generatedResult: String = ""
    @State private var isStreaming: Bool = false
    @State private var errorMessage: String? = nil
    @State private var streamTask: Task<Void, Never>? = nil
    @State private var showDiff: Bool = false
    @FocusState private var isPromptFocused: Bool

    // Quick Prompt Presets
    private let promptPresets: [(icon: String, label: String, prompt: String)] = [
        ("wand.and.stars", "Polish Flow", "Improve flow, clarity, and elegance while preserving core meaning."),
        ("arrow.down.right.and.arrow.up.left", "Make Shorter", "Make this text more concise, direct, and punchy without losing key facts."),
        ("text.badge.plus", "Expand", "Expand this text with rich academic detail, background context, and depth."),
        ("checkmark.shield", "Fix Grammar", "Fix all grammar, spelling, and punctuation errors cleanly."),
        ("graduationcap", "Academic Tone", "Rewrite this text in a formal academic journal style with sophisticated prose."),
        ("character.book.closed", "Translate (EN)", "Translate this text into fluent, natural English."),
        ("list.bullet", "Bullet Summary", "Convert this text into clean, structured bullet points.")
    ]

    public init(
        selectedText: String,
        fullDocumentContext: String = "",
        onAccept: @escaping (String) -> Void,
        onInsertBelow: @escaping (String) -> Void = { _ in },
        onDismiss: @escaping () -> Void
    ) {
        self.selectedText = selectedText
        self.fullDocumentContext = fullDocumentContext
        self.onAccept = onAccept
        self.onInsertBelow = onInsertBelow
        self.onDismiss = onDismiss
    }

    private var selectedProvider: AIProvider {
        if AIGateway.findClaudeExecutable() != nil {
            return .claudeCLI
        } else if AIGateway.shared.getKey(provider: .google) != nil {
            return .google
        } else if AIGateway.shared.getKey(provider: .anthropic) != nil {
            return .anthropic
        } else if AIGateway.shared.getKey(provider: .openAI) != nil {
            return .openAI
        }
        return .claudeCLI
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Header Bar: Title, Context Snippet & Close
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Ask AI on Canvas")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                }

                // Selected text excerpt preview pill
                Text("“\(selectedText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(38))... ”")
                    .font(.system(size: 10.5, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))

                Spacer()

                // Provider Badge
                HStack(spacing: 3) {
                    Circle()
                        .fill(isStreaming ? Color.green : Color.accentColor)
                        .frame(width: 5, height: 5)
                    Text(selectedProvider == .claudeCLI ? "Claude Pro" : selectedProvider.badgeLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.05), in: Capsule())

                // Dismiss Button
                Button(action: {
                    stopGeneration()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close (Esc)")
            }

            // 2. Input Field & Action Buttons (When not generated yet or when refining)
            if generatedResult.isEmpty && !isStreaming {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        TextField("What changes should AI make to this text?...", text: $userPrompt)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5))
                            .focused($isPromptFocused)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                            )
                            .onSubmit {
                                if !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    runAICommand(prompt: userPrompt)
                                }
                            }

                        Button(action: {
                            if !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                runAICommand(prompt: userPrompt)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Generate")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6.5)
                            .background(
                                userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary.opacity(0.2)
                                    : Color.accentColor,
                                in: RoundedRectangle(cornerRadius: 7)
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // Quick Prompt Preset Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(promptPresets, id: \.label) { preset in
                                Button(action: {
                                    userPrompt = preset.label
                                    runAICommand(prompt: preset.prompt)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: preset.icon)
                                            .font(.system(size: 9.5))
                                            .foregroundColor(.purple)
                                        Text(preset.label)
                                            .font(.system(size: 10.5, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3.5)
                                    .background(Color.primary.opacity(0.04), in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // 3. Streaming / Generation In-Progress View
            if isStreaming {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.65)
                            .frame(width: 14, height: 14)
                        Text("Claude is editing selection...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Stop") {
                            stopGeneration()
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }

                    ScrollView {
                        Text(generatedResult.isEmpty ? "Thinking..." : generatedResult)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 120)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            // 4. Result View with Diff Comparison & Accept / Insert / Discard Actions
            if !generatedResult.isEmpty && !isStreaming {
                VStack(alignment: .leading, spacing: 8) {
                    // Diff / Comparison Toggle
                    HStack {
                        Text("PROPOSED REVISION")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)

                        Spacer()

                        // Word count delta badge
                        let originalWords = selectedText.split(separator: " ").count
                        let newWords = generatedResult.split(separator: " ").count
                        let delta = newWords - originalWords
                        Text(delta >= 0 ? "+\(delta) words" : "\(delta) words")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(delta >= 0 ? .green : .orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))

                        Button(action: { showDiff.toggle() }) {
                            HStack(spacing: 3) {
                                Image(systemName: showDiff ? "eye.slash" : "arrow.left.arrow.right")
                                    .font(.system(size: 9))
                                Text(showDiff ? "Hide Original" : "Compare")
                                    .font(.system(size: 9.5, weight: .medium))
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }

                    if showDiff {
                        // Side-by-side or stacked diff view
                        VStack(alignment: .leading, spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Original:")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(selectedText)
                                    .font(.system(size: 11, design: .serif))
                                    .foregroundColor(.secondary)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI Revision:")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(generatedResult)
                                    .font(.system(size: 11.5, design: .serif))
                                    .foregroundColor(.primary)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .frame(maxHeight: 140)
                    } else {
                        // Clean Proposed Text Scrollbox
                        ScrollView {
                            Text(generatedResult)
                                .font(.system(size: 12.5, design: .serif))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 120)
                        .background(Color.accentColor.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                        )
                    }

                    // Decision Button Row
                    HStack(spacing: 8) {
                        // 1. Accept & Replace (Primary)
                        Button(action: {
                            onAccept(cleanOutput(generatedResult))
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Accept & Replace")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.defaultAction)
                        .help("Replace selected text with revision (Return)")

                        // 2. Insert Below
                        Button(action: {
                            onInsertBelow(cleanOutput(generatedResult))
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Insert Below")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5.5)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // 3. Refine / Try Again
                        Button(action: {
                            generatedResult = ""
                            userPrompt = ""
                            isPromptFocused = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 9.5))
                                Text("Refine")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        // 4. Discard
                        Button("Discard") {
                            stopGeneration()
                            onDismiss()
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                    }
                }
            }

            // 5. Error View
            if let err = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    Text(err)
                        .font(.system(size: 10.5))
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                    Button("Retry") {
                        errorMessage = nil
                        if !userPrompt.isEmpty {
                            runAICommand(prompt: userPrompt)
                        }
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .frame(width: 480)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.4), Color.purple.opacity(0.2), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
        .onAppear {
            isPromptFocused = true
        }
    }

    private func stopGeneration() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    private func runAICommand(prompt: String) {
        stopGeneration()
        errorMessage = nil
        generatedResult = ""
        isStreaming = true

        let systemInstruction = """
        You are Letters Inline Editor. Your role is to transform the user's selected text according to their instruction.
        CRITICAL RULES:
        1. Return ONLY the transformed replacement text.
        2. Do NOT add preamble like "Here is your text:" or quotes around the result.
        3. Maintain formatting, tone, and factual accuracy.
        4. If the instruction is a question, answer it directly in relation to the selected text.
        """

        let context = """
        Selected text to edit:
        \"\"\"
        \(selectedText)
        \"\"\"

        Document Context (Surrounding context for coherence):
        \"\"\"
        \(fullDocumentContext.prefix(1500))
        \"\"\"
        """

        let targetProvider = selectedProvider

        streamTask = Task {
            do {
                try await AIGateway.shared.streamCompletion(
                    prompt: prompt,
                    contextText: context,
                    provider: targetProvider,
                    systemPrompt: systemInstruction,
                    onToken: { token in
                        Task { @MainActor in
                            self.generatedResult += token
                        }
                    }
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                self.isStreaming = false
            }
        }
    }

    private func cleanOutput(_ text: String) -> String {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("\"") && clean.hasSuffix("\"") && clean.count > 2 {
            clean = String(clean.dropFirst().dropLast())
        }
        return clean
    }
}
