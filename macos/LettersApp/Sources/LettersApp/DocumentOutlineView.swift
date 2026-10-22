import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public enum OutlineDrawerTab: String, CaseIterable {
    case outline = "Outline"
    case pages = "Pages"
    case sources = "Sources"
}

public struct DocumentOutlineView: View {
    @Binding var isPresented: Bool
    let rawText: String
    let pageSlices: [DocumentPageSlice]
    let columnCount: Int
    @Binding var sources: [String: Source]
    @Binding var activeCitationStyle: CitationStyle
    var onSelectHeading: ((Int, Int) -> Void)?
    var onSelectPage: ((Int) -> Void)?

    @State private var activeTab: OutlineDrawerTab = .outline

    public init(
        isPresented: Binding<Bool>,
        rawText: String,
        pageSlices: [DocumentPageSlice],
        columnCount: Int = 1,
        sources: Binding<[String: Source]>,
        activeCitationStyle: Binding<CitationStyle>,
        onSelectHeading: ((Int, Int) -> Void)? = nil,
        onSelectPage: ((Int) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.rawText = rawText
        self.pageSlices = pageSlices
        self.columnCount = max(1, columnCount)
        self._sources = sources
        self._activeCitationStyle = activeCitationStyle
        self.onSelectHeading = onSelectHeading
        self.onSelectPage = onSelectPage
    }

    private struct LiveHeadingItem: Identifiable {
        let id: String
        let title: String
        let level: Int
        let columnIndex: Int
        let pageNumber: Int
        let localOffset: Int
    }

    private var headings: [LiveHeadingItem] {
        var items: [LiveHeadingItem] = []
        let regex = EditorPerformanceCache.shared.tocHeadingRegex

        for (colIdx, slice) in pageSlices.enumerated() {
            let pageNum = (colIdx / columnCount) + 1
            let nsSlice = slice.text as NSString
            var lineOffset = 0
            let lines = slice.text.components(separatedBy: "\n")

            for (lineIdx, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("# ") {
                    let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        items.append(LiveHeadingItem(id: "c\(colIdx)-l\(lineIdx)", title: title, level: 1, columnIndex: colIdx, pageNumber: pageNum, localOffset: lineOffset))
                    }
                } else if trimmed.hasPrefix("## ") {
                    let title = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        items.append(LiveHeadingItem(id: "c\(colIdx)-l\(lineIdx)", title: title, level: 2, columnIndex: colIdx, pageNumber: pageNum, localOffset: lineOffset))
                    }
                } else if trimmed.hasPrefix("### ") {
                    let title = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        items.append(LiveHeadingItem(id: "c\(colIdx)-l\(lineIdx)", title: title, level: 3, columnIndex: colIdx, pageNumber: pageNum, localOffset: lineOffset))
                    }
                } else {
                    let nsTrimmed = trimmed as NSString
                    if let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: nsTrimmed.length)),
                       match.range.location != NSNotFound {
                        let dotCount = trimmed.prefix(while: { $0 != " " }).filter { $0 == "." }.count
                        items.append(LiveHeadingItem(id: "c\(colIdx)-l\(lineIdx)", title: trimmed, level: max(1, dotCount), columnIndex: colIdx, pageNumber: pageNum, localOffset: lineOffset))
                    } else if !trimmed.isEmpty,
                              !trimmed.hasPrefix("[["),
                              trimmed.count <= 120,
                              let attrSlice = slice.attributedText,
                              lineOffset < attrSlice.length,
                              let font = attrSlice.attribute(.font, at: lineOffset, effectiveRange: nil) as? NSFont {
                        let traits = NSFontManager.shared.traits(of: font)
                        let isBold = traits.contains(.boldFontMask)
                        let isItalic = traits.contains(.italicFontMask)
                        let preset = DocumentParagraphStyle.infer(fontSize: font.pointSize, isBold: isBold, isItalic: isItalic)
                        if preset == .title || preset == .heading1 {
                            items.append(LiveHeadingItem(id: "c\(colIdx)-l\(lineIdx)", title: trimmed, level: 1, columnIndex: colIdx, pageNumber: pageNum, localOffset: lineOffset))
                        } else if preset == .heading2 {
                            items.append(LiveHeadingItem(id: "c\(colIdx)-l\(lineIdx)", title: trimmed, level: 2, columnIndex: colIdx, pageNumber: pageNum, localOffset: lineOffset))
                        } else if preset == .heading3 {
                            items.append(LiveHeadingItem(id: "c\(colIdx)-l\(lineIdx)", title: trimmed, level: 3, columnIndex: colIdx, pageNumber: pageNum, localOffset: lineOffset))
                        }
                    }
                }
                lineOffset = min(nsSlice.length, lineOffset + (line as NSString).length + 1)
            }
        }
        return items
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(pageSlices.count) / Double(columnCount))))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.bullet.indent")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13, weight: .semibold))
                Text("Navigator")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Picker("", selection: $activeTab) {
                ForEach(OutlineDrawerTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider()

            switch activeTab {
            case .outline:
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        if headings.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("No headings in document")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Text("Add # Heading 1, ## Heading 2, or numbered sections (1. Intro) to populate the outline.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                        } else {
                            ForEach(headings) { item in
                                Button {
                                    onSelectHeading?(item.columnIndex, item.localOffset)
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(item.title)
                                            .font(.system(size: item.level == 1 ? 12.5 : 11.5, weight: item.level == 1 ? .semibold : .regular))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .padding(.leading, CGFloat((item.level - 1) * 12))
                                        Spacer()
                                        Text("p. \(item.pageNumber)")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(12)
                }

            case .pages:
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { pageIdx in
                            let colIdx = pageIdx * columnCount
                            let preview = colIdx < pageSlices.count
                                ? pageSlices[colIdx].text.trimmingCharacters(in: .whitespacesAndNewlines)
                                : ""
                            Button {
                                onSelectPage?(colIdx)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white)
                                            .frame(width: 28, height: 36)
                                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                        Text("\(pageIdx + 1)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Page \(pageIdx + 1)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text(preview.isEmpty ? "Empty page" : String(preview.prefix(60)))
                                            .font(.system(size: 10.5))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }

            case .sources:
                SourceManagerView(
                    sources: $sources,
                    activeStyle: $activeCitationStyle
                )
            }
        }
        .frame(width: 270)
        .frame(maxHeight: 540)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}
