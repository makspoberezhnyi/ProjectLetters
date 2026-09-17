import Foundation
import SwiftUI
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

    public init(
        id: UUID = UUID(),
        base64Data: String,
        originalByteSize: Int = 0,
        compressedByteSize: Int = 0,
        caption: String = "Figure 1: Illustration",
        scaleWidthPercent: Double = 100.0,
        aspectRatioPreset: ImageAspectRatio = .original,
        alignment: ImageAlignment = .center
    ) {
        self.id = id
        self.base64Data = base64Data
        self.originalByteSize = originalByteSize
        self.compressedByteSize = compressedByteSize == 0 ? originalByteSize : compressedByteSize
        self.caption = caption
        self.scaleWidthPercent = scaleWidthPercent
        self.aspectRatioPreset = aspectRatioPreset
        self.alignment = alignment
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

// MARK: - Native .letters / .ltt Document Bundle Package
public struct LettersDocumentBundle: Codable, Sendable {
    public static let currentVersion = "1.0.0"
    public static let fileExtensionLetters = "letters"
    public static let fileExtensionLtt = "ltt"

    public var version: String
    public var title: String
    public var rawText: String
    public var tables: [StudioTableData]
    public var images: [StudioImageBlock]
    public var videos: [StudioVideoBlock]
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
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        title: String,
        rawText: String,
        tables: [StudioTableData] = [],
        images: [StudioImageBlock] = [],
        videos: [StudioVideoBlock] = [],
        sources: [String: Source] = [:],
        citationStyle: CitationStyle = .apa7,
        pageSizePreset: PageSizePreset = .letter,
        marginPreset: MarginPreset = .normal,
        margins: PageMargins = PageMargins(),
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: Double = 15.0,
        lineSpacing: Double = 1.15,
        paragraphSpacing: Double = 12.0,
        textAlignmentString: String = "leading"
    ) {
        self.version = Self.currentVersion
        self.title = title
        self.rawText = rawText
        self.tables = tables
        self.images = images
        self.videos = videos
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
        self.createdAt = Date()
        self.modifiedAt = Date()
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
