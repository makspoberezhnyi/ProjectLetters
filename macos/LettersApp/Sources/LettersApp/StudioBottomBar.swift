import SwiftUI

public struct StudioBottomBar: View {
    @Binding var selectedPage: Int
    let totalPages: Int
    let wordCount: Int
    let characterCount: Int
    let readingTime: Int
    @Binding var zoomLevel: Double

    public init(
        selectedPage: Binding<Int>,
        totalPages: Int = 1,
        wordCount: Int,
        characterCount: Int,
        readingTime: Int,
        zoomLevel: Binding<Double>
    ) {
        self._selectedPage = selectedPage
        self.totalPages = totalPages
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.readingTime = readingTime
        self._zoomLevel = zoomLevel
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Page Navigator
            HStack(spacing: 6) {
                Button {
                    if selectedPage > 1 { selectedPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .disabled(selectedPage <= 1)

                Text("Page \(selectedPage) of \(totalPages)")
                    .font(.caption2.monospacedDigit().weight(.medium))

                Button {
                    if selectedPage < totalPages { selectedPage += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(StudioTheme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .disabled(selectedPage >= totalPages)
            }

            Divider()
                .frame(height: 12)

            // Live Document Stats
            HStack(spacing: 12) {
                Text("\(wordCount) words")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)

                Text("\(characterCount) characters")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)

                Text("~\(readingTime) min read")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Zoom Controller (Figma / Affinity Style)
            HStack(spacing: 8) {
                Button {
                    zoomLevel = max(0.5, zoomLevel - 0.1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)

                Slider(value: $zoomLevel, in: 0.5...2.0)
                    .frame(width: 80)
                    .controlSize(.mini)

                Button {
                    zoomLevel = min(2.0, zoomLevel + 0.1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)

                Text("\(Int(zoomLevel * 100))%")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .frame(width: 38, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .top
        )
    }
}
