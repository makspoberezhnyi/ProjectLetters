import Foundation
import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Image Block Model with Compression & Aspect Ratio
public struct StudioImageBlock: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var base64Data: String
    public var originalByteSize: Int
    public var compressedByteSize: Int
    public var caption: String
    public var scaleWidthPercent: Double // 25.0 to 100.0
    public var aspectRatioPreset: ImageAspectRatio
    public var alignment: ImageAlignment
    public var offsetX: CGFloat = 0.0
    public var offsetY: CGFloat = 0.0
    public var wrapMode: ImageWrapMode = .topAndBottom
    public var rotationAngle: Double = 0.0
    public var lockAspectRatio: Bool = true

    public enum ImageWrapMode: String, Codable, Sendable, CaseIterable {
        case inline = "In Line with Text"
        case topAndBottom = "Top and Bottom"
        case square = "Square (Wrap Text)"
        case behindText = "Behind Text"
        case inFrontOfText = "In Front of Text"

        public var systemImage: String {
            switch self {
            case .inline: return "text.alignleft"
            case .topAndBottom: return "distribute.vertical.top"
            case .square: return "character.textbox"
            case .behindText: return "square.2.layers.3d.bottom.filled"
            case .inFrontOfText: return "square.2.layers.3d.top.filled"
            }
        }
    }

    public enum ImageAlignment: String, Codable, Sendable, CaseIterable {
        case leading = "leading"
        case center = "center"
        case trailing = "trailing"
    }

    public enum ImageAspectRatio: String, CaseIterable, Codable, Sendable {
        case original = "Original"
        case wide16_9 = "16:9 Cinema"
        case standard4_3 = "4:3 Standard"
        case square1_1 = "1:1 Square"

        public var ratio: CGFloat? {
            switch self {
            case .original: return nil
            case .wide16_9: return 16.0 / 9.0
            case .standard4_3: return 4.0 / 3.0
            case .square1_1: return 1.0
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, base64Data, originalByteSize, compressedByteSize, caption, scaleWidthPercent, aspectRatioPreset, alignment, offsetX, offsetY, wrapMode, rotationAngle, lockAspectRatio
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.base64Data = try container.decode(String.self, forKey: .base64Data)
        self.originalByteSize = try container.decodeIfPresent(Int.self, forKey: .originalByteSize) ?? 0
        self.compressedByteSize = try container.decodeIfPresent(Int.self, forKey: .compressedByteSize) ?? 0
        self.caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        self.scaleWidthPercent = try container.decodeIfPresent(Double.self, forKey: .scaleWidthPercent) ?? 100.0
        self.aspectRatioPreset = try container.decodeIfPresent(ImageAspectRatio.self, forKey: .aspectRatioPreset) ?? .original
        self.alignment = try container.decodeIfPresent(ImageAlignment.self, forKey: .alignment) ?? .center
        self.offsetX = try container.decodeIfPresent(CGFloat.self, forKey: .offsetX) ?? 0.0
        self.offsetY = try container.decodeIfPresent(CGFloat.self, forKey: .offsetY) ?? 0.0
        self.wrapMode = try container.decodeIfPresent(ImageWrapMode.self, forKey: .wrapMode) ?? .topAndBottom
        self.rotationAngle = try container.decodeIfPresent(Double.self, forKey: .rotationAngle) ?? 0.0
        self.lockAspectRatio = try container.decodeIfPresent(Bool.self, forKey: .lockAspectRatio) ?? true
    }

    public init(
        id: UUID = UUID(),
        base64Data: String,
        originalByteSize: Int = 0,
        compressedByteSize: Int = 0,
        caption: String = "Figure 1: Illustration",
        scaleWidthPercent: Double = 100.0,
        aspectRatioPreset: ImageAspectRatio = .original,
        alignment: ImageAlignment = .center,
        offsetX: CGFloat = 0.0,
        offsetY: CGFloat = 0.0,
        wrapMode: ImageWrapMode = .topAndBottom,
        rotationAngle: Double = 0.0,
        lockAspectRatio: Bool = true
    ) {
        self.id = id
        self.base64Data = base64Data
        self.originalByteSize = originalByteSize
        self.compressedByteSize = compressedByteSize == 0 ? originalByteSize : compressedByteSize
        self.caption = caption
        self.scaleWidthPercent = scaleWidthPercent
        self.aspectRatioPreset = aspectRatioPreset
        self.alignment = alignment
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.wrapMode = wrapMode
        self.rotationAngle = rotationAngle
        self.lockAspectRatio = lockAspectRatio
    }

    public func toMarkdown() -> String {
        return "\n\n![\(caption)](embedded_image_\(id.uuidString.prefix(8)).png)\n*\(caption)*\n"
    }
}

// MARK: - Video Embed Block Model
public struct StudioVideoBlock: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var url: String
    public var title: String
    public var platform: VideoPlatform
    public var thumbnailURL: String?

    public enum VideoPlatform: String, CaseIterable, Codable, Sendable {
        case youtube = "YouTube"
        case vimeo = "Vimeo"
        case web = "Web Video"
    }

    public init(
        id: UUID = UUID(),
        url: String,
        title: String = "Embedded Video",
        platform: VideoPlatform = .youtube,
        thumbnailURL: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.platform = platform
        self.thumbnailURL = thumbnailURL
    }

    public static func parse(url: String) -> StudioVideoBlock {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("youtube.com") || trimmed.contains("youtu.be") {
            var videoId = ""
            if trimmed.contains("v=") {
                videoId = trimmed.components(separatedBy: "v=").last?.components(separatedBy: "&").first ?? ""
            } else if trimmed.contains("youtu.be/") {
                videoId = trimmed.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first ?? ""
            }
            let thumb = videoId.isEmpty ? nil : "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
            return StudioVideoBlock(url: trimmed, title: "YouTube Video (\(videoId.prefix(6)))", platform: .youtube, thumbnailURL: thumb)
        } else if trimmed.contains("vimeo.com") {
            return StudioVideoBlock(url: trimmed, title: "Vimeo Video", platform: .vimeo)
        } else {
            return StudioVideoBlock(url: trimmed, title: "Web Video", platform: .web)
        }
    }

    public func toMarkdown() -> String {
        return "\n\n[▶ Watch Video: \(title) (\(url))](\(url))\n"
    }
}

// MARK: - Footnote Model
public struct StudioFootnote: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var referenceMarker: String // e.g. "1", "2", "*", "†"
    public var text: String
    
    public init(id: UUID = UUID(), referenceMarker: String, text: String) {
        self.id = id
        self.referenceMarker = referenceMarker
        self.text = text
    }
}


// MARK: - Native .letters / .ltt Document Bundle Package
public struct LettersDocumentBundle: Codable, Sendable {
    public static let currentVersion = "1.0.0"
    public static let fileExtensionLetters = "letters"
    public static let fileExtensionLtt = "ltt"

    public var version: String
    public var title: String
    public var rawText: String
    public var richTextData: Data?
    public var tables: [StudioTableData]
    public var images: [StudioImageBlock]
    public var videos: [StudioVideoBlock]
    public var floatingElements: [StudioFloatingElement]
    public var footnotes: [StudioFootnote]
    public var sideNotes: [StudioSideNote]
    public var sources: [String: Source]
    public var citationStyle: CitationStyle
    public var pageSizePreset: PageSizePreset
    public var marginPreset: MarginPreset
    public var margins: PageMargins
    public var fontFamily: String
    public var fontSize: Double
    public var lineSpacing: Double
    public var paragraphSpacing: Double
    public var textAlignmentString: String
    public var columnCount: Int
    public var showLineNumbers: Bool
    public var watermarkText: String
    public var kern: Double         // character tracking (pts)
    public var hangingIndent: Double // hanging indent (pts)
    public var headerFooter: HeaderFooterConfig
    public var coverBanner: CoverBannerConfig
    public var isTrackChangesEnabled: Bool
    public var revisions: [StudioTrackedRevision]
    public var styleProfile: String
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        title: String,
        rawText: String,
        richTextData: Data? = nil,
        tables: [StudioTableData] = [],
        images: [StudioImageBlock] = [],
        videos: [StudioVideoBlock] = [],
        floatingElements: [StudioFloatingElement] = [],
        footnotes: [StudioFootnote] = [],
        sideNotes: [StudioSideNote] = [],
        sources: [String: Source] = [:],
        citationStyle: CitationStyle = .apa7,
        pageSizePreset: PageSizePreset = .letter,
        marginPreset: MarginPreset = .normal,
        margins: PageMargins = PageMargins(),
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: Double = 15.0,
        lineSpacing: Double = 1.15,
        paragraphSpacing: Double = 12.0,
        textAlignmentString: String = "leading",
        columnCount: Int = 1,
        showLineNumbers: Bool = false,
        watermarkText: String = "",
        kern: Double = 0.0,
        hangingIndent: Double = 0.0,
        headerFooter: HeaderFooterConfig = HeaderFooterConfig(),
        coverBanner: CoverBannerConfig = CoverBannerConfig(),
        isTrackChangesEnabled: Bool = false,
        revisions: [StudioTrackedRevision] = [],
        styleProfile: String = "none"
    ) {
        self.version = Self.currentVersion
        self.title = title
        self.rawText = rawText
        self.richTextData = richTextData
        self.tables = tables
        self.images = images
        self.videos = videos
        self.floatingElements = floatingElements
        self.footnotes = footnotes
        self.sideNotes = sideNotes
        self.sources = sources
        self.citationStyle = citationStyle
        self.pageSizePreset = pageSizePreset
        self.marginPreset = marginPreset
        self.margins = margins
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.textAlignmentString = textAlignmentString
        self.columnCount = columnCount
        self.showLineNumbers = showLineNumbers
        self.watermarkText = watermarkText
        self.kern = kern
        self.hangingIndent = hangingIndent
        self.headerFooter = headerFooter
        self.coverBanner = coverBanner
        self.isTrackChangesEnabled = isTrackChangesEnabled
        self.revisions = revisions
        self.styleProfile = styleProfile
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case version, title, rawText, richTextData, tables, images, videos, floatingElements, footnotes, sideNotes, sources, citationStyle, pageSizePreset, marginPreset, margins, fontFamily, fontSize, lineSpacing, paragraphSpacing, textAlignmentString, columnCount, showLineNumbers, watermarkText, kern, hangingIndent, headerFooter, coverBanner, isTrackChangesEnabled, revisions, styleProfile, createdAt, modifiedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? Self.currentVersion
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Document"
        self.rawText = try container.decodeIfPresent(String.self, forKey: .rawText) ?? ""
        self.richTextData = try container.decodeIfPresent(Data.self, forKey: .richTextData)
        self.tables = try container.decodeIfPresent([StudioTableData].self, forKey: .tables) ?? []
        self.images = try container.decodeIfPresent([StudioImageBlock].self, forKey: .images) ?? []
        self.videos = try container.decodeIfPresent([StudioVideoBlock].self, forKey: .videos) ?? []
        self.floatingElements = try container.decodeIfPresent([StudioFloatingElement].self, forKey: .floatingElements) ?? []
        self.footnotes = try container.decodeIfPresent([StudioFootnote].self, forKey: .footnotes) ?? []
        self.sideNotes = try container.decodeIfPresent([StudioSideNote].self, forKey: .sideNotes) ?? []
        self.sources = try container.decodeIfPresent([String: Source].self, forKey: .sources) ?? [:]
        self.citationStyle = try container.decodeIfPresent(CitationStyle.self, forKey: .citationStyle) ?? .apa7
        self.pageSizePreset = try container.decodeIfPresent(PageSizePreset.self, forKey: .pageSizePreset) ?? .letter
        self.marginPreset = try container.decodeIfPresent(MarginPreset.self, forKey: .marginPreset) ?? .normal
        self.margins = try container.decodeIfPresent(PageMargins.self, forKey: .margins) ?? PageMargins()
        self.fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily) ?? "Default Serif (Georgia)"
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 15.0
        self.lineSpacing = try container.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? 1.15
        self.paragraphSpacing = try container.decodeIfPresent(Double.self, forKey: .paragraphSpacing) ?? 12.0
        self.textAlignmentString = try container.decodeIfPresent(String.self, forKey: .textAlignmentString) ?? "leading"
        self.columnCount = try container.decodeIfPresent(Int.self, forKey: .columnCount) ?? 1
        self.showLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? false
        self.watermarkText = try container.decodeIfPresent(String.self, forKey: .watermarkText) ?? ""
        self.kern = try container.decodeIfPresent(Double.self, forKey: .kern) ?? 0.0
        self.hangingIndent = try container.decodeIfPresent(Double.self, forKey: .hangingIndent) ?? 0.0
        self.headerFooter = try container.decodeIfPresent(HeaderFooterConfig.self, forKey: .headerFooter) ?? HeaderFooterConfig()
        self.coverBanner = try container.decodeIfPresent(CoverBannerConfig.self, forKey: .coverBanner) ?? CoverBannerConfig()
        self.isTrackChangesEnabled = try container.decodeIfPresent(Bool.self, forKey: .isTrackChangesEnabled) ?? false
        self.revisions = try container.decodeIfPresent([StudioTrackedRevision].self, forKey: .revisions) ?? []
        self.styleProfile = try container.decodeIfPresent(String.self, forKey: .styleProfile) ?? "none"
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
    }

    public func encodeToData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> LettersDocumentBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LettersDocumentBundle.self, from: data)
    }
}

public struct StudioFloatingElement: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var text: String
    public var position: CGPoint
    public var size: CGSize
    public var pageIndex: Int
    
    public init(id: UUID = UUID(), text: String, position: CGPoint, size: CGSize, pageIndex: Int = 0) {
        self.id = id
        self.text = text
        self.position = position
        self.size = size
        self.pageIndex = pageIndex
    }
}
public extension NSAttributedString.Key {
    static let keepLinesTogether = NSAttributedString.Key("LettersKeepLinesTogether")
    static let keepWithNext = NSAttributedString.Key("LettersKeepWithNext")
}

public struct StudioSideNote: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var referenceMarker: String
    public var text: String
    public var anchorText: String?
    public var rangeLocation: Int?
    public var rangeLength: Int?
    public var author: String
    public var createdAt: Date
    public var isResolved: Bool

    public init(
        id: UUID = UUID(),
        referenceMarker: String = "",
        text: String,
        anchorText: String? = nil,
        rangeLocation: Int? = nil,
        rangeLength: Int? = nil,
        author: String = "Reviewer",
        createdAt: Date = Date(),
        isResolved: Bool = false
    ) {
        self.id = id
        self.referenceMarker = referenceMarker
        self.text = text
        self.anchorText = anchorText
        self.rangeLocation = rangeLocation
        self.rangeLength = rangeLength
        self.author = author
        self.createdAt = createdAt
        self.isResolved = isResolved
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.referenceMarker = try container.decodeIfPresent(String.self, forKey: .referenceMarker) ?? ""
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.anchorText = try container.decodeIfPresent(String.self, forKey: .anchorText)
        self.rangeLocation = try container.decodeIfPresent(Int.self, forKey: .rangeLocation)
        self.rangeLength = try container.decodeIfPresent(Int.self, forKey: .rangeLength)
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? "Reviewer"
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.isResolved = try container.decodeIfPresent(Bool.self, forKey: .isResolved) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, referenceMarker, text, anchorText, rangeLocation, rangeLength, author, createdAt, isResolved
    }
}

public struct StudioTrackedRevision: Identifiable, Codable, Sendable, Hashable {
    public enum RevisionKind: String, Codable, Sendable {
        case insertion
        case deletion
    }

    public var id: UUID
    public var kind: RevisionKind
    public var text: String
    public var originalText: String?
    public var author: String
    public var createdAt: Date
    public var rangeLocation: Int?
    public var pageIndex: Int?

    public init(
        id: UUID = UUID(),
        kind: RevisionKind,
        text: String,
        originalText: String? = nil,
        author: String = "Author",
        createdAt: Date = Date(),
        rangeLocation: Int? = nil,
        pageIndex: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.originalText = originalText
        self.author = author
        self.createdAt = createdAt
        self.rangeLocation = rangeLocation
        self.pageIndex = pageIndex
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, text, originalText, author, createdAt, rangeLocation, pageIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.kind = try container.decodeIfPresent(RevisionKind.self, forKey: .kind) ?? .insertion
        self.text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.originalText = try container.decodeIfPresent(String.self, forKey: .originalText)
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? "Author"
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.rangeLocation = try container.decodeIfPresent(Int.self, forKey: .rangeLocation)
        self.pageIndex = try container.decodeIfPresent(Int.self, forKey: .pageIndex)
    }
}

@objc(CrossReferenceAttachment)
public class CrossReferenceAttachment: NSTextAttachment {
    public var targetId: String
    public var targetType: String
    
    public init(targetId: String, targetType: String) {
        self.targetId = targetId
        self.targetType = targetType
        super.init(data: nil, ofType: nil)
    }
    
    required init?(coder: NSCoder) {
        self.targetId = coder.decodeObject(forKey: "targetId") as? String ?? ""
        self.targetType = coder.decodeObject(forKey: "targetType") as? String ?? ""
        super.init(coder: coder)
    }
    
    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(targetId, forKey: "targetId")
        coder.encode(targetType, forKey: "targetType")
    }
    
    public override func viewProvider(for parentView: NSView?, location: NSTextLocation, textContainer: NSTextContainer?) -> NSTextAttachmentViewProvider? {
        return CrossReferenceViewProvider(textAttachment: self, parentView: parentView, textLayoutManager: textContainer?.textLayoutManager, location: location)
    }
}

public class CrossReferenceViewProvider: NSTextAttachmentViewProvider {
    public override func loadView() {
        let attachment = self.textAttachment as? CrossReferenceAttachment
        let targetId = attachment?.targetId ?? ""
        let targetType = attachment?.targetType ?? ""

        let label = MainActor.assumeIsolated { () -> NSTextField in
            var initialTitle = "Figure..."
            if targetType == "Figure", let active = LettersDocumentController.active {
                if let idx = active.images.firstIndex(where: { $0.id.uuidString == targetId }) {
                    initialTitle = "Figure \(idx + 1)"
                } else {
                    initialTitle = "Figure ?"
                }
            }
            let tf = NSTextField(labelWithString: initialTitle)
            tf.textColor = .systemBlue
            tf.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            tf.drawsBackground = true
            tf.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1)
            tf.isBordered = false
            tf.isEditable = false
            tf.isSelectable = false
            tf.wantsLayer = true
            tf.layer?.cornerRadius = 3
            return tf
        }
        self.view = label
    }
}
