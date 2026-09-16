import Foundation
import Security

public enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    case anthropic = "Anthropic"
    case openAI = "OpenAI"
    case google = "Google Gemini"

    public var id: String { rawValue }

    public var defaultModel: String {
        switch self {
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .openAI: return "gpt-4o"
        case .google: return "gemini-2.0-flash"
        }
    }
}

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

public actor AIGateway {
    public static let shared = AIGateway()

    private let keychainService = "com.letters.ai.credentials"

    public func storeKey(provider: AIProvider, key: String) throws {
        let account = provider.rawValue
        let data = Data(key.utf8)

        // Delete existing item if present
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        if !key.isEmpty {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw NSError(domain: "LettersKeychainError", code: Int(status))
            }
        }
    }

    public func getKey(provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func streamCompletion(
        prompt: String,
        contextText: String?,
        provider: AIProvider,
        systemPrompt: String = "You are Letters Assistant, an expert academic and professional document copilot. Provide direct, insightful assistance.",
        onToken: @Sendable (String) -> Void
    ) async throws {
        guard let key = getKey(provider: provider), !key.isEmpty else {
            throw NSError(domain: "LettersAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "No API key configured for \(provider.rawValue)."])
        }

        switch provider {
        case .anthropic:
            try await streamAnthropic(key: key, prompt: prompt, context: contextText, system: systemPrompt, onToken: onToken)
        case .openAI:
            try await streamOpenAI(key: key, prompt: prompt, context: contextText, system: systemPrompt, onToken: onToken)
        case .google:
            try await streamGemini(key: key, prompt: prompt, context: contextText, system: systemPrompt, onToken: onToken)
        }
    }

    private func streamAnthropic(
        key: String,
        prompt: String,
        context: String?,
        system: String,
        onToken: @Sendable (String) -> Void
    ) async throws {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let fullUserMsg = context != nil ? "Document Context:\n\(context!)\n\nUser Question:\n\(prompt)" : prompt
        let body: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 2048,
            "system": system,
            "stream": true,
            "messages": [
                ["role": "user", "content": fullUserMsg]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "AnthropicAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Anthropic API error"])
        }

        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let json = line.dropFirst(6)
                if let data = json.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let delta = obj["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    onToken(text)
                }
            }
        }
    }

    private func streamOpenAI(
        key: String,
        prompt: String,
        context: String?,
        system: String,
        onToken: @Sendable (String) -> Void
    ) async throws {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let fullUserMsg = context != nil ? "Document Context:\n\(context!)\n\nUser Question:\n\(prompt)" : prompt
        let body: [String: Any] = [
            "model": "gpt-4o",
            "stream": true,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": fullUserMsg]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "OpenAIAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "OpenAI API error"])
        }

        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let payload = line.dropFirst(6)
                if payload == "[DONE]" { break }
                if let data = payload.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = obj["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let delta = first["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    onToken(content)
                }
            }
        }
    }

    private func streamGemini(
        key: String,
        prompt: String,
        context: String?,
        system: String,
        onToken: @Sendable (String) -> Void
    ) async throws {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent?key=\(key)&alt=sse"
        guard let url = URL(string: endpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let fullUserMsg = context != nil ? "\(system)\n\nDocument Context:\n\(context!)\n\nUser Question:\n\(prompt)" : "\(system)\n\n\(prompt)"
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": fullUserMsg]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GeminiAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Gemini API error"])
        }

        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let payload = line.dropFirst(6)
                if let data = payload.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = obj["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    onToken(text)
                }
            }
        }
    }
}
