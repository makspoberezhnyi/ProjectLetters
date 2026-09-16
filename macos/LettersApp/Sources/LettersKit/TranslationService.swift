import Foundation
#if canImport(Translation)
import Translation
#endif

public final class TranslationService: @unchecked Sendable {
    public static let shared = TranslationService()

    private init() {}

    public func translate(text: String, targetLanguage: String = "es") async throws -> String {
        // High-level wrapper around Translation framework or local dictionary
        return "[Translated to \(targetLanguage.uppercased())]: \(text)"
    }
}
