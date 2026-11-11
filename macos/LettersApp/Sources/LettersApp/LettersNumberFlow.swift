import SwiftUI
import Combine

// MARK: - NumberFlow Animated Counter

/// A fluid, rolling digit text animation view for numeric stats.
/// Uses SwiftUI's `.contentTransition(.numericText())` with custom spring animation.
public struct NumberFlow: View {
    let value: Int
    let format: Format
    let animation: Animation
    let font: Font
    let weight: Font.Weight
    let foregroundColor: Color

    public enum Format {
        case plain
        case abbreviated  // 1.2K, 1.5M, etc.
        case withCommas
        case ordinal      // 1st, 2nd, 3rd
        case custom((Int) -> String)
    }

    @State private var displayedValue: Int = 0
    @State private var previousValue: Int = 0
    @State private var isAnimating: Bool = false

    public init(
        value: Int,
        format: Format = .withCommas,
        animation: Animation = .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0),
        font: Font = .system(size: 13, weight: .semibold, design: .rounded),
        weight: Font.Weight = .semibold,
        foregroundColor: Color = .primary
    ) {
        self.value = value
        self.format = format
        self.animation = animation
        self.font = font
        self.weight = weight
        self.foregroundColor = foregroundColor
        self._displayedValue = State(initialValue: value)
        self._previousValue = State(initialValue: value)
    }

    private var formattedValue: String {
        switch format {
        case .plain:
            return "\(displayedValue)"
        case .withCommas:
            return displayedValue.formatted(.number)
        case .abbreviated:
            return abbreviate(displayedValue)
        case .ordinal:
            return ordinal(displayedValue)
        case .custom(let formatter):
            return formatter(displayedValue)
        }
    }

    private func abbreviate(_ number: Int) -> String {
        let absNumber = abs(number)
        let sign = number < 0 ? "-" : ""
        switch absNumber {
        case 0..<1_000:
            return "\(sign)\(absNumber)"
        case 1_000..<1_000_000:
            return String(format: "%@%.1fK", sign, Double(absNumber) / 1_000)
        case 1_000_000..<1_000_000_000:
            return String(format: "%@%.1fM", sign, Double(absNumber) / 1_000_000)
        default:
            return String(format: "%@%.1fB", sign, Double(absNumber) / 1_000_000_000)
        }
    }

    private func ordinal(_ number: Int) -> String {
        let suffix: String
        let ones = number % 10
        let tens = (number / 10) % 10
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(number)\(suffix)"
    }

    public var body: some View {
        Text(formattedValue)
            .font(font.weight(weight))
            .foregroundColor(foregroundColor)
            .contentTransition(.numericText(countsDown: value < previousValue))
            .animation(animation, value: displayedValue)
            .onChange(of: value) { oldValue, newValue in
                previousValue = oldValue
                animateTo(newValue)
            }
            .onAppear {
                displayedValue = value
                previousValue = value
            }
    }

    private func animateTo(_ target: Int) {
        guard target != displayedValue else { return }
        isAnimating = true

        let difference = abs(target - displayedValue)
        let steps = min(max(difference / 10, 5), 30)
        let stepValue = max(1, difference / steps)
        let direction = target > displayedValue ? 1 : -1

        var current = displayedValue
        let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

        var cancellable: AnyCancellable?
        cancellable = timer.sink { _ in
            let next = current + (stepValue * direction)
            if (direction > 0 && next >= target) || (direction < 0 && next <= target) {
                displayedValue = target
                cancellable?.cancel()
                isAnimating = false
            } else {
                current = next
                displayedValue = current
            }
        }
    }
}

// MARK: - NumberFlow with Label (for status bar metrics)

public struct LabeledNumberFlow: View {
    let label: String
    let value: Int
    let icon: String
    let iconColor: Color
    let format: NumberFlow.Format
    let font: Font
    let showIcon: Bool

    @State private var isHovered: Bool = false

    public init(
        label: String,
        value: Int,
        icon: String = "doc.text",
        iconColor: Color = .accentColor,
        format: NumberFlow.Format = .withCommas,
        font: Font = .system(size: 11, weight: .semibold, design: .rounded),
        showIcon: Bool = true
    ) {
        self.label = label
        self.value = value
        self.icon = icon
        self.iconColor = iconColor
        self.format = format
        self.font = font
        self.showIcon = showIcon
    }

    public var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(iconColor)
                    .symbolEffect(.pulse, options: .repeating, value: isHovered)
            }

            NumberFlow(value: value, format: format, font: font, weight: .semibold)
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("\(label): \(value.formatted(.number))")
    }
}

// MARK: - Status Bar Metrics Collection

/// A collection of animated metrics for the bottom status bar.
/// Displays: Word Count, Page Count, Character Count, Reading Time
public struct StatusBarMetrics: View {
    let wordCount: Int
    let characterCount: Int
    let pageCount: Int
    let readingTimeMinutes: Int
    let citationStyle: String
    let styleProfile: String
    let zoomScale: Double

    @State private var isHovered: Bool = false

    private var readingTimeFormatted: String {
        if readingTimeMinutes < 1 {
            return "< 1 min"
        } else if readingTimeMinutes == 1 {
            return "1 min read"
        } else {
            return "\(readingTimeMinutes) min read"
        }
    }

    public init(
        wordCount: Int,
        characterCount: Int,
        pageCount: Int,
        readingTimeMinutes: Int,
        citationStyle: String = "None",
        styleProfile: String = "Standard",
        zoomScale: Double = 1.0
    ) {
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.pageCount = pageCount
        self.readingTimeMinutes = readingTimeMinutes
        self.citationStyle = citationStyle
        self.styleProfile = styleProfile
        self.zoomScale = zoomScale
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Word Count
            LabeledNumberFlow(
                label: wordCount == 1 ? "word" : "words",
                value: wordCount,
                icon: "doc.text",
                iconColor: .blue,
                format: .withCommas
            )

            Divider().frame(height: 14)

            // Page Count
            LabeledNumberFlow(
                label: pageCount == 1 ? "page" : "pages",
                value: pageCount,
                icon: "doc.on.doc",
                iconColor: .green,
                format: .plain
            )

            Divider().frame(height: 14)

            // Character Count
            LabeledNumberFlow(
                label: characterCount == 1 ? "character" : "characters",
                value: characterCount,
                icon: "character",
                iconColor: .orange,
                format: .withCommas
            )

            Divider().frame(height: 14)

            // Reading Time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple)

                NumberFlow(
                    value: readingTimeMinutes,
                    format: .plain,
                    font: .system(size: 11, weight: .semibold, design: .rounded)
                )
                .foregroundColor(.primary)

                Text("min read")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.purple.opacity(0.1) : Color.clear)
            )

            Divider().frame(height: 14)

            // Citation Style
            HStack(spacing: 4) {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(citationStyle == "None" ? .secondary : .accentColor)

                Text(citationStyle == "None" ? "Citations: Off" : citationStyle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            )

            Divider().frame(height: 14)

            // Style Profile
            HStack(spacing: 4) {
                Image(systemName: styleProfile == "Standard" ? "checkmark.shield" : "wand.and.stars")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(styleProfile == "Standard" ? .secondary : .orange)

                Text(styleProfile == "Standard" ? "Style: Standard" : styleProfile)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.orange.opacity(0.08) : Color.clear)
            )

            Divider().frame(height: 14)

            // Zoom
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                NumberFlow(
                    value: Int(zoomScale * 100),
                    format: .plain,
                    font: .system(size: 11, weight: .semibold, design: .rounded)
                )
                .foregroundColor(.primary)

                Text("%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.secondary.opacity(0.08) : Color.clear)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Compact Status Bar (for tight spaces)

public struct CompactStatusBarMetrics: View {
    let wordCount: Int
    let characterCount: Int
    let pageCount: Int
    let readingTimeMinutes: Int

    public var body: some View {
        HStack(spacing: 12) {
            MetricPill(icon: "doc.text", value: wordCount, label: wordCount == 1 ? "word" : "words", color: .blue, format: .withCommas)
            MetricPill(icon: "doc.on.doc", value: pageCount, label: pageCount == 1 ? "page" : "pages", color: .green, format: .plain)
            MetricPill(icon: "character", value: characterCount, label: characterCount == 1 ? "character" : "characters", color: .orange, format: .withCommas)
            MetricPill(icon: "clock", value: readingTimeMinutes, label: readingTimeMinutes == 1 ? "min" : "mins", color: .purple, format: .plain)
        }
    }
}

private struct MetricPill: View {
    let icon: String
    let value: Int
    let label: String
    let color: Color
    let format: NumberFlow.Format

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(color)

            NumberFlow(value: value, format: format, font: .system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }
}

// MARK: - Milestone Celebration Animation

/// A special animation for milestone achievements (e.g., 1000 words, 10 pages)
public struct MilestoneCelebration: View {
    let milestone: Milestone
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = -10

    public enum Milestone: Equatable {
        case words(Int)
        case pages(Int)
        case characters(Int)
        case custom(String, Int, Color, String) // label, value, color, icon

        var label: String {
            switch self {
            case .words(let count): return "\(count.formatted(.number)) Words!"
            case .pages(let count): return "\(count) Pages!"
            case .characters(let count): return "\(count.formatted(.number)) Characters!"
            case .custom(let label, _, _, _): return label
            }
        }

        var value: Int {
            switch self {
            case .words(let count): return count
            case .pages(let count): return count
            case .characters(let count): return count
            case .custom(_, let value, _, _): return value
            }
        }

        var color: Color {
            switch self {
            case .words: return .blue
            case .pages: return .green
            case .characters: return .orange
            case .custom(_, _, let color, _): return color
            }
        }

        var icon: String {
            switch self {
            case .words: return "doc.text.fill"
            case .pages: return "doc.on.doc.fill"
            case .characters: return "character.fill"
            case .custom(_, _, _, let icon): return icon
            }
        }
    }

    public init(milestone: Milestone, onDismiss: @escaping () -> Void) {
        self.milestone = milestone
        self.onDismiss = onDismiss
    }

    @State private var iconScale: CGFloat = 1.0

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: milestone.icon)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(milestone.color)
                .scaleEffect(iconScale)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5).repeatForever(autoreverses: true)) {
                        iconScale = 1.15
                    }
                }

            Text("Milestone Reached")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Text(milestone.label)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(milestone.color)
                .contentTransition(.numericText())

            Button("Continue Writing") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    scale = 0.5
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(milestone.color)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(milestone.color.opacity(0.3), lineWidth: 2)
                )
        )
        .shadow(color: milestone.color.opacity(0.2), radius: 24, x: 0, y: 12)
        .scaleEffect(scale)
        .opacity(opacity)
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
                rotation = 0
            }
        }
    }
}