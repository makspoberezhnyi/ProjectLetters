import Foundation

let path = "macos/LettersApp/Sources/LettersKit/AIGateway.swift"
var content = try! String(contentsOfFile: path)

let target = """
public struct AIChatMessage: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var role: String // "user" or "assistant"
    public var content: String
    public var timestamp: Date

    public init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
"""

let replacement = """
public struct AIChatMessage: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var role: String // "user" or "assistant"
    public var content: String
    public var reasoning: String?
    public var reasoningDuration: TimeInterval?
    public var isGenerating: Bool
    public var timestamp: Date

    public init(id: UUID = UUID(), role: String, content: String, reasoning: String? = nil, reasoningDuration: TimeInterval? = nil, isGenerating: Bool = false, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.reasoningDuration = reasoningDuration
        self.isGenerating = isGenerating
        self.timestamp = timestamp
    }
}
"""

content = content.replacingOccurrences(of: target, with: replacement)
try! content.write(toFile: path, atomically: true, encoding: .utf8)
