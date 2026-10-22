import Foundation
#if canImport(LettersCoreC)
import LettersCoreC
#endif

public final class CoreBridge: @unchecked Sendable {
    public static let shared = CoreBridge()

    private typealias FreeStringFn = @convention(c) (UnsafeMutablePointer<CChar>?) -> Void
    private typealias FreeBytesFn = @convention(c) (UnsafeMutablePointer<UInt8>?, Int) -> Void
    private typealias LintTextFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?
    private typealias RenderCitationFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?
    private typealias ExportDocxFn = @convention(c) (UnsafePointer<CChar>?, UnsafeMutablePointer<Int>?) -> UnsafeMutablePointer<UInt8>?
    private typealias ExportDocxFromMdFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafeMutablePointer<Int>?) -> UnsafeMutablePointer<UInt8>?
    private typealias ImportDocxFn = @convention(c) (UnsafePointer<UInt8>?, Int) -> UnsafeMutablePointer<CChar>?

    private var dylibHandle: UnsafeMutableRawPointer?
    private var freeString: FreeStringFn?
    private var freeBytes: FreeBytesFn?
    private var lintTextFn: LintTextFn?
    private var renderCitationFn: RenderCitationFn?
    private var exportDocxFn: ExportDocxFn?
    private var exportDocxFromMdFn: ExportDocxFromMdFn?
    private var importDocxFn: ImportDocxFn?

    private init() {
        loadDynamicLibrary()
    }

    private func loadDynamicLibrary() {
        // Try common release / debug dylib paths
        let candidatePaths = [
            Bundle.main.resourcePath.map { "\($0)/libletters_core.dylib" },
            Bundle.main.bundlePath + "/Contents/Frameworks/libletters_core.dylib",
            FileManager.default.currentDirectoryPath + "/../../core/letters_core/target/release/libletters_core.dylib",
            FileManager.default.currentDirectoryPath + "/core/letters_core/target/release/libletters_core.dylib",
            "/Users/mpob/Developer/projectletters/core/letters_core/target/release/libletters_core.dylib"
        ].compactMap { $0 }

        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path) {
                if let handle = dlopen(path, RTLD_NOW) {
                    self.dylibHandle = handle
                    self.freeString = unsafeBitCast(dlsym(handle, "letters_free_string"), to: FreeStringFn?.self)
                    self.freeBytes = unsafeBitCast(dlsym(handle, "letters_free_bytes"), to: FreeBytesFn?.self)
                    self.lintTextFn = unsafeBitCast(dlsym(handle, "letters_lint_text"), to: LintTextFn?.self)
                    self.renderCitationFn = unsafeBitCast(dlsym(handle, "letters_render_citation"), to: RenderCitationFn?.self)
                    self.exportDocxFn = unsafeBitCast(dlsym(handle, "letters_export_docx_from_json"), to: ExportDocxFn?.self)
                    self.exportDocxFromMdFn = unsafeBitCast(dlsym(handle, "letters_export_docx_from_markdown"), to: ExportDocxFromMdFn?.self)
                    self.importDocxFn = unsafeBitCast(dlsym(handle, "letters_import_docx"), to: ImportDocxFn?.self)
                    break
                }
            }
        }
    }

    private struct NativeLintRule {
        let pattern: String
        let message: String
        let suggestion: String
        let ruleId: String
    }

    private static let academicRules: [NativeLintRule] = [
        // Clichés & Subjective Adverbs
        NativeLintRule(pattern: #"(?i)\bas we all know\b"#, message: "Avoid cliché: provide citation or evidence", suggestion: "evidence indicates", ruleId: "cliche_as_we_know"),
        NativeLintRule(pattern: #"(?i)\bit is obvious that\b"#, message: "Avoid unproven assertion", suggestion: "evidence demonstrates that", ruleId: "cliche_obvious"),
        NativeLintRule(pattern: #"(?i)\bclearly,\b"#, message: "Avoid subjective adverb in formal writing", suggestion: "Notably,", ruleId: "cliche_clearly"),
        NativeLintRule(pattern: #"(?i)\bobviously,\b"#, message: "Avoid subjective adverb in formal writing", suggestion: "Notably,", ruleId: "cliche_obviously"),
        NativeLintRule(pattern: #"(?i)\bneedless to say\b"#, message: "Avoid conversational filler", suggestion: "notably", ruleId: "cliche_needless_to_say"),
        NativeLintRule(pattern: #"(?i)\ba lot of\b"#, message: "Replace informal quantifier with precise academic terminology", suggestion: "many", ruleId: "cliche_a_lot_of"),
        NativeLintRule(pattern: #"(?i)\blots of\b"#, message: "Replace informal quantifier with precise academic terminology", suggestion: "numerous", ruleId: "cliche_lots_of"),
        NativeLintRule(pattern: #"(?i)\bvery unique\b"#, message: "'Unique' is absolute; avoid intensifying", suggestion: "unique", ruleId: "cliche_very_unique"),
        NativeLintRule(pattern: #"(?i)\breally unique\b"#, message: "'Unique' is absolute; avoid intensifying", suggestion: "unique", ruleId: "cliche_really_unique"),
        NativeLintRule(pattern: #"(?i)\bin a nutshell\b"#, message: "Replace colloquial idiom", suggestion: "in summary", ruleId: "cliche_in_a_nutshell"),
        NativeLintRule(pattern: #"(?i)\bat the end of the day\b"#, message: "Replace colloquial cliché", suggestion: "ultimately", ruleId: "cliche_end_of_day"),

        // Wordiness & Pompous Phrasing
        NativeLintRule(pattern: #"(?i)\bdue to the fact that\b"#, message: "Simplify wordy phrasing", suggestion: "because", ruleId: "wordy_due_to_fact"),
        NativeLintRule(pattern: #"(?i)\bin order to\b"#, message: "Simplify wordy infinitive", suggestion: "to", ruleId: "wordy_in_order_to"),
        NativeLintRule(pattern: #"(?i)\bat the present time\b"#, message: "Simplify wordy temporal phrase", suggestion: "currently", ruleId: "wordy_present_time"),
        NativeLintRule(pattern: #"(?i)\bat this point in time\b"#, message: "Simplify wordy temporal phrase", suggestion: "currently", ruleId: "wordy_point_in_time"),
        NativeLintRule(pattern: #"(?i)\buntil such time as\b"#, message: "Simplify wordy phrase", suggestion: "until", ruleId: "wordy_until_such_time"),
        NativeLintRule(pattern: #"(?i)\bfor the purpose of\b"#, message: "Simplify wordy prepositional phrase", suggestion: "to", ruleId: "wordy_purpose_of"),
        NativeLintRule(pattern: #"(?i)\bin the event that\b"#, message: "Simplify wordy conditional", suggestion: "if", ruleId: "wordy_in_the_event"),
        NativeLintRule(pattern: #"(?i)\bprior to\b"#, message: "Prefer direct preposition", suggestion: "before", ruleId: "wordy_prior_to"),
        NativeLintRule(pattern: #"(?i)\bsubsequent to\b"#, message: "Prefer direct preposition", suggestion: "after", ruleId: "wordy_subsequent_to"),
        NativeLintRule(pattern: #"(?i)\bhas the capability to\b"#, message: "Simplify verbose modal", suggestion: "can", ruleId: "wordy_capability"),
        NativeLintRule(pattern: #"(?i)\bis capable of\b"#, message: "Simplify verbose modal", suggestion: "can", ruleId: "wordy_capable_of"),
        NativeLintRule(pattern: #"(?i)\btake into consideration\b"#, message: "Replace nominalization with active verb", suggestion: "consider", ruleId: "wordy_consideration"),
        NativeLintRule(pattern: #"(?i)\bmake a decision\b"#, message: "Replace nominalization with active verb", suggestion: "decide", ruleId: "wordy_decision"),
        NativeLintRule(pattern: #"(?i)\bgive an indication of\b"#, message: "Replace nominalization with active verb", suggestion: "indicate", ruleId: "wordy_indication"),
        NativeLintRule(pattern: #"(?i)\bdraw attention to the fact that\b"#, message: "Simplify wordy phrase", suggestion: "note that", ruleId: "wordy_draw_attention"),
        NativeLintRule(pattern: #"(?i)\bwith reference to\b"#, message: "Simplify prepositional phrase", suggestion: "regarding", ruleId: "wordy_reference_to"),
        NativeLintRule(pattern: #"(?i)\bin close proximity\b"#, message: "Simplify wordy phrase", suggestion: "near", ruleId: "wordy_proximity"),
        NativeLintRule(pattern: #"(?i)\butilize\b"#, message: "Prefer plain verb 'use' over 'utilize'", suggestion: "use", ruleId: "wordy_utilize"),
        NativeLintRule(pattern: #"(?i)\butilized\b"#, message: "Prefer plain verb 'used' over 'utilized'", suggestion: "used", ruleId: "wordy_utilized"),
        NativeLintRule(pattern: #"(?i)\butilizing\b"#, message: "Prefer plain verb 'using' over 'utilizing'", suggestion: "using", ruleId: "wordy_utilizing"),
        NativeLintRule(pattern: #"(?i)\butilizes\b"#, message: "Prefer plain verb 'uses' over 'utilizes'", suggestion: "uses", ruleId: "wordy_utilizes"),

        // Redundancies
        NativeLintRule(pattern: #"(?i)\bcompletely eliminate\b"#, message: "Remove redundant modifier", suggestion: "eliminate", ruleId: "redundant_eliminate"),
        NativeLintRule(pattern: #"(?i)\bend result\b"#, message: "Remove redundant modifier", suggestion: "result", ruleId: "redundant_result"),
        NativeLintRule(pattern: #"(?i)\bfuture plans\b"#, message: "Remove redundant modifier", suggestion: "plans", ruleId: "redundant_plans"),
        NativeLintRule(pattern: #"(?i)\bpast history\b"#, message: "Remove redundant modifier", suggestion: "history", ruleId: "redundant_history"),
        NativeLintRule(pattern: #"(?i)\bbasic fundamentals\b"#, message: "Remove redundant modifier", suggestion: "fundamentals", ruleId: "redundant_fundamentals"),
        NativeLintRule(pattern: #"(?i)\bconsensus of opinion\b"#, message: "Remove redundant phrase", suggestion: "consensus", ruleId: "redundant_consensus"),
        NativeLintRule(pattern: #"(?i)\bfirst and foremost\b"#, message: "Remove redundant doublet", suggestion: "first", ruleId: "redundant_foremost"),
        NativeLintRule(pattern: #"(?i)\btrue facts\b"#, message: "Remove redundant modifier", suggestion: "facts", ruleId: "redundant_true_facts"),
        NativeLintRule(pattern: #"(?i)\btrue fact\b"#, message: "Remove redundant modifier", suggestion: "fact", ruleId: "redundant_true_fact"),
        NativeLintRule(pattern: #"(?i)\bunexpected surprise\b"#, message: "Remove redundant modifier", suggestion: "surprise", ruleId: "redundant_surprise"),

        // Academic Contractions
        NativeLintRule(pattern: #"(?i)\bdon't\b"#, message: "Expand informal contraction in formal prose", suggestion: "do not", ruleId: "informal_dont"),
        NativeLintRule(pattern: #"(?i)\bcan't\b"#, message: "Expand informal contraction in formal prose", suggestion: "cannot", ruleId: "informal_cant"),
        NativeLintRule(pattern: #"(?i)\bwon't\b"#, message: "Expand informal contraction in formal prose", suggestion: "will not", ruleId: "informal_wont"),
        NativeLintRule(pattern: #"(?i)\bdoesn't\b"#, message: "Expand informal contraction in formal prose", suggestion: "does not", ruleId: "informal_doesnt")
    ]

    public func lint(text: String, profile: String = "none") -> [StyleLintMatch] {
        guard profile != "none", !profile.isEmpty else { return [] }
        var results: [StyleLintMatch] = []

        // 1. Run dynamic library / C-FFI linter if available
        if let fn = lintTextFn, let free = freeString {
            let resPtr = profile.withCString { pProf in
                text.withCString { pText in
                    fn(pProf, pText)
                }
            }
            if let ptr = resPtr {
                let jsonString = String(cString: ptr)
                free(ptr)
                if let data = jsonString.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode([StyleLintMatch].self, from: data) {
                    results.append(contentsOf: decoded)
                }
            }
        } else if let res = letters_lint_text(profile, text) {
            let jsonString = String(cString: res)
            letters_free_string(res)
            if let data = jsonString.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([StyleLintMatch].self, from: data) {
                results.append(contentsOf: decoded)
            }
        }

        // 2. Run high-performance Swift native academic style rule dictionary
        if profile.lowercased().contains("academic") || profile.isEmpty {
            let ns = text as NSString
            let fullRange = NSRange(location: 0, length: ns.length)

            for rule in Self.academicRules {
                guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: []) else { continue }
                let matches = regex.matches(in: text, options: [], range: fullRange)
                for match in matches {
                    let spanRange = match.range
                    let alreadyMatched = results.contains { r in
                        r.spanStart == spanRange.location && r.spanEnd == spanRange.location + spanRange.length
                    }
                    if !alreadyMatched {
                        results.append(
                            StyleLintMatch(
                                ruleId: rule.ruleId,
                                message: rule.message,
                                spanStart: spanRange.location,
                                spanEnd: spanRange.location + spanRange.length,
                                suggestion: rule.suggestion
                            )
                        )
                    }
                }
            }
        }

        return results.sorted(by: { $0.spanStart < $1.spanStart })
    }

    public func renderCitation(source: Source, reference: CitationReference, style: CitationStyle) -> String {
        guard let sourceData = try? JSONEncoder().encode(source),
              let refData = try? JSONEncoder().encode(reference),
              let sourceJson = String(data: sourceData, encoding: .utf8),
              let refJson = String(data: refData, encoding: .utf8) else {
            return "[Error encoding citation]"
        }

        if let fn = renderCitationFn, let free = freeString {
            let resPtr = sourceJson.withCString { pSrc in
                refJson.withCString { pRef in
                    style.rawValue.withCString { pStyle in
                        fn(pSrc, pRef, pStyle)
                    }
                }
            }
            guard let ptr = resPtr else { return "[Citation Error]" }
            defer { free(ptr) }
            return String(cString: ptr)
        }

        let res = letters_render_citation(sourceJson, refJson, style.rawValue)
        guard let res else { return "[Citation]" }
        defer { letters_free_string(res) }
        return String(cString: res)
    }

    public func exportDocx(title: String = "Untitled Document", text: String) -> Data? {
        if let fn = exportDocxFromMdFn, let free = freeBytes {
            var len: Int = 0
            let resPtr = title.withCString { pTitle in
                text.withCString { pText in
                    fn(pTitle, pText, &len)
                }
            }
            guard let ptr = resPtr, len > 0 else { return nil }
            defer { free(ptr, len) }
            return Data(bytes: ptr, count: len)
        }

        var len: Int = 0
        let res = letters_export_docx_from_markdown(title, text, &len)
        guard let res, len > 0 else { return nil }
        defer { letters_free_bytes(res, len) }
        return Data(bytes: res, count: len)
    }

    public func exportDocx(document: DocumentModel) -> Data? {
        guard let docData = try? JSONEncoder().encode(document),
              let docJson = String(data: docData, encoding: .utf8) else {
            return nil
        }

        if let fn = exportDocxFn, let free = freeBytes {
            var len: Int = 0
            let resPtr = docJson.withCString { pDoc in
                fn(pDoc, &len)
            }
            guard let ptr = resPtr, len > 0 else { return nil }
            defer { free(ptr, len) }
            return Data(bytes: ptr, count: len)
        }

        var len: Int = 0
        let res = letters_export_docx_from_json(docJson, &len)
        guard let res, len > 0 else { return nil }
        defer { letters_free_bytes(res, len) }
        return Data(bytes: res, count: len)
    }

    public func importDocx(data: Data) -> DocumentModel? {
        guard !data.isEmpty else { return nil }
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return nil }
            if let fn = importDocxFn, let free = freeString {
                guard let ptr = fn(baseAddress, data.count) else { return nil }
                defer { free(ptr) }
                let jsonString = String(cString: ptr)
                guard let jsonData = jsonString.data(using: .utf8) else { return nil }
                return try? JSONDecoder().decode(DocumentModel.self, from: jsonData)
            }
            guard let res = letters_import_docx(baseAddress, data.count) else { return nil }
            defer { letters_free_string(res) }
            let jsonString = String(cString: res)
            guard let jsonData = jsonString.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(DocumentModel.self, from: jsonData)
        }
    }
}
