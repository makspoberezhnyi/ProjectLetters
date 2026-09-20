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
    @State private var isRegex: Bool = false
    @State private var regexErrorMessage: String? = nil

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
                    .font(.system(size: 12, design: isRegex ? .monospaced : .default))
                    .onSubmit {
                        findNext()
                    }
                    .onChange(of: findQuery) { _, _ in
                        recalculateMatches()
                    }

                // Mode Toggles: Match Case & Regular Expressions
                HStack(spacing: 3) {
                    Button {
                        isCaseSensitive.toggle()
                        recalculateMatches()
                    } label: {
                        Text("Aa")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 18)
                            .background(isCaseSensitive ? Color.accentColor.opacity(0.2) : Color.clear)
                            .foregroundColor(isCaseSensitive ? .accentColor : .secondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Match Case (Case Sensitive)")

                    Button {
                        isRegex.toggle()
                        recalculateMatches()
                    } label: {
                        Text(".*")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 22, height: 18)
                            .background(isRegex ? Color.accentColor.opacity(0.2) : Color.clear)
                            .foregroundColor(isRegex ? .accentColor : .secondary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Use Regular Expressions (Regex with $1, $2 capture groups)")
                }

                if let err = regexErrorMessage {
                    Text("Regex error")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                        .help(err)
                } else if !findQuery.isEmpty {
                    Text(matchCount > 0 ? "\(currentMatchIndex + 1) of \(matchCount)" : "No matches")
                        .font(.system(size: 11))
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

                TextField(isRegex ? "Replace (supports $1, $2, $0)..." : "Replace with...", text: $replaceQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: isRegex ? .monospaced : .default))

                Spacer()

                // 1. Single Replace
                Button("Replace") {
                    replaceCurrentMatch()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(matchCount == 0 || regexErrorMessage != nil)
                .help(isRegex ? "Replace active match with capture group expansion" : "Replace current matching instance")

                // 2. Replace All
                Button("Replace All") {
                    replaceAllMatches()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(matchCount == 0 || regexErrorMessage != nil)
                .help(isRegex ? "Replace all matches expanding $1, $2 across document" : "Replace all matching instances in document")
            }
        }
        .padding(10)
        .frame(width: 440)
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
            regexErrorMessage = nil
            currentMatchIndex = 0
            return
        }

        if isRegex {
            do {
                var regexOptions: NSRegularExpression.Options = []
                if !isCaseSensitive {
                    regexOptions.insert(.caseInsensitive)
                }
                let regex = try NSRegularExpression(pattern: findQuery, options: regexOptions)
                regexErrorMessage = nil

                let nsStr = rawText as NSString
                let nsMatches = regex.matches(in: rawText, options: [], range: NSRange(location: 0, length: nsStr.length))
                var swiftRanges: [Range<String.Index>] = []
                for match in nsMatches {
                    if let r = Range(match.range, in: rawText) {
                        swiftRanges.append(r)
                    }
                }
                matchRanges = swiftRanges
                if currentMatchIndex >= swiftRanges.count {
                    currentMatchIndex = 0
                }
            } catch {
                matchRanges = []
                regexErrorMessage = error.localizedDescription
                currentMatchIndex = 0
            }
        } else {
            regexErrorMessage = nil
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

        if isRegex {
            do {
                var regexOptions: NSRegularExpression.Options = []
                if !isCaseSensitive {
                    regexOptions.insert(.caseInsensitive)
                }
                let regex = try NSRegularExpression(pattern: findQuery, options: regexOptions)
                let nsStr = rawText as NSString
                let nsMatches = regex.matches(in: rawText, options: [], range: NSRange(location: 0, length: nsStr.length))
                if nsMatches.indices.contains(currentMatchIndex) {
                    let match = nsMatches[currentMatchIndex]
                    let replacement = regex.replacementString(for: match, in: rawText, offset: 0, template: replaceQuery)
                    if let swiftRange = Range(match.range, in: rawText) {
                        rawText.replaceSubrange(swiftRange, with: replacement)
                        onToast?("✓ Regex replaced instance (\(currentMatchIndex + 1)/\(matchCount))")
                        recalculateMatches()
                    }
                }
            } catch {
                regexErrorMessage = error.localizedDescription
            }
        } else {
            let targetRange = matchRanges[currentMatchIndex]
            rawText.replaceSubrange(targetRange, with: replaceQuery)
            onToast?("✓ Replaced instance (\(currentMatchIndex + 1)/\(matchCount))")
            recalculateMatches()
        }
    }

    private func replaceAllMatches() {
        guard !findQuery.isEmpty else { return }
        let count = matchCount

        if isRegex {
            do {
                var regexOptions: NSRegularExpression.Options = []
                if !isCaseSensitive {
                    regexOptions.insert(.caseInsensitive)
                }
                let regex = try NSRegularExpression(pattern: findQuery, options: regexOptions)
                let nsStr = rawText as NSString
                let replaced = regex.stringByReplacingMatches(
                    in: rawText,
                    options: [],
                    range: NSRange(location: 0, length: nsStr.length),
                    withTemplate: replaceQuery
                )
                rawText = replaced
                onToast?("✓ Regex replaced all \(count) occurrences")
                recalculateMatches()
            } catch {
                regexErrorMessage = error.localizedDescription
            }
        } else {
            let options: String.CompareOptions = isCaseSensitive ? [] : [.caseInsensitive]
            rawText = rawText.replacingOccurrences(of: findQuery, with: replaceQuery, options: options)
            onToast?("✓ Replaced all \(count) occurrences")
            recalculateMatches()
        }
    }
}
