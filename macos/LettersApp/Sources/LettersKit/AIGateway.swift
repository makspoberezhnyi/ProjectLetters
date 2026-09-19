import Foundation
import Security
import AppKit

public enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    case google = "Google Gemini (Free Tier)"
    case claudeCLI = "Claude Pro (Local CLI)"
    case ollama = "Local On-Device (Ollama / M-Series)"
    case anthropic = "Anthropic Claude (API Key)"
    case openAI = "OpenAI GPT-4o (API Key)"

    public var id: String { rawValue }

    public var defaultModel: String {
        switch self {
        case .google: return "gemini-1.5-flash"
        case .claudeCLI: return "claude-3-5-sonnet (CLI Session)"
        case .ollama: return "llama3.2 / deepseek-r1"
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .openAI: return "gpt-4o"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .claudeCLI, .ollama: return false
        default: return true
        }
    }

    public var badgeLabel: String {
        switch self {
        case .google: return "100% FREE"
        case .claudeCLI: return "PRO ACCOUNT"
        case .ollama: return "OFFLINE / LOCAL"
        case .anthropic, .openAI: return "BYOK API"
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

    public nonisolated func storeKey(provider: AIProvider, key: String) throws {
        let account = provider.rawValue
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(cleanKey.utf8)

        // Delete existing item if present
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        if !cleanKey.isEmpty {
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

    public nonisolated func getKey(provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    public static let defaultSystemPrompt = """
You are Letters Assistant, an expert document editor and intelligent copilot in Project Letters for macOS.
Provide direct, insightful, concise, and beautifully formatted writing assistance.

DOCUMENT CONTENT GUIDELINE:
When providing document drafts, summaries, rewritten paragraphs, or factual content requested by the user:
• Provide the actual document content directly without conversational preambles like "Here is your text:", "Here is the summary:", "Certainly!", or "Below is the updated section:".
• If you want to include brief commentary or context alongside document-ready text, place the ready-to-insert document text inside [CONTENT]...[/CONTENT] or use an action tag.

DOCUMENT ACTIONS:
When asked to create, modify, or insert elements into the document, use structured action tags:
• Smart Table: [ACTION:insert_table {"headers":["Col 1","Col 2"],"rows":[["A","B"],["C","D"]]}]
• Heading: [ACTION:insert_heading {"level": 1, "title": "Section Title"}]
• Citation: [ACTION:insert_citation {"author": "Author Name", "year": 2024, "title": "Article Title", "doi": "10.1000/xyz"}]
• Blockquote: [ACTION:insert_quote {"text": "Quote text"}]
• Page Margins: [ACTION:set_margins {"preset": "normal"}] (options: "normal", "narrow", "wide")
• Page Break: [ACTION:insert_page_break]
• Table of Contents: [ACTION:insert_toc]
• Bibliography: [ACTION:insert_bibliography]
• Replace Text: [ACTION:replace_selection {"text": "Replacement text"}]
• Append Section: [ACTION:append_document {"text": "Content to append"}]

Never output raw chain-of-thought or internal brainstorming notes.
"""

    // MARK: - Streaming Entrypoint
    public func streamCompletion(
        prompt: String,
        contextText: String?,
        provider: AIProvider = .claudeCLI,
        systemPrompt: String = AIGateway.defaultSystemPrompt,
        onToken: @Sendable (String) -> Void
    ) async throws {
        switch provider {
        case .google:
            guard let key = getKey(provider: provider), !key.isEmpty else {
                throw NSError(domain: "LettersAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Google Gemini API key found. Paste your key and click Save or Test."])
            }
            try await streamGemini(key: key, prompt: prompt, context: contextText, system: systemPrompt, onToken: onToken)

        case .claudeCLI:
            try await streamClaudeCLI(prompt: prompt, context: contextText, system: systemPrompt, onToken: onToken)

        case .ollama:
            try await streamOllama(prompt: prompt, context: contextText, system: systemPrompt, onToken: onToken)

        case .anthropic:
            guard let key = getKey(provider: provider), !key.isEmpty else {
                throw NSError(domain: "LettersAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Anthropic API key configured."])
            }
            try await streamAnthropic(key: key, prompt: prompt, context: contextText, system: systemPrompt, onToken: onToken)

        case .openAI:
            guard let key = getKey(provider: provider), !key.isEmpty else {
                throw NSError(domain: "LettersAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "No OpenAI API key configured."])
            }
            try await streamOpenAI(key: key, prompt: prompt, context: contextText, system: systemPrompt, onToken: onToken)
        }
    }

    // MARK: - 1. Claude CLI / Local Subscription Bridge
    public static func findClaudeExecutable() -> String? {
        // 1. Try login shell discovery
        let shellProcess = Process()
        shellProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shellProcess.arguments = ["-l", "-c", "which claude"]
        let shellPipe = Pipe()
        shellProcess.standardOutput = shellPipe
        shellProcess.standardError = Pipe()
        do {
            try shellProcess.run()
            shellProcess.waitUntilExit()
            if shellProcess.terminationStatus == 0 {
                let data = shellPipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !str.isEmpty,
                   FileManager.default.isExecutableFile(atPath: str) {
                    return str
                }
            }
        } catch {}

        let home = NSHomeDirectory()

        // 2. Scan NVM node versions dynamically
        let nvmNodeDir = "\(home)/.nvm/versions/node"
        if let nodeVersions = try? FileManager.default.contentsOfDirectory(atPath: nvmNodeDir) {
            for v in nodeVersions.sorted().reversed() {
                let candidate = "\(nvmNodeDir)/\(v)/bin/claude"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        // 3. Scan FNM versions dynamically
        let fnmNodeDir = "\(home)/.fnm/node-versions"
        if let fnmVersions = try? FileManager.default.contentsOfDirectory(atPath: fnmNodeDir) {
            for v in fnmVersions.sorted().reversed() {
                let candidate = "\(fnmNodeDir)/\(v)/installation/bin/claude"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        // 4. Standard global paths
        let standardPaths = [
            "\(home)/.fnm/current/bin/claude",
            "\(home)/.volta/bin/claude",
            "\(home)/.asdf/shims/claude",
            "\(home)/.bun/bin/claude",
            "\(home)/.pnpm-global/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude"
        ]

        for p in standardPaths {
            if FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }

        return nil
    }

    private func streamClaudeCLI(
        prompt: String,
        context: String?,
        system: String,
        onToken: @Sendable (String) -> Void
    ) async throws {
        guard let executable = Self.findClaudeExecutable() else {
            throw NSError(
                domain: "ClaudeCLI",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Claude CLI not found. Install it in Terminal with: 'npm install -g @anthropic-ai/claude-code' and run 'claude' to log in with your Claude Pro subscription."]
            )
        }

        let fullPrompt = context != nil ? "System Instructions: \(system)\n\nDocument Context:\n\(context!)\n\nUser Request:\n\(prompt)" : "\(system)\n\n\(prompt)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [
            "-p", fullPrompt,
            "--allowed-tools", "WebSearch,WebFetch",
            "--output-format", "text"
        ]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        var env = ProcessInfo.processInfo.environment
        let execDir = (executable as NSString).deletingLastPathComponent
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "\(execDir):/opt/homebrew/bin:/usr/local/bin:\(currentPath)"
        env["HOME"] = NSHomeDirectory()
        process.environment = env

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()

        let handle = pipe.fileHandleForReading
        for try await line in handle.bytes.lines {
            onToken(line + "\n")
        }
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let msg = errMsg, !msg.isEmpty {
                throw NSError(domain: "ClaudeCLI", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: msg])
            }
        }
    }

    // MARK: - 2. Local Ollama Models & Discovery
    public func fetchLocalOllamaModels() async -> [String] {
        guard let url = URL(string: "http://127.0.0.1:11434/api/tags") else { return [] }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return []
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                return models.compactMap { $0["name"] as? String }
            }
        } catch {
            return []
        }
        return []
    }

    private func streamOllama(
        prompt: String,
        context: String?,
        system: String,
        onToken: @Sendable (String) -> Void
    ) async throws {
        guard let url = URL(string: "http://127.0.0.1:11434/v1/chat/completions") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let fullUserMsg = context != nil ? "Document Context:\n\(context!)\n\nUser Request:\n\(prompt)" : prompt
        let body: [String: Any] = [
            "model": "llama3.2",
            "stream": true,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": fullUserMsg]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "OllamaAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Ollama not reachable at http://127.0.0.1:11434. Make sure Ollama is running locally on your Mac."])
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

    // MARK: - 3. Google Gemini (Free Tier)
    private func fetchAvailableGeminiModels(cleanKey: String) async -> [String] {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(cleanKey)") else {
            return []
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return []
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = obj["models"] as? [[String: Any]] {
                let validModels = models.compactMap { m -> String? in
                    guard let name = m["name"] as? String else { return nil }
                    if let methods = m["supportedGenerationMethods"] as? [String], !methods.contains("generateContent") {
                        return nil
                    }
                    return name
                }
                if !validModels.isEmpty {
                    return validModels.sorted { a, b in
                        let rankA = a.contains("2.0-flash") ? 0 : (a.contains("1.5-flash") ? 1 : (a.contains("pro") ? 2 : 3))
                        let rankB = b.contains("2.0-flash") ? 0 : (b.contains("1.5-flash") ? 1 : (b.contains("pro") ? 2 : 3))
                        return rankA < rankB
                    }
                }
            }
        } catch {
            return []
        }
        return []
    }

    private func streamGemini(
        key: String,
        prompt: String,
        context: String?,
        system: String,
        onToken: @Sendable (String) -> Void
    ) async throws {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "GeminiAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Google Gemini API key is missing. Enter your key in Settings."])
        }

        var promptText = prompt
        if let ctx = context?.trimmingCharacters(in: .whitespacesAndNewlines), !ctx.isEmpty, !ctx.contains("Word Count: 0 words") {
            promptText = "Document Context:\n\(ctx)\n\nUser Request: \(prompt)"
        }

        let effectiveSystem = system.isEmpty
            ? "You are Letters Assistant, an expert academic and professional document copilot. Provide direct, concise, insightful assistance without internal reasoning or meta-commentary."
            : "\(system)\n\nNever output internal thoughts, brainstorming notes, or option lists. Respond directly to the user."

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": effectiveSystem]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": promptText]
                    ]
                ]
            ]
        ]
        let httpBody = try JSONSerialization.data(withJSONObject: body)

        // Try dynamically discovered models first
        var candidateModels = await fetchAvailableGeminiModels(cleanKey: cleanKey)
        if candidateModels.isEmpty {
            candidateModels = [
                "models/gemini-2.0-flash",
                "models/gemini-1.5-flash",
                "models/gemini-1.5-pro",
                "models/gemini-2.0-flash-exp",
                "models/gemini-1.5-flash-8b"
            ]
        }

        var lastErrorMessage: String? = nil

        for model in candidateModels {
            let modelPath = model.starts(with: "models/") ? model : "models/\(model)"
            let endpoint = "https://generativelanguage.googleapis.com/v1beta/\(modelPath):generateContent?key=\(cleanKey)"
            guard let url = URL(string: endpoint) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody
            request.timeoutInterval = 25

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }

                if !(200...299).contains(httpResponse.statusCode) {
                    if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = obj["error"] as? [String: Any],
                       let msg = err["message"] as? String {
                        lastErrorMessage = msg
                    } else {
                        lastErrorMessage = "Google API returned HTTP \(httpResponse.statusCode)"
                    }
                    continue
                }

                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let candidates = obj["candidates"] as? [[String: Any]],
                       let first = candidates.first,
                       let content = first["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]] {
                        var fullText = ""
                        for part in parts {
                            if let text = part["text"] as? String {
                                fullText += text
                            }
                        }
                        if !fullText.isEmpty {
                            let words = fullText.split(separator: " ", omittingEmptySubsequences: false)
                            for (idx, word) in words.enumerated() {
                                let suffix = (idx == words.count - 1) ? "" : " "
                                onToken(String(word) + suffix)
                                try? await Task.sleep(nanoseconds: 12_000_000)
                            }
                            return
                        }
                    }
                    if let promptFeedback = obj["promptFeedback"] as? [String: Any],
                       let blockReason = promptFeedback["blockReason"] as? String {
                        lastErrorMessage = "Request was blocked by safety filter: \(blockReason)"
                    }
                }
            } catch {
                lastErrorMessage = error.localizedDescription
                continue
            }
        }

        if let msg = lastErrorMessage {
            throw NSError(domain: "GeminiAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: msg])
        } else {
            throw NSError(domain: "GeminiAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to generate response from Google Gemini. Please verify your connection."])
        }
    }

    // MARK: - 4. Anthropic & OpenAI BYOK
    private func streamAnthropic(
        key: String,
        prompt: String,
        context: String?,
        system: String,
        onToken: @Sendable (String) -> Void
    ) async throws {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(cleanKey, forHTTPHeaderField: "x-api-key")
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
            throw NSError(domain: "AnthropicAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Anthropic API key error. Check your key and credits on console.anthropic.com."])
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
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")

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
            throw NSError(domain: "OpenAIAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key error. Check your key on platform.openai.com."])
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

    // MARK: - 5. Claude Desktop MCP Config Exporter
    public nonisolated func exportClaudeDesktopMCPConfig() -> String {
        return """
        {
          "mcpServers": {
            "projectletters": {
              "command": "/Applications/Letters.app/Contents/MacOS/Letters",
              "args": ["--mcp-server"]
            }
          }
        }
        """
    }

    // MARK: - 6. Test Key Connection
    public func testConnection(provider: AIProvider) async -> (Bool, String) {
        if provider == .google {
            guard let key = getKey(provider: .google), !key.isEmpty else {
                return (false, "⚠️ No Google Gemini API key found. Paste your key and click Test.")
            }
            let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(cleanKey)") else {
                return (false, "⚠️ Invalid URL for Gemini endpoint.")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        return (true, "✓ Connected successfully to Google Gemini Free Tier")
                    } else {
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let err = json["error"] as? [String: Any],
                           let msg = err["message"] as? String {
                            return (false, "⚠️ Google Error: \(msg)")
                        }
                        return (false, "⚠️ Google HTTP Error \(httpResponse.statusCode)")
                    }
                }
            } catch {
                return (false, "⚠️ Connection error: \(error.localizedDescription)")
            }
        }

        if provider == .claudeCLI {
            guard let exec = Self.findClaudeExecutable() else {
                return (false, "⚠️ Claude CLI not found. Install in Terminal: npm install -g @anthropic-ai/claude-code")
            }
            return (true, "✓ Connected to Claude CLI (\(exec))")
        }

        do {
            try await streamCompletion(
                prompt: "Reply with the single word 'OK'",
                contextText: nil,
                provider: provider,
                onToken: { _ in }
            )
            return (true, "✓ Connected successfully to \(provider.rawValue)")
        } catch {
            return (false, "⚠️ Connection failed: \(error.localizedDescription)")
        }
    }
}
