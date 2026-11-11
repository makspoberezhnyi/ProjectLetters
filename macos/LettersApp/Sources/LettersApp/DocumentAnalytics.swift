import Foundation
#if canImport(LettersKit)
import LettersKit
#endif

/// Live reading and health numbers for the Document tab. Pure and `Sendable`, so it can be computed
/// off the main thread once typing pauses.
struct DocumentAnalytics: Equatable, Sendable {
    var words: Int = 0
    var characters: Int = 0
    var sentences: Int = 0
    /// Flesch–Kincaid US grade level; nil when there is too little prose to be meaningful.
    var gradeLevel: Double? = nil

    /// Average adult silent-reading speed.
    static let wordsPerMinute: Double = 230
    /// Below this many words a grade level is noise.
    static let minimumWordsForGrade = 25

    var readingMinutes: Double { Double(words) / Self.wordsPerMinute }

    /// "< 1 min", "4 min", "1 hr 12 min".
    var readingTimeLabel: String {
        guard words > 0 else { return "—" }
        let minutes = Int(readingMinutes.rounded())
        if minutes < 1 { return "< 1 min" }
        if minutes < 60 { return "\(minutes) min" }
        let rem = minutes % 60
        return rem == 0 ? "\(minutes / 60) hr" : "\(minutes / 60) hr \(rem) min"
    }

    /// "Grade 9", or an em dash when there is not enough text.
    var gradeLabel: String {
        guard let grade = gradeLevel else { return "—" }
        return "Grade \(Int(grade.rounded()))"
    }

    /// Plain-language band for the grade ("Easy", "Standard", "Advanced").
    var gradeDescription: String? {
        guard let grade = gradeLevel else { return nil }
        switch grade {
        case ..<7: return "Easy to read"
        case ..<11: return "Plain English"
        case ..<14: return "College level"
        default: return "Advanced"
        }
    }

    static func compute(_ rawText: String) -> DocumentAnalytics {
        let text = prose(from: rawText)
        let words = EditorPerformanceCache.countWords(in: text)
        guard words > 0 else { return DocumentAnalytics() }

        var sentences = 0
        var syllables = 0
        var currentWord = ""
        var inSentence = false

        func flushWord() {
            guard !currentWord.isEmpty else { return }
            syllables += syllableCount(of: currentWord)
            currentWord.removeAll(keepingCapacity: true)
        }

        for ch in text {
            if ch.isLetter || ch == "'" || ch == "’" {
                currentWord.append(ch)
                inSentence = true
            } else {
                flushWord()
                if ch == "." || ch == "!" || ch == "?" || ch == "…" {
                    if inSentence { sentences += 1; inSentence = false }
                } else if ch.isNumber {
                    inSentence = true
                }
            }
        }
        flushWord()
        if inSentence { sentences += 1 }
        sentences = max(1, sentences)

        var grade: Double? = nil
        if words >= minimumWordsForGrade {
            let w = Double(words)
            let value = 0.39 * (w / Double(sentences)) + 11.8 * (Double(syllables) / w) - 15.59
            grade = min(18, max(0, value))
        }

        return DocumentAnalytics(
            words: words,
            characters: text.count,
            sentences: sentences,
            gradeLevel: grade
        )
    }

    /// Drops layout markers (`[[table:…]]`, page breaks) that are not prose.
    static func prose(from rawText: String) -> String {
        var text = rawText
        if text.contains("[[") {
            text = text.replacingOccurrences(of: #"\[\[[^\]]*\]\]"#, with: " ", options: .regularExpression)
        }
        if text.contains("---pagebreak---") {
            text = text.replacingOccurrences(of: "---pagebreak---", with: " ")
        }
        return text
    }

    /// Vowel-group heuristic; good enough for a readability estimate.
    static func syllableCount(of word: String) -> Int {
        let lower = word.lowercased().filter { $0.isLetter }
        guard !lower.isEmpty else { return 0 }
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var previousWasVowel = false
        for ch in lower {
            let isVowel = vowels.contains(ch)
            if isVowel && !previousWasVowel { count += 1 }
            previousWasVowel = isVowel
        }
        if lower.hasSuffix("e") && !lower.hasSuffix("le") && count > 1 { count -= 1 }
        return max(1, count)
    }
}

/// In-text citation strings for the Citations tab.
enum InTextCitation {
    /// "Kuhn" from "Thomas Kuhn" or "Kuhn, Thomas".
    static func surname(of author: String) -> String {
        let trimmed = author.trimmingCharacters(in: .whitespaces)
        if let comma = trimmed.firstIndex(of: ",") {
            return String(trimmed[..<comma]).trimmingCharacters(in: .whitespaces)
        }
        return trimmed.split(separator: " ").last.map(String.init) ?? trimmed
    }

    /// `(Kuhn, 1962)` for most styles; `(Kuhn 1962)` for Chicago author–date; `(Kuhn)` for MLA.
    static func text(for source: Source, style: CitationStyle) -> String {
        let name = source.authors.first.map(surname(of:)) ?? "Author"
        let others = source.authors.count > 1 ? " et al." : ""
        let year = source.year.map(String.init) ?? "n.d."
        switch style {
        case .mla9: return "(\(name)\(others))"
        case .chicagoDate: return "(\(name)\(others) \(year))"
        default: return "(\(name)\(others), \(year))"
        }
    }
}
