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
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Master Page / Section Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Page Spreads")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)

                            // Page 1 Thumbnail Card
                            Button {
                                selectedPage = 1
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .topLeading) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(StudioTheme.paperBackground)
                                            .frame(width: 140, height: 180)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .stroke(selectedPage == 1 ? Color.accentColor : StudioTheme.border, lineWidth: selectedPage == 1 ? 2 : 1)
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
                                                Text("1")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(10)
                                        .frame(width: 140, height: 180)
                                    }

                                    Text("Page 1 - Overview")
                                        .font(.caption2)
                                        .foregroundColor(selectedPage == 1 ? .primary : .secondary)
                                }
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)

                            // Page 2 Thumbnail Card
                            Button {
                                selectedPage = 2
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .topLeading) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(StudioTheme.paperBackground)
                                            .frame(width: 140, height: 180)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .stroke(selectedPage == 2 ? Color.accentColor : StudioTheme.border, lineWidth: selectedPage == 2 ? 2 : 1)
                                            )
                                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

                                        // Mini wireframe
                                        VStack(alignment: .leading, spacing: 4) {
                                            RoundedRectangle(cornerRadius: 1)
                                                .fill(Color.primary.opacity(0.25))
                                                .frame(width: 80, height: 5)
                                            RoundedRectangle(cornerRadius: 1)
                                                .fill(Color.primary.opacity(0.12))
                                                .frame(width: 110, height: 4)
                                            RoundedRectangle(cornerRadius: 1)
                                                .fill(Color.primary.opacity(0.12))
                                                .frame(width: 105, height: 4)
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                Text("2")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(10)
                                        .frame(width: 140, height: 180)
                                    }

                                    Text("Page 2 - Analysis")
                                        .font(.caption2)
                                        .foregroundColor(selectedPage == 2 ? .primary : .secondary)
                                }
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)
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
