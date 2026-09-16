import Foundation

public enum SourceType: String, Codable, CaseIterable, Sendable {
    case journalArticle = "journalarticle"
    case book = "book"
    case bookChapter = "bookchapter"
    case legalCase = "legalcase"
    case statute = "statute"
    case newsArticle = "newsarticle"
    case website = "website"
    case interview = "interview"
    case report = "report"
}

public struct Source: Codable, Identifiable, Sendable, Hashable {
    public var id: String
    public var sourceType: SourceType
    public var authors: [String]
    public var year: Int?
    public var title: String
    public var publication: String?
    public var volume: String?
    public var issue: String?
    public var pages: String?
    public var doi: String?
    public var url: String?
    public var publisher: String?
    public var court: String?
    public var reporter: String?
    public var accessDate: String?
    public var interviewDate: String?
    public var notes: String?

    public init(
        id: String,
        sourceType: SourceType = .journalArticle,
        authors: [String] = [],
        year: Int? = nil,
        title: String = "",
        publication: String? = nil,
        volume: String? = nil,
        issue: String? = nil,
        pages: String? = nil,
        doi: String? = nil,
        url: String? = nil,
        publisher: String? = nil,
        court: String? = nil,
        reporter: String? = nil,
        accessDate: String? = nil,
        interviewDate: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.authors = authors
        self.year = year
        self.title = title
        self.publication = publication
        self.volume = volume
        self.issue = issue
        self.pages = pages
        self.doi = doi
        self.url = url
        self.publisher = publisher
        self.court = court
        self.reporter = reporter
        self.accessDate = accessDate
        self.interviewDate = interviewDate
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sourceType = "source_type"
        case authors, year, title, publication, volume, issue, pages, doi, url, publisher, court, reporter
        case accessDate = "access_date"
        case interviewDate = "interview_date"
        case notes
    }
}

public struct CitationReference: Codable, Sendable, Hashable {
    public var sourceId: String
    public var pinPoint: String?
    public var prefix: String?
    public var suffix: String?

    public init(sourceId: String, pinPoint: String? = nil, prefix: String? = nil, suffix: String? = nil) {
        self.sourceId = sourceId
        self.pinPoint = pinPoint
        self.prefix = prefix
        self.suffix = suffix
    }

    enum CodingKeys: String, CodingKey {
        case sourceId = "source_id"
        case pinPoint = "pin_point"
        case prefix, suffix
    }
}

public enum CitationStyle: String, Codable, CaseIterable, Sendable {
    case apa7 = "apa"
    case mla9 = "mla"
    case chicagoDate = "chicago_date"
    case chicagoNotes = "chicago_notes"
    case bluebook = "bluebook"
    case plain = "plain"

    public var displayName: String {
        switch self {
        case .apa7: return "APA 7th Edition"
        case .mla9: return "MLA 9th Edition"
        case .chicagoDate: return "Chicago (Author-Date)"
        case .chicagoNotes: return "Chicago (Notes & Bib)"
        case .bluebook: return "Bluebook (Legal)"
        case .plain: return "Plain Attribution"
        }
    }
}

public struct StyleLintMatch: Codable, Identifiable, Sendable {
    public var id: String { "\(ruleId)_\(spanStart)_\(spanEnd)" }
    public var ruleId: String
    public var message: String
    public var spanStart: Int
    public var spanEnd: Int
    public var suggestion: String?

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case message
        case spanStart = "span_start"
        case spanEnd = "span_end"
        case suggestion
    }
}

public struct TextRun: Codable, Sendable, Hashable {
    public var text: String
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var strike: Bool
    public var citation: CitationReference?
    public var variableRef: String?

    public init(
        text: String,
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        strike: Bool = false,
        citation: CitationReference? = nil,
        variableRef: String? = nil
    ) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strike = strike
        self.citation = citation
        self.variableRef = variableRef
    }

    enum CodingKeys: String, CodingKey {
        case text, bold, italic, underline, strike, citation
        case variableRef = "variable_ref"
    }
}

public enum HeadingLevel: String, Codable, Sendable {
    case title = "Title"
    case subtitle = "Subtitle"
    case heading1 = "Heading1"
    case heading2 = "Heading2"
    case heading3 = "Heading3"
    case heading4 = "Heading4"
}

public enum BlockElement: Codable, Sendable {
    case paragraph(runs: [TextRun], alignment: String?)
    case heading(level: HeadingLevel, runs: [TextRun])
    case bulletItem(runs: [TextRun], indentLevel: Int)
    case numberedItem(runs: [TextRun], number: Int)
    case blockquote(runs: [TextRun])
    case pageBreak

    enum CodingKeys: String, CodingKey {
        case type, runs, alignment, level, indentLevel = "indent_level", number
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let runs, let alignment):
            try container.encode("Paragraph", forKey: .type)
            try container.encode(runs, forKey: .runs)
            try container.encodeIfPresent(alignment, forKey: .alignment)
        case .heading(let level, let runs):
            try container.encode("Heading", forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(runs, forKey: .runs)
        case .bulletItem(let runs, let indentLevel):
            try container.encode("BulletItem", forKey: .type)
            try container.encode(runs, forKey: .runs)
            try container.encode(indentLevel, forKey: .indentLevel)
        case .numberedItem(let runs, let number):
            try container.encode("NumberedItem", forKey: .type)
            try container.encode(runs, forKey: .runs)
            try container.encode(number, forKey: .number)
        case .blockquote(let runs):
            try container.encode("Blockquote", forKey: .type)
            try container.encode(runs, forKey: .runs)
        case .pageBreak:
            try container.encode("PageBreak", forKey: .type)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "Paragraph":
            let runs = try container.decode([TextRun].self, forKey: .runs)
            let alignment = try container.decodeIfPresent(String.self, forKey: .alignment)
            self = .paragraph(runs: runs, alignment: alignment)
        case "Heading":
            let level = try container.decode(HeadingLevel.self, forKey: .level)
            let runs = try container.decode([TextRun].self, forKey: .runs)
            self = .heading(level: level, runs: runs)
        case "BulletItem":
            let runs = try container.decode([TextRun].self, forKey: .runs)
            let indent = try container.decode(Int.self, forKey: .indentLevel)
            self = .bulletItem(runs: runs, indentLevel: indent)
        case "NumberedItem":
            let runs = try container.decode([TextRun].self, forKey: .runs)
            let num = try container.decode(Int.self, forKey: .number)
            self = .numberedItem(runs: runs, number: num)
        case "Blockquote":
            let runs = try container.decode([TextRun].self, forKey: .runs)
            self = .blockquote(runs: runs)
        case "PageBreak":
            self = .pageBreak
        default:
            self = .paragraph(runs: [], alignment: nil)
        }
    }
}

public struct DocumentModel: Codable, Sendable {
    public var title: String
    public var blocks: [BlockElement]
    public var sources: [String: Source]

    public init(title: String = "Untitled Document", blocks: [BlockElement] = [], sources: [String: Source] = [:]) {
        self.title = title
        self.blocks = blocks
        self.sources = sources
    }
}
