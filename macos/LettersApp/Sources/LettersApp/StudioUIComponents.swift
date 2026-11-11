import SwiftUI
import AppKit

// MARK: - Shared building blocks for the navigator (left) and inspector (right)
//
// Everything in the two sidebars is built from these few parts, so segmented controls, form
// sections, icon buttons and empty states look and behave the same on both sides of the page.

// MARK: Segmented control

struct StudioSegment<Tag: Hashable>: Identifiable {
    let tag: Tag
    let title: String
    var icon: String? = nil
    /// Small count pill shown after the title. Hidden when nil or zero.
    var badge: Int? = nil
    var help: String? = nil

    var id: Tag { tag }
}

/// A compact, icon-capable segmented control with a sliding selection pill and hover feedback.
/// `selected` is optional so the toolbar can show "no tab open"; re-clicking the selected segment
/// reports through `onReselect` (the toolbar uses that to collapse the inspector).
struct StudioSegmentedControl<Tag: Hashable>: View {
    let segments: [StudioSegment<Tag>]
    let selected: Tag?
    var height: CGFloat = 28
    var showsIcons: Bool = true
    let onSelect: (Tag) -> Void
    var onReselect: ((Tag) -> Void)? = nil

    @Namespace private var pill
    @State private var hovered: Tag? = nil

    var body: some View {
        HStack(spacing: 2) {
            ForEach(segments) { segment in
                segmentButton(segment)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func segmentButton(_ segment: StudioSegment<Tag>) -> some View {
        let isSelected = selected == segment.tag
        let isHovered = hovered == segment.tag

        return Button {
            if isSelected {
                onReselect?(segment.tag)
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { onSelect(segment.tag) }
            }
        } label: {
            HStack(spacing: 5) {
                if showsIcons, let icon = segment.icon {
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .semibold))
                }
                Text(segment.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let badge = segment.badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.10))
                        )
                }
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: height - 4)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.10), radius: 1.5, x: 0, y: 0.5)
                        .matchedGeometryEffect(id: "pill", in: pill)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(segment.help ?? segment.title)
        .accessibilityLabel(segment.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .onHover { inside in
            if inside { hovered = segment.tag } else if hovered == segment.tag { hovered = nil }
        }
    }
}

// MARK: Vibrancy

/// Real AppKit vibrancy for sidebars. Never takes part in hit-testing, so it can sit behind anything.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    final class PassthroughEffectView: NSVisualEffectView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = PassthroughEffectView()
        view.state = .followsWindowActiveState
        view.material = material
        view.blendingMode = blending
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

// MARK: Buttons

/// Quiet icon / row button: transparent until hovered, tinted when `isActive`, with a press state.
struct StudioHoverButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 6
    var isActive: Bool = false
    var tint: Color = .accentColor
    var restingFill: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration, cornerRadius: cornerRadius, isActive: isActive, tint: tint, restingFill: restingFill)
    }

    private struct HoverBody: View {
        let configuration: ButtonStyleConfiguration
        let cornerRadius: CGFloat
        let isActive: Bool
        let tint: Color
        let restingFill: Color
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fill)
                )
                .opacity(isEnabled ? 1 : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }

        private var fill: Color {
            if configuration.isPressed { return isActive ? tint.opacity(0.22) : Color.primary.opacity(0.12) }
            if isActive { return tint.opacity(hovering ? 0.18 : 0.12) }
            if hovering { return Color.primary.opacity(0.07) }
            return restingFill
        }
    }
}

/// Small filled action button used for "Accept", "Insert", "Restore" and similar.
struct StudioPillButtonStyle: ButtonStyle {
    var tint: Color = .accentColor
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, tint: tint, prominent: prominent)
    }

    private struct PillBody: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color
        let prominent: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(prominent ? .white : tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(prominent
                        ? tint.opacity(configuration.isPressed ? 0.75 : (hovering ? 0.92 : 1))
                        : tint.opacity(configuration.isPressed ? 0.26 : (hovering ? 0.20 : 0.13)))
                )
                .opacity(isEnabled ? 1 : 0.4)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}

// MARK: Form sections

/// A titled, rounded group of rows — the inspector's basic unit.
struct StudioFormSection<Content: View, Trailing: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer(minLength: 4)
                trailing()
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
        }
    }
}

extension StudioFormSection where Trailing == EmptyView {
    init(title: String, icon: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.trailing = { EmptyView() }
        self.content = content
    }
}

/// One labelled row inside a `StudioFormSection`.
struct StudioFormRow<Control: View>: View {
    let label: String
    var detail: String? = nil
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if let detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 6)
            control()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

/// Hairline between rows of a `StudioFormSection`.
struct StudioRowDivider: View {
    var body: some View {
        Divider().opacity(0.6).padding(.leading, 10)
    }
}

/// Menu-style value picker ("Letter ⌄") for a form row.
struct StudioMenuValue<Content: View>: View {
    let value: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }
}

// MARK: Empty state

struct StudioEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.secondary.opacity(0.55))
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
    }
}

// MARK: Relative time

@MainActor
enum StudioTimeFormat {
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func ago(_ date: Date, now: Date = Date()) -> String {
        if abs(now.timeIntervalSince(date)) < 45 { return "just now" }
        return relative.localizedString(for: date, relativeTo: now)
    }
}
