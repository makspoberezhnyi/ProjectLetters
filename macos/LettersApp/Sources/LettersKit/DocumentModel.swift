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

public struct PageMargins: Codable, Sendable, Hashable {
    public var top: CGFloat
    public var bottom: CGFloat
    public var left: CGFloat
    public var right: CGFloat

    public init(top: CGFloat = 72, bottom: CGFloat = 72, left: CGFloat = 72, right: CGFloat = 72) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }
}

public enum PageSizePreset: String, Codable, CaseIterable, Sendable {
    case letter = "US Letter"
    case a4 = "A4"
    case executive = "Executive"
    case legal = "US Legal"

    public var dimensions: (width: CGFloat, height: CGFloat) {
        switch self {
        case .letter: return (816, 1056)
        case .a4: return (794, 1123)
        case .executive: return (522, 756)
        case .legal: return (816, 1344)
        }
    }

    public var subtitle: String {
        switch self {
        case .letter: return "8.5 × 11 in"
        case .a4: return "210 × 297 mm"
        case .executive: return "7.25 × 10.5 in"
        case .legal: return "8.5 × 14 in"
        }
    }
}

public enum MarginPreset: String, Codable, CaseIterable, Sendable {
    case normal = "Normal (1.0\")"
    case narrow = "Narrow (0.5\")"
    case moderate = "Moderate (0.75\")"
    case wide = "Wide (1.5\")"
    case custom = "Custom"

    public var margins: PageMargins {
        switch self {
        case .normal: return PageMargins(top: 72, bottom: 72, left: 72, right: 72)
        case .narrow: return PageMargins(top: 36, bottom: 36, left: 36, right: 36)
        case .moderate: return PageMargins(top: 72, bottom: 72, left: 54, right: 54)
        case .wide: return PageMargins(top: 108, bottom: 108, left: 108, right: 108)
        case .custom: return PageMargins(top: 72, bottom: 72, left: 72, right: 72)
        }
    }
}

public enum PageNumberPosition: String, Codable, CaseIterable, Sendable {
    case footerRight = "Footer Right"
    case footerCenter = "Footer Center"
    case footerLeft = "Footer Left"
    case headerRight = "Header Right"
    case headerCenter = "Header Center"
    case headerLeft = "Header Left"
    case none = "None (Hidden)"

    public var isHeader: Bool {
        self == .headerRight || self == .headerCenter || self == .headerLeft
    }

    public var isFooter: Bool {
        self == .footerRight || self == .footerCenter || self == .footerLeft
    }
}

public enum PageNumberFormat: String, Codable, CaseIterable, Sendable {
    case pageXofY = "Page X of Y"
    case xOfY = "X / Y"
    case pageX = "Page X"
    case plain = "X (Plain Number)"
    case dash = "— X — (Em-dash)"
    case romanLower = "i, ii, iii (Roman Lower)"
    case romanUpper = "I, II, III (Roman Upper)"

    public func format(page: Int, totalPages: Int) -> String {
        switch self {
        case .pageXofY:
            return "Page \(page) of \(max(1, totalPages))"
        case .xOfY:
            return "\(page) / \(max(1, totalPages))"
        case .pageX:
            return "Page \(page)"
        case .plain:
            return "\(page)"
        case .dash:
            return "— \(page) —"
        case .romanLower:
            return Self.toRoman(page).lowercased()
        case .romanUpper:
            return Self.toRoman(page)
        }
    }

    private static func toRoman(_ number: Int) -> String {
        guard number > 0 else { return "\(number)" }
        let decimals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        let numerals = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
        var result = ""
        var num = number
        for i in 0..<decimals.count {
            while num >= decimals[i] {
                result += numerals[i]
                num -= decimals[i]
            }
        }
        return result
    }
}

public struct HeaderFooterConfig: Codable, Sendable, Hashable {
    public var headerLeftText: String
    public var headerCenterText: String
    public var headerRightText: String

    public var footerLeftText: String
    public var footerCenterText: String
    public var footerRightText: String

    public var pageNumberPosition: PageNumberPosition
    public var pageNumberFormat: PageNumberFormat
    public var startingPageNumber: Int
    public var differentFirstPage: Bool
    public var isHeaderVisible: Bool
    public var isFooterVisible: Bool

    public init(
        headerLeftText: String = "",
        headerCenterText: String = "",
        headerRightText: String = "Project Letters Studio",
        footerLeftText: String = "Confidential • Project Letters",
        footerCenterText: String = "",
        footerRightText: String = "",
        pageNumberPosition: PageNumberPosition = .footerRight,
        pageNumberFormat: PageNumberFormat = .pageXofY,
        startingPageNumber: Int = 1,
        differentFirstPage: Bool = false,
        isHeaderVisible: Bool = true,
        isFooterVisible: Bool = true
    ) {
        self.headerLeftText = headerLeftText
        self.headerCenterText = headerCenterText
        self.headerRightText = headerRightText
        self.footerLeftText = footerLeftText
        self.footerCenterText = footerCenterText
        self.footerRightText = footerRightText
        self.pageNumberPosition = pageNumberPosition
        self.pageNumberFormat = pageNumberFormat
        self.startingPageNumber = startingPageNumber
        self.differentFirstPage = differentFirstPage
        self.isHeaderVisible = isHeaderVisible
        self.isFooterVisible = isFooterVisible
    }

    public func evaluateHeader(slot: Slot, pageIndex: Int, totalPages: Int, documentTitle: String) -> String {
        let pageNum = startingPageNumber + pageIndex
        let isFirstPage = (pageIndex == 0)
        if differentFirstPage && isFirstPage { return "" }
        if !isHeaderVisible { return "" }

        let customText: String
        switch slot {
        case .left: customText = headerLeftText.isEmpty ? documentTitle : headerLeftText
        case .center: customText = headerCenterText
        case .right: customText = headerRightText
        }

        let evaluated = replaceTokens(in: customText, page: pageNum, totalPages: totalPages, title: documentTitle)

        // Inject page number if configured in this slot
        if (slot == .left && pageNumberPosition == .headerLeft) ||
           (slot == .center && pageNumberPosition == .headerCenter) ||
           (slot == .right && pageNumberPosition == .headerRight) {
            let numStr = pageNumberFormat.format(page: pageNum, totalPages: totalPages)
            return evaluated.isEmpty ? numStr : "\(evaluated) • \(numStr)"
        }

        return evaluated
    }

    public func evaluateFooter(slot: Slot, pageIndex: Int, totalPages: Int, documentTitle: String) -> String {
        let pageNum = startingPageNumber + pageIndex
        let isFirstPage = (pageIndex == 0)
        if differentFirstPage && isFirstPage { return "" }
        if !isFooterVisible { return "" }

        let customText: String
        switch slot {
        case .left: customText = footerLeftText
        case .center: customText = footerCenterText
        case .right: customText = footerRightText
        }

        let evaluated = replaceTokens(in: customText, page: pageNum, totalPages: totalPages, title: documentTitle)

        // Inject page number if configured in this slot
        if (slot == .left && pageNumberPosition == .footerLeft) ||
           (slot == .center && pageNumberPosition == .footerCenter) ||
           (slot == .right && pageNumberPosition == .footerRight) {
            let numStr = pageNumberFormat.format(page: pageNum, totalPages: totalPages)
            return evaluated.isEmpty ? numStr : "\(evaluated) • \(numStr)"
        }

        return evaluated
    }

    private func replaceTokens(in text: String, page: Int, totalPages: Int, title: String) -> String {
        var str = text
        str = str.replacingOccurrences(of: "{page}", with: "\(page)")
        str = str.replacingOccurrences(of: "{pages}", with: "\(max(1, totalPages))")
        str = str.replacingOccurrences(of: "{total}", with: "\(max(1, totalPages))")
        str = str.replacingOccurrences(of: "{title}", with: title)
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
        str = str.replacingOccurrences(of: "{date}", with: dateStr)
        return str
    }

    public enum Slot {
        case left, center, right
    }
}

public struct DocumentModel: Codable, Sendable {
    public var title: String
    public var blocks: [BlockElement]
    public var sources: [String: Source]
    public var pageSize: PageSizePreset
    public var margins: PageMargins
    public var headerFooter: HeaderFooterConfig

    public init(
        title: String = "Untitled Document",
        blocks: [BlockElement] = [],
        sources: [String: Source] = [:],
        pageSize: PageSizePreset = .letter,
        margins: PageMargins = PageMargins(),
        headerFooter: HeaderFooterConfig = HeaderFooterConfig()
    ) {
        self.title = title
        self.blocks = blocks
        self.sources = sources
        self.pageSize = pageSize
        self.margins = margins
        self.headerFooter = headerFooter
    }

    enum CodingKeys: String, CodingKey {
        case title, blocks, sources, pageSize, margins, headerFooter
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Document"
        self.blocks = try container.decodeIfPresent([BlockElement].self, forKey: .blocks) ?? []
        self.sources = try container.decodeIfPresent([String: Source].self, forKey: .sources) ?? [:]
        self.pageSize = try container.decodeIfPresent(PageSizePreset.self, forKey: .pageSize) ?? .letter
        self.margins = try container.decodeIfPresent(PageMargins.self, forKey: .margins) ?? PageMargins()
        self.headerFooter = try container.decodeIfPresent(HeaderFooterConfig.self, forKey: .headerFooter) ?? HeaderFooterConfig()
    }
}

