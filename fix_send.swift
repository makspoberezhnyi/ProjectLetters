import Foundation

let path = "macos/LettersApp/Sources/LettersApp/AssistantSidebarView.swift"
var content = try! String(contentsOfFile: path)

let target = """
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
"""

let replacement = """
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
"""

content = content.replacingOccurrences(of: target, with: replacement)

let target2 = """
            await MainActor.run {
                isGenerating = false
            }
"""

let replacement2 = """
            await MainActor.run {
                isGenerating = false
                if let idx = messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    messages[idx].isGenerating = false
                    messages[idx].reasoningDuration = abs(startDate.timeIntervalSinceNow)
                }
            }
"""

content = content.replacingOccurrences(of: target2, with: replacement2)
try! content.write(toFile: path, atomically: true, encoding: .utf8)
