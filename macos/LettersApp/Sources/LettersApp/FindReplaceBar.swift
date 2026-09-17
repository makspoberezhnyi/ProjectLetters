import SwiftUI

public struct FindReplaceBar: View {
    @Binding var isPresented: Bool
    @Binding var rawText: String
    var onToast: ((String) -> Void)? = nil

    @State private var findQuery: String = ""
    @State private var replaceQuery: String = ""
    @State private var currentMatchIndex: Int = 0
    @State private var matchRanges: [Range<String.Index>] = []
    @State private var isCaseSensitive: Bool = false

    public init(
        isPresented: Binding<Bool>,
        rawText: Binding<String>,
        onToast: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._rawText = rawText
        self.onToast = onToast
    }

    private var matchCount: Int {
        matchRanges.count
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Find Row
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Find in document...", text: $findQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        findNext()
                    }
                    .onChange(of: findQuery) { _, _ in
                        recalculateMatches()
                    }

                if !findQuery.isEmpty {
                    Text(matchCount > 0 ? "\(currentMatchIndex + 1) of \(matchCount)" : "No matches")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(matchCount > 0 ? .secondary : .red)

                    // Prev / Next Buttons
                    Button(action: findPrev) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(matchCount == 0)
                    .help("Previous Match (Shift+Enter)")

                    Button(action: findNext) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(matchCount == 0)
                    .help("Next Match (Enter)")
                }

                // Close Button
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Find & Replace (Esc)")
            }

            Divider()

            // Replace Row
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Replace with...", text: $replaceQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                Spacer()

                // 1. Single Replace (replaces current specific match only)
                Button("Replace") {
                    replaceCurrentMatch()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(matchCount == 0)
                .help("Replace current matching instance")

                // 2. Replace All
                Button("Replace All") {
                    replaceAllMatches()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(matchCount == 0)
                .help("Replace all matching instances in document")
            }
        }
        .padding(10)
        .frame(width: 380)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
        .onAppear {
            recalculateMatches()
        }
    }

    private func recalculateMatches() {
        guard !findQuery.isEmpty else {
            matchRanges = []
            currentMatchIndex = 0
            return
        }

        var ranges: [Range<String.Index>] = []
        var searchStart = rawText.startIndex
        let options: String.CompareOptions = isCaseSensitive ? [] : [.caseInsensitive]

        while searchStart < rawText.endIndex,
              let range = rawText.range(of: findQuery, options: options, range: searchStart..<rawText.endIndex) {
            ranges.append(range)
            searchStart = range.upperBound
        }

        matchRanges = ranges
        if currentMatchIndex >= ranges.count {
            currentMatchIndex = 0
        }
    }

    private func findNext() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchCount
    }

    private func findPrev() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchCount) % matchCount
    }

    private func replaceCurrentMatch() {
        guard matchCount > 0, matchRanges.indices.contains(currentMatchIndex) else { return }
        let targetRange = matchRanges[currentMatchIndex]
        rawText.replaceSubrange(targetRange, with: replaceQuery)
        onToast?("✓ Replaced instance (\(currentMatchIndex + 1)/\(matchCount))")
        recalculateMatches()
    }

    private func replaceAllMatches() {
        guard !findQuery.isEmpty else { return }
        let count = matchCount
        let options: String.CompareOptions = isCaseSensitive ? [] : [.caseInsensitive]
        rawText = rawText.replacingOccurrences(of: findQuery, with: replaceQuery, options: options)
        onToast?("✓ Replaced all \(count) occurrences")
        recalculateMatches()
    }
}
