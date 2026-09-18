import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct StudioDocumentTimelineView: View {
    @Binding var isPresented: Bool
    @Binding var rawText: String
    let wordCount: Int
    let characterCount: Int
    let readingTimeMinutes: Int
    var onSelectHeading: ((String) -> Void)? = nil

    @State private var hoveredHeading: String? = nil

    public init(
        isPresented: Binding<Bool>,
        rawText: Binding<String>,
        wordCount: Int,
        characterCount: Int,
        readingTimeMinutes: Int,
        onSelectHeading: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._rawText = rawText
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.readingTimeMinutes = readingTimeMinutes
        self.onSelectHeading = onSelectHeading
    }

    private struct TimelineHeading: Identifiable {
        let id = UUID()
        let level: Int
        let title: String
        let approximateWords: Int
    }

    private var parsedTimeline: [TimelineHeading] {
        var headings: [TimelineHeading] = []
        let sections = rawText.components(separatedBy: .newlines)
        var currentTitle = "Overview"
        var currentLevel = 1
        var currentWords = 0

        for line in sections {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("### ") {
                if currentWords > 0 {
                    headings.append(TimelineHeading(level: currentLevel, title: currentTitle, approximateWords: currentWords))
                }
                currentTitle = String(trimmed.dropFirst(4))
                currentLevel = 3
                currentWords = 0
            } else if trimmed.hasPrefix("## ") {
                if currentWords > 0 {
                    headings.append(TimelineHeading(level: currentLevel, title: currentTitle, approximateWords: currentWords))
                }
                currentTitle = String(trimmed.dropFirst(3))
                currentLevel = 2
                currentWords = 0
            } else if trimmed.hasPrefix("# ") {
                if currentWords > 0 {
                    headings.append(TimelineHeading(level: currentLevel, title: currentTitle, approximateWords: currentWords))
                }
                currentTitle = String(trimmed.dropFirst(2))
                currentLevel = 1
                currentWords = 0
            } else {
                currentWords += EditorPerformanceCache.countWords(in: trimmed)
            }
        }
        if currentWords > 0 || headings.isEmpty {
            headings.append(TimelineHeading(level: currentLevel, title: currentTitle, approximateWords: max(1, currentWords)))
        }
        return headings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Header (Timeline Title & Dismiss)
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(StudioTheme.luminousAmber)
                    Text("Reading Flow")
                        .font(.system(size: 12, weight: .bold))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.primary.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            Divider()
                .padding(.horizontal, 8)

            // 2. Circular Reading Progress Card (Inspired by reference app timer ring)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 3)
                        .frame(width: 36, height: 36)

                    Circle()
                        .trim(from: 0.0, to: min(1.0, Double(wordCount) / 1000.0))
                        .stroke(
                            LinearGradient(
                                colors: [StudioTheme.luminousAmber, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 36, height: 36)

                    Text("\(readingTimeMinutes)m")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(StudioTheme.luminousAmber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(wordCount) words")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("Est. ~\(readingTimeMinutes) min reading time")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(8)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 8)

            // 3. Vertical Track Timeline of Sections
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(parsedTimeline.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            // Timeline track & circular node
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(item.level == 1 ? StudioTheme.luminousAmber : (item.level == 2 ? StudioTheme.luminousBlue : StudioTheme.luminousPurple))
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 4)

                                if index < parsedTimeline.count - 1 {
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.12))
                                        .frame(width: 1.5)
                                        .frame(minHeight: 28)
                                }
                            }
                            .frame(width: 10)

                            // Section Details Card
                            Button {
                                onSelectHeading?(item.title)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 10.5, weight: item.level == 1 ? .semibold : .medium))
                                        .foregroundColor(hoveredHeading == item.title ? .accentColor : .primary)
                                        .lineLimit(1)

                                    HStack(spacing: 4) {
                                        Text("\(item.approximateWords) words")
                                            .font(.system(size: 8.5, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    hoveredHeading == item.title
                                        ? Color.primary.opacity(0.06)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { isHov in
                                hoveredHeading = isHov ? item.title : nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(StudioTheme.islandBackground)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 10)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
    }
}
