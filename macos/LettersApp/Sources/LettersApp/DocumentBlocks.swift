import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Block markers

/// Rich blocks live in the text as a single marker paragraph (`[[table:UUID]]`, `[[image:UUID]]`, `[[toc]]`,
/// `[[bibliography]]`, `---pagebreak---`). The canvas reserves vertical space for that paragraph and pins a
/// view on top of it, so blocks scroll, zoom and paginate with the text instead of floating over it.
public enum BlockKind: Hashable {
    case table(UUID)
    case image(UUID)
    case video(UUID)
    case tableOfContents
    case bibliography
    case pageBreak

    /// Parses the *whole* paragraph (already trimmed). Anything else is ordinary text.
    public init?(marker: String) {
        if marker == "---pagebreak---" { self = .pageBreak; return }
        guard marker.hasPrefix("[["), marker.hasSuffix("]]") else { return nil }
        let inner = marker.dropFirst(2).dropLast(2)
        let parts = inner.split(separator: ":", maxSplits: 1).map(String.init)
        switch parts.first {
        case "toc" where parts.count == 1: self = .tableOfContents
        case "bibliography" where parts.count == 1: self = .bibliography
        case "table" where parts.count == 2: guard let id = UUID(uuidString: parts[1]) else { return nil }; self = .table(id)
        case "image" where parts.count == 2: guard let id = UUID(uuidString: parts[1]) else { return nil }; self = .image(id)
        case "video" where parts.count == 2: guard let id = UUID(uuidString: parts[1]) else { return nil }; self = .video(id)
        default: return nil
        }
    }

    public var isPageBreak: Bool { self == .pageBreak }

    /// Page breaks are drawn as a rule; videos have no inline renderer yet. Everything else gets a hosted view.
    var hasHostedView: Bool {
        switch self {
        case .pageBreak, .video: return false
        default: return true
        }
    }

    /// Height used until the hosted view has been measured.
    var provisionalHeight: CGFloat {
        switch self {
        case .table: return 150
        case .image, .video: return 220
        case .tableOfContents, .bibliography: return 160
        case .pageBreak: return 16
        }
    }
}

public struct BlockMarker: Equatable {
    public let kind: BlockKind
    /// Range of the marker text itself (without surrounding newlines).
    public let range: NSRange

    private static let regex: NSRegularExpression = {
        // A marker is a paragraph on its own line.
        let pattern = #"^(?:\[\[(?:table|image|video):[A-Za-z0-9\-]+\]\]|\[\[(?:toc|bibliography)\]\]|---pagebreak---)[ \t]*$"#
        return (try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])) ?? NSRegularExpression()
    }()

    public static func scan(_ string: String) -> [BlockMarker] {
        let ns = string as NSString
        // NSString search is far cheaper than Swift's Unicode-aware `contains` on a long manuscript.
        guard ns.range(of: "[[").location != NSNotFound || ns.range(of: "---pagebreak---").location != NSNotFound else { return [] }
        return regex.matches(in: string, options: [], range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let text = ns.substring(with: match.range).trimmingCharacters(in: .whitespaces)
            guard let kind = BlockKind(marker: text) else { return nil }
            return BlockMarker(kind: kind, range: match.range)
        }
    }
}

// MARK: - Hosting view that reports its content height

final class BlockHostingView: NSHostingView<AnyView> {
    var onHeightChange: ((CGFloat) -> Void)?
    private var reported: CGFloat = 0

    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        sizingOptions = [.intrinsicContentSize]
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in self?.reportHeight() }
    }

    override func layout() {
        super.layout()
        reportHeight()
    }

    func reportHeight() {
        let h = ceil(fittingSize.height)
        guard h > 1, abs(h - reported) > 1 else { return }
        reported = h
        onHeightChange?(h)
    }
}

// MARK: - SwiftUI content for each block kind

struct DocumentBlockView: View {
    let kind: BlockKind
    @ObservedObject var document: LettersDocumentController
    var onToast: (String) -> Void

    private func removeMarker(_ marker: String) {
        document.rawText = document.rawText.replacingOccurrences(of: marker, with: "")
    }

    var body: some View {
        switch kind {
        case .table(let id):
            if document.tables.contains(where: { $0.id == id }) {
                SmartTableView(
                    store: document,
                    tableId: id,
                    fontFamily: document.fontFamily,
                    onDelete: {
                        document.tables.removeAll { $0.id == id }
                        removeMarker("[[table:\(id.uuidString)]]")
                        onToast("Table deleted")
                    },
                    onChange: { document.commitSnapshot(actionName: "Edit Table", isMilestone: false) },
                    onToast: onToast
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .image(let id):
            if let index = document.images.firstIndex(where: { $0.id == id }) {
                StudioImageView(
                    imageBlock: Binding(
                        get: { document.images.first(where: { $0.id == id }) ?? document.images[min(index, document.images.count - 1)] },
                        set: { newValue in
                            if let i = document.images.firstIndex(where: { $0.id == id }) { document.images[i] = newValue }
                        }
                    ),
                    onDelete: {
                        document.images.removeAll { $0.id == id }
                        removeMarker("[[image:\(id.uuidString)]]")
                        onToast("Figure deleted")
                    },
                    onChange: { onToast("Figure updated") },
                    onToast: onToast
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }

        case .video:
            EmptyView()

        case .tableOfContents:
            DynamicTOCView(
                rawText: document.rawText,
                richTextData: document.richTextData,
                onDelete: {
                    removeMarker("[[toc]]")
                    onToast("Table of contents deleted")
                },
                onToast: onToast
            )

        case .bibliography:
            DynamicBibliographyView(
                sources: document.document.sources,
                activeStyle: Binding(get: { document.citationStyle }, set: { document.citationStyle = $0 }),
                onDelete: {
                    removeMarker("[[bibliography]]")
                    onToast("Bibliography deleted")
                },
                onToast: onToast
            )

        case .pageBreak:
            HStack(spacing: 8) {
                Rectangle().fill(Color.secondary.opacity(0.35)).frame(height: 1)
                Text("Page Break").textCase(.uppercase)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
                Rectangle().fill(Color.secondary.opacity(0.35)).frame(height: 1)
            }
            .frame(height: 16)
            .allowsHitTesting(false)
        }
    }
}
