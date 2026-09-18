import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct StudioPagesNavigator: View {
    @Binding var rawText: String
    @Binding var selectedPage: Int
    @State private var activeTab: NavigatorTab = .pages

    enum NavigatorTab: String, CaseIterable {
        case pages = "Pages"
        case outline = "Outline"
        case assets = "Assets"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Tab Header (Pages / Outline / Assets)
            Picker("Navigator", selection: $activeTab) {
                ForEach(NavigatorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            if activeTab == .pages {
                // Page Spreads / Thumbnails (Affinity Publisher Style)
                let pages = rawText.components(separatedBy: "---pagebreak---")
                let pageList = pages.isEmpty ? [""] : pages

                ScrollView {
                    LazyVStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Page Spreads (\(pageList.count))")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)

                            ForEach(0..<pageList.count, id: \.self) { idx in
                                let pageNum = idx + 1
                                let pageContent = pageList[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                                let firstLine = pageContent.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? "Page \(pageNum)"
                                let titlePreview = firstLine.isEmpty ? "Page \(pageNum)" : String(firstLine.prefix(20))

                                Button {
                                    selectedPage = pageNum
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack(alignment: .topLeading) {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(StudioTheme.paperBackground)
                                                .frame(width: 140, height: 180)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                        .stroke(selectedPage == pageNum ? Color.accentColor : StudioTheme.border, lineWidth: selectedPage == pageNum ? 2 : 1)
                                                )
                                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

                                            // Mini wireframe representation
                                            VStack(alignment: .leading, spacing: 4) {
                                                RoundedRectangle(cornerRadius: 1)
                                                    .fill(Color.primary.opacity(0.3))
                                                    .frame(width: 70, height: 6)
                                                RoundedRectangle(cornerRadius: 1)
                                                    .fill(Color.primary.opacity(0.15))
                                                    .frame(width: 100, height: 4)
                                                RoundedRectangle(cornerRadius: 1)
                                                    .fill(Color.primary.opacity(0.15))
                                                    .frame(width: 90, height: 4)
                                                RoundedRectangle(cornerRadius: 1)
                                                    .fill(Color.primary.opacity(0.15))
                                                    .frame(width: 110, height: 4)
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    Text("\(pageNum)")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(10)
                                            .frame(width: 140, height: 180)
                                        }

                                        Text("Page \(pageNum) - \(titlePreview)")
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .foregroundColor(selectedPage == pageNum ? .primary : .secondary)
                                    }
                                    .padding(.horizontal, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else if activeTab == .outline {
                // Section Outline
                List {
                    Section("Document Headings") {
                        ForEach(extractHeadings(from: rawText), id: \.self) { heading in
                            HStack(spacing: 6) {
                                Image(systemName: "number")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(heading)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            } else {
                // Assets & Tables
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No assets attached")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                Spacer()
            }
        }
        .frame(minWidth: 170, idealWidth: 190, maxWidth: 220)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .trailing
        )
    }

    private func extractHeadings(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("#") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).trimmingCharacters(in: .whitespaces) }
    }
}
