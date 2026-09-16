import Foundation
import LettersCoreC

public final class CoreBridge: @unchecked Sendable {
    public static let shared = CoreBridge()

    private typealias FreeStringFn = @convention(c) (UnsafeMutablePointer<CChar>?) -> Void
    private typealias FreeBytesFn = @convention(c) (UnsafeMutablePointer<UInt8>?, Int) -> Void
    private typealias LintTextFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?
    private typealias RenderCitationFn = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?
    private typealias ExportDocxFn = @convention(c) (UnsafePointer<CChar>?, UnsafeMutablePointer<Int>?) -> UnsafeMutablePointer<UInt8>?

    private var dylibHandle: UnsafeMutableRawPointer?
    private var freeString: FreeStringFn?
    private var freeBytes: FreeBytesFn?
    private var lintTextFn: LintTextFn?
    private var renderCitationFn: RenderCitationFn?
    private var exportDocxFn: ExportDocxFn?

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
                    break
                }
            }
        }
    }

    public func lint(text: String, profile: String = "academic") -> [StyleLintMatch] {
        if let fn = lintTextFn, let free = freeString {
            let resPtr = profile.withCString { pProf in
                text.withCString { pText in
                    fn(pProf, pText)
                }
            }
            guard let ptr = resPtr else { return [] }
            defer { free(ptr) }
            let jsonString = String(cString: ptr)
            guard let data = jsonString.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([StyleLintMatch].self, from: data)) ?? []
        }

        // Fallback using direct C symbols
        let res = letters_lint_text(profile, text)
        guard let res else { return [] }
        defer { letters_free_string(res) }
        let jsonString = String(cString: res)
        guard let data = jsonString.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([StyleLintMatch].self, from: data)) ?? []
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
}
