import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

@MainActor
enum SnapshotActor: String, Codable, Equatable, Sendable {
    case user
    case ai
}

public struct HistoryNode: Identifiable, Equatable {
    public let id: UUID
    public let parentId: UUID?
    let timestamp: Date
    var actionName: String
    var diffSummary: String?
    let actor: SnapshotActor
    var isMilestone: Bool
    var isPinned: Bool
    var customName: String?
    let bundle: LettersDocumentBundle

    nonisolated public static func == (lhs: HistoryNode, rhs: HistoryNode) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
public class LettersDocumentController: ObservableObject {
    public static weak var active: LettersDocumentController?
    @Published public var title: String
    @Published public var rawText: String
    @Published public var richTextData: Data?
    
    @Published public var document: DocumentModel
    @Published public var tables: [StudioTableData]
    @Published public var images: [StudioImageBlock]
    @Published public var videos: [StudioVideoBlock]
    @Published public var floatingElements: [StudioFloatingElement]
    @Published public var footnotes: [StudioFootnote]
    @Published public var sideNotes: [StudioSideNote]
    @Published public var citationStyle: CitationStyle
    
    @Published public var pageSize: PageSizePreset
    @Published public var marginPreset: MarginPreset
    @Published public var margins: PageMargins
    @Published public var coverBanner: CoverBannerConfig
    @Published public var headerFooter: HeaderFooterConfig
    @Published public var isTrackChangesEnabled: Bool
    @Published public var revisions: [StudioTrackedRevision]
    @Published public var styleProfile: String = "none"
    
    @Published public var fontFamily: String
    @Published public var fontSize: CGFloat
    @Published public var lineSpacing: CGFloat
    @Published public var paragraphSpacing: CGFloat
    @Published public var textAlignment: TextAlignment
    @Published public var columnCount: Int
    @Published public var showLineNumbers: Bool
    @Published public var watermarkText: String
    @Published public var kern: CGFloat
    @Published public var hangingIndent: CGFloat
    
    // MARK: - DAG Time Travel Engine & Document Lifecycle
    @Published public var historyNodes: [UUID: HistoryNode] = [:]
    @Published public var currentSnapshotId: UUID? = nil
    @Published public var mainBranchHeadId: UUID? = nil
    @Published public var isPeeking: Bool = false
    @Published public var currentFileURL: URL? = nil
    @Published public var isDirty: Bool = false {
        didSet {
            NSApp.windows.first?.isDocumentEdited = isDirty
        }
    }
    @Published public var lastAutosaveDate: Date? = nil
    
    /// Installed by the canvas: archives the live text view into `richTextData` before the model is read.
    var flushEditor: (() -> Void)?

    var isReverting: Bool = false
    var cancellables = Set<AnyCancellable>()
    var backupBundleForPeek: LettersDocumentBundle? = nil
    
    public static var autosaveShadowURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = appSupport.appendingPathComponent("ProjectLetters", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("AutosaveRecovery.letters")
    }

    func performAutosave() {
        guard !isReverting, !isPeeking else { return }
        let bundle = createBundle()
        guard let data = try? bundle.encodeToData() else { return }
        // 1. Always write shadow recovery bundle
        try? data.write(to: Self.autosaveShadowURL, options: .atomic)
        // 2. If user already saved to a .letters or .ltt file on disk, autosave in place
        if let fileURL = currentFileURL {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "letters" || ext == "ltt" {
                if (try? data.write(to: fileURL, options: .atomic)) != nil {
                    isDirty = false
                }
            }
        }
        lastAutosaveDate = Date()
    }

    func markSaved(url: URL) {
        currentFileURL = url
        isDirty = false
        lastAutosaveDate = Date()
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        let titleStr = url.lastPathComponent
        NSApp.windows.first?.title = "Letters — \(titleStr)"
        NSApp.windows.first?.representedURL = url
    }
    
    private static func scrubDeadTags(text: String, tables: [StudioTableData], images: [StudioImageBlock], videos: [StudioVideoBlock]) -> String {
        let regex = EditorPerformanceCache.shared.canvasSegmentRegex
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        
        var toRemove: [NSRange] = []
        for match in matches {
            let kind = ns.substring(with: match.range(at: 1))
            let idStr = (match.numberOfRanges >= 3 && match.range(at: 2).location != NSNotFound) ? ns.substring(with: match.range(at: 2)) : ""
            
            if kind == "table" {
                if let uuid = UUID(uuidString: idStr), tables.contains(where: { $0.id == uuid }) { continue }
                if idStr.lowercased() == "budget" && !tables.isEmpty { continue }
                if tables.contains(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) { continue }
                toRemove.append(match.range)
            } else if kind == "image" {
                if let uuid = UUID(uuidString: idStr), images.contains(where: { $0.id == uuid }) { continue }
                if images.contains(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) { continue }
                toRemove.append(match.range)
            } else if kind == "video" {
                if let uuid = UUID(uuidString: idStr), videos.contains(where: { $0.id == uuid }) { continue }
                if videos.contains(where: { $0.id.uuidString.lowercased() == idStr.lowercased() }) { continue }
                toRemove.append(match.range)
            }
        }
        
        var cleanText = text
        for range in toRemove.reversed() {
            let nsMutable = NSMutableString(string: cleanText)
            nsMutable.deleteCharacters(in: range)
            cleanText = nsMutable as String
        }

        // Scrub any legacy `[note:1]` or `[note:xyz]` tags that might exist in old files
        cleanText = cleanText.replacingOccurrences(of: #"\s*\[note:[^\]]+\]"#, with: "", options: .regularExpression)
        
        return cleanText
    }

    public init(
        title: String = "Untitled Document",
        rawText: String = "",
        richTextData: Data? = nil,
        document: DocumentModel = DocumentModel(title: "Untitled", blocks: [], sources: [String: Source](), pageSize: .letter, margins: PageMargins(top: 72, bottom: 72, left: 72, right: 72)),
        tables: [StudioTableData] = [],
        images: [StudioImageBlock] = [],
        videos: [StudioVideoBlock] = [],
        floatingElements: [StudioFloatingElement] = [],
        footnotes: [StudioFootnote] = [],
        sideNotes: [StudioSideNote] = [],
        citationStyle: CitationStyle = .apa7,
        pageSize: PageSizePreset = .letter,
        marginPreset: MarginPreset = .normal,
        margins: PageMargins = PageMargins(top: 72, bottom: 72, left: 72, right: 72),
        coverBanner: CoverBannerConfig = CoverBannerConfig(),
        headerFooter: HeaderFooterConfig = HeaderFooterConfig(),
        isTrackChangesEnabled: Bool = false,
        revisions: [StudioTrackedRevision] = [],
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        lineSpacing: CGFloat = 1.15,
        paragraphSpacing: CGFloat = 12.0,
        textAlignment: TextAlignment = .leading,
        columnCount: Int = 1,
        showLineNumbers: Bool = false,
        watermarkText: String = "",
        kern: CGFloat = 0.0,
        hangingIndent: CGFloat = 0.0,
        styleProfile: String = "none"
    ) {
        self.title = title
        self.rawText = Self.scrubDeadTags(text: rawText, tables: tables, images: images, videos: videos)
        self.richTextData = richTextData
        self.document = document
        self.tables = tables
        self.images = images
        self.videos = videos
        self.floatingElements = floatingElements
        self.footnotes = footnotes
        self.sideNotes = sideNotes
        self.citationStyle = citationStyle
        self.pageSize = pageSize
        self.marginPreset = marginPreset
        self.margins = margins
        self.coverBanner = coverBanner
        self.headerFooter = headerFooter
        self.isTrackChangesEnabled = isTrackChangesEnabled
        self.revisions = revisions
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.textAlignment = textAlignment
        self.columnCount = columnCount
        self.showLineNumbers = showLineNumbers
        self.watermarkText = watermarkText
        self.kern = kern
        self.hangingIndent = hangingIndent
        self.styleProfile = styleProfile
        Self.active = self
        // Initial snapshot
        DispatchQueue.main.async {
            self.commitSnapshot(actionName: "Created Document", isMilestone: true)
            self.isDirty = false
        }
        
        $rawText
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.isDirty = true
            }
            .store(in: &cancellables)

        $rawText
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.commitSnapshot(actionName: "Typing", isMilestone: false)
                self.performAutosave()
            }
            .store(in: &cancellables)

        $tables
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.isDirty = true
                self.commitSnapshot(actionName: "Table Edit", isMilestone: false)
                self.performAutosave()
            }
            .store(in: &cancellables)

        $images
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting, !self.isPeeking else { return }
                self.isDirty = true
                self.performAutosave()
            }
            .store(in: &cancellables)
    }
    
    func createBundle() -> LettersDocumentBundle {
        flushEditor?()
        let alignStr: String
        switch textAlignment {
        case .leading: alignStr = "leading"
        case .center: alignStr = "center"
        case .trailing: alignStr = "trailing"
        }

        return LettersDocumentBundle(
            title: title,
            rawText: rawText,
            richTextData: richTextData,
            tables: tables,
            images: images,
            videos: videos,
            floatingElements: floatingElements,
            footnotes: footnotes,
            sideNotes: sideNotes,
            sources: document.sources,
            citationStyle: citationStyle,
            pageSizePreset: pageSize,
            marginPreset: marginPreset,
            margins: margins,
            fontFamily: fontFamily,
            fontSize: Double(fontSize),
            lineSpacing: Double(lineSpacing),
            paragraphSpacing: Double(paragraphSpacing),
            textAlignmentString: alignStr,
            columnCount: columnCount,
            showLineNumbers: showLineNumbers,
            watermarkText: watermarkText,
            kern: Double(kern),
            hangingIndent: Double(hangingIndent),
            headerFooter: headerFooter,
            coverBanner: coverBanner,
            isTrackChangesEnabled: isTrackChangesEnabled,
            revisions: revisions,
            styleProfile: styleProfile
        )
    }
    
    func loadBundle(_ bundle: LettersDocumentBundle) {
        self.title = bundle.title
        self.tables = bundle.tables
        self.images = bundle.images
        self.videos = bundle.videos
        self.floatingElements = bundle.floatingElements
        self.footnotes = bundle.footnotes
        self.sideNotes = bundle.sideNotes
        self.rawText = Self.scrubDeadTags(text: bundle.rawText, tables: bundle.tables, images: bundle.images, videos: bundle.videos)
        self.richTextData = bundle.richTextData
        self.document.sources = bundle.sources
        self.citationStyle = bundle.citationStyle
        self.pageSize = bundle.pageSizePreset
        self.marginPreset = bundle.marginPreset
        self.margins = bundle.margins
        switch bundle.textAlignmentString {
        case "center": self.textAlignment = .center
        case "trailing", "right": self.textAlignment = .trailing
        default: self.textAlignment = .leading
        }
        self.columnCount = bundle.columnCount
        self.showLineNumbers = bundle.showLineNumbers
        self.watermarkText = bundle.watermarkText
        self.coverBanner = bundle.coverBanner
        self.headerFooter = bundle.headerFooter
        self.isTrackChangesEnabled = bundle.isTrackChangesEnabled
        self.revisions = bundle.revisions
        self.styleProfile = bundle.styleProfile
        self.fontFamily = bundle.fontFamily
        self.fontSize = CGFloat(bundle.fontSize)
        self.lineSpacing = CGFloat(bundle.lineSpacing)
        self.paragraphSpacing = CGFloat(bundle.paragraphSpacing)
        self.kern = CGFloat(bundle.kern)
        self.hangingIndent = CGFloat(bundle.hangingIndent)
    }

    // MARK: - Track Changes & Revisions Engine
    func recordRevision(
        kind: StudioTrackedRevision.RevisionKind,
        text: String,
        originalText: String? = nil,
        author: String? = nil,
        rangeLocation: Int? = nil,
        pageIndex: Int? = nil
    ) {
        let auth = author ?? (NSFullUserName().isEmpty ? "Reviewer" : NSFullUserName())

        // 1. Coalesce rapid consecutive typing (insertions) into single revision card
        if kind == .insertion, originalText == nil,
           let last = revisions.last,
           last.kind == .insertion,
           last.originalText == nil,
           last.author == auth,
           Date().timeIntervalSince(last.createdAt) < 3.0 {
            revisions[revisions.count - 1].text += text
            revisions[revisions.count - 1].createdAt = Date()
            return
        }

        // 2. Coalesce rapid consecutive backspacing/deletions into single revision card
        if kind == .deletion,
           let last = revisions.last,
           last.kind == .deletion,
           last.author == auth,
           Date().timeIntervalSince(last.createdAt) < 3.0 {
            let lastOrig = last.originalText ?? ""
            let newOrig = originalText ?? ""
            if let newLoc = rangeLocation, let lastLoc = last.rangeLocation, newLoc <= lastLoc {
                revisions[revisions.count - 1].originalText = newOrig + lastOrig
                revisions[revisions.count - 1].rangeLocation = newLoc
            } else {
                revisions[revisions.count - 1].originalText = lastOrig + newOrig
            }
            revisions[revisions.count - 1].createdAt = Date()
            return
        }

        let rev = StudioTrackedRevision(
            id: UUID(),
            kind: kind,
            text: text,
            originalText: originalText,
            author: auth,
            createdAt: Date(),
            rangeLocation: rangeLocation,
            pageIndex: pageIndex
        )
        revisions.append(rev)
        commitSnapshot(actionName: "Track Change (\(kind.rawValue))", isMilestone: false)
    }

    func acceptRevision(id: UUID) {
        guard let rev = revisions.first(where: { $0.id == id }) else { return }
        if rev.kind == .deletion, let orig = rev.originalText, !orig.isEmpty {
            rawText = rawText.replacingOccurrences(of: orig, with: "")
        }
        revisions.removeAll(where: { $0.id == id })
        commitSnapshot(actionName: "Accept Change", isMilestone: false)
    }

    func rejectRevision(id: UUID) {
        guard let rev = revisions.first(where: { $0.id == id }) else { return }
        if rev.kind == .insertion {
            rawText = rawText.replacingOccurrences(of: rev.text, with: rev.originalText ?? "")
        } else if rev.kind == .deletion {
            if let orig = rev.originalText, !orig.isEmpty {
                if let loc = rev.rangeLocation, loc <= (rawText as NSString).length {
                    let ns = rawText as NSString
                    let newStr = ns.substring(to: loc) + orig + ns.substring(from: loc)
                    rawText = newStr
                } else {
                    rawText += orig
                }
            }
        }
        revisions.removeAll(where: { $0.id == id })
        commitSnapshot(actionName: "Reject Change", isMilestone: false)
    }

    func acceptAllRevisions() {
        for rev in revisions {
            if rev.kind == .deletion, let orig = rev.originalText ?? (rev.text.isEmpty ? nil : rev.text) {
                rawText = rawText.replacingOccurrences(of: orig, with: "")
            }
        }
        revisions.removeAll()
        commitSnapshot(actionName: "Accept All Changes", isMilestone: false)
    }

    func rejectAllRevisions() {
        for rev in revisions.reversed() {
            if rev.kind == .insertion {
                rawText = rawText.replacingOccurrences(of: rev.text, with: rev.originalText ?? "")
            } else if rev.kind == .deletion {
                if let orig = rev.originalText, !orig.isEmpty {
                    if let loc = rev.rangeLocation, loc <= (rawText as NSString).length {
                        let ns = rawText as NSString
                        let newStr = ns.substring(to: loc) + orig + ns.substring(from: loc)
                        rawText = newStr
                    } else {
                        rawText += orig
                    }
                }
            }
        }
        revisions.removeAll()
        commitSnapshot(actionName: "Reject All Changes", isMilestone: false)
    }
    
    // MARK: - DAG Engine Methods
    
    func generateDiffSummary(old: LettersDocumentBundle, new: LettersDocumentBundle) -> String? {
        var diffs = [String]()
        
        let oldWords = old.rawText.split(whereSeparator: { $0.isWhitespace }).count
        let newWords = new.rawText.split(whereSeparator: { $0.isWhitespace }).count
        let wordDiff = newWords - oldWords
        
        if wordDiff > 0 { diffs.append("+\(wordDiff) words") }
        else if wordDiff < 0 { diffs.append("\(wordDiff) words") }
        
        let tableDiff = new.tables.count - old.tables.count
        if tableDiff > 0 { diffs.append("+\(tableDiff) table") }
        else if tableDiff < 0 { diffs.append("\(tableDiff) table") }
        
        return diffs.isEmpty ? nil : diffs.joined(separator: ", ")
    }
    
    func commitSnapshot(actionName: String, actor: SnapshotActor = .user, isMilestone: Bool = false) {
        if isReverting || isPeeking { return }
        
        let newBundle = createBundle()
        var diffSummary: String? = nil
        
        if let parentId = currentSnapshotId, let parentNode = historyNodes[parentId] {
            // Prevent duplicate identical snapshots
            if parentNode.bundle.rawText == newBundle.rawText && parentNode.bundle.tables == newBundle.tables {
                return 
            }
            diffSummary = generateDiffSummary(old: parentNode.bundle, new: newBundle)
        }
        
        let newNode = HistoryNode(
            id: UUID(),
            parentId: currentSnapshotId,
            timestamp: Date(),
            actionName: actionName,
            diffSummary: diffSummary,
            actor: actor,
            isMilestone: isMilestone,
            isPinned: false,
            customName: nil,
            bundle: newBundle
        )
        
        historyNodes[newNode.id] = newNode
        if mainBranchHeadId == nil || currentSnapshotId == mainBranchHeadId {
            mainBranchHeadId = newNode.id
        }
        currentSnapshotId = newNode.id
        
        // Memory cap: 200 nodes. Garbage collect oldest non-pinned leaves if necessary.
        if historyNodes.count > 200 {
            garbageCollectOldestNode()
        }
    }
    
    func garbageCollectOldestNode() {
        let sorted = historyNodes.values
            .filter { !$0.isPinned && $0.parentId == nil } // Try to kill roots first
            .sorted { $0.timestamp < $1.timestamp }
        
        if let oldest = sorted.first {
            historyNodes.removeValue(forKey: oldest.id)
        }
    }
    
    // MARK: - Time Travel & Peek
    
    func setAsMainBranch(nodeId: UUID) {
        mainBranchHeadId = nodeId
        if currentSnapshotId != nodeId {
            revertTo(id: nodeId)
        }
    }

    func revertTo(id: UUID) {
        guard let node = historyNodes[id] else { return }
        isReverting = true
        currentSnapshotId = id
        loadBundle(node.bundle)
        isReverting = false
    }
    
    func startPeek(id: UUID) {
        guard !isPeeking, let node = historyNodes[id] else { return }
        isPeeking = true
        backupBundleForPeek = createBundle()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            loadBundle(node.bundle)
        }
    }
    
    func endPeek() {
        guard isPeeking, let backup = backupBundleForPeek else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            loadBundle(backup)
        }
        backupBundleForPeek = nil
        isPeeking = false
    }
    
    func togglePin(id: UUID) {
        historyNodes[id]?.isPinned.toggle()
    }
    
    // MARK: - Micro Undo/Redo (Linear path resolution)
    
    func undo() {
        guard let current = currentSnapshotId, let node = historyNodes[current], let parentId = node.parentId else { return }
        revertTo(id: parentId)
    }
    
    func redo() {
        // Redo follows the most recently created child of the current node
        guard let current = currentSnapshotId else { return }
        let children = historyNodes.values.filter { $0.parentId == current }.sorted { $0.timestamp > $1.timestamp }
        if let mostRecentChild = children.first {
            revertTo(id: mostRecentChild.id)
        }
    }

    // MARK: - Tables API (Migrated to Snapshot Engine)
    
    func mutateTable(id: UUID, actionName: String? = nil, mutation: (inout StudioTableData) -> Void) {
        guard let index = tables.firstIndex(where: { $0.id == id }) else { return }
        var newTable = tables[index]
        mutation(&newTable)
        self.tables[index] = newTable
        
        if let name = actionName {
            commitSnapshot(actionName: name, isMilestone: true)
        }
    }
    
    func addTable(_ table: StudioTableData) {
        tables.append(table)
        commitSnapshot(actionName: "Insert Table", isMilestone: true)
    }
    
    func removeTable(id: UUID) {
        guard let index = tables.firstIndex(where: { $0.id == id }) else { return }
        tables.remove(at: index)
        commitSnapshot(actionName: "Delete Table", isMilestone: true)
    }
    
    func insertTable(_ table: StudioTableData, at index: Int) {
        tables.insert(table, at: index)
        commitSnapshot(actionName: "Insert Table", isMilestone: true)
    }
}
