import Foundation

/// Helpers for user-facing copy, so counts read correctly ("1 word", "2 words").
enum Copy {
    /// Formats a count with its noun, using the singular only for exactly one.
    /// Pass `plural` for irregular nouns (e.g. "child" / "children").
    static func count(_ n: Int, _ singular: String, plural: String? = nil) -> String {
        let formatted = n.formatted(.number)
        return "\(formatted) " + (n == 1 ? singular : (plural ?? singular + "s"))
    }
}
