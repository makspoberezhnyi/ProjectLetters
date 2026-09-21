import Foundation

let path = "macos/LettersApp/Sources/LettersApp/AssistantSidebarView.swift"
var content = try! String(contentsOfFile: path)

let target = """
            // Content & Action Blocks
            VStack(alignment: .leading, spacing: 10) {
                let cleanText = extractDisplayableContent(from: msg.content)
                if !cleanText.isEmpty || !isGenerating {
                    Text(cleanText.isEmpty && isGenerating ? "Thinking..." : cleanText)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                }

                // AI Document Tool Action Cards
"""

let replacement = """
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
"""

content = content.replacingOccurrences(of: target, with: replacement)
try! content.write(toFile: path, atomically: true, encoding: .utf8)
