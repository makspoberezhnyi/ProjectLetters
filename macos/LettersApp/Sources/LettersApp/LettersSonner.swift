import SwiftUI
import AppKit
import Combine

// MARK: - Toast Model

public struct Toast: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    public let kind: Kind
    public let duration: TimeInterval
    public let action: ToastAction?
    public let createdAt = Date()

    public enum Kind: Equatable {
        case info
        case success
        case warning
        case error
        case milestone(String)  // e.g., "1,000 words", "5 pages"
    }

    public struct ToastAction: Equatable {
        public let label: String
        public let action: () -> Void

        public static func == (lhs: ToastAction, rhs: ToastAction) -> Bool {
            lhs.label == rhs.label
        }
    }

    public init(
        message: String,
        kind: Kind = .info,
        duration: TimeInterval = 4.0,
        action: ToastAction? = nil
    ) {
        self.message = message
        self.kind = kind
        self.duration = duration
        self.action = action
    }

    // Convenience initializers
    public static func info(_ message: String, duration: TimeInterval = 4.0, action: ToastAction? = nil) -> Toast {
        Toast(message: message, kind: .info, duration: duration, action: action)
    }

    public static func success(_ message: String, duration: TimeInterval = 4.0, action: ToastAction? = nil) -> Toast {
        Toast(message: message, kind: .success, duration: duration, action: action)
    }

    public static func warning(_ message: String, duration: TimeInterval = 4.0, action: ToastAction? = nil) -> Toast {
        Toast(message: message, kind: .warning, duration: duration, action: action)
    }

    public static func error(_ message: String, duration: TimeInterval = 5.0, action: ToastAction? = nil) -> Toast {
        Toast(message: message, kind: .error, duration: duration, action: action)
    }

    public static func milestone(_ message: String, kind: Kind = .milestone(""), duration: TimeInterval = 5.0, action: ToastAction? = nil) -> Toast {
        Toast(message: message, kind: kind, duration: duration, action: action)
    }
}

// MARK: - Toast Manager (ObservableObject)

@MainActor
public final class ToastManager: ObservableObject {
    @Published public private(set) var toasts: [Toast] = []
    @Published public var isExpanded: Bool = false

    private var dismissTimers: [UUID: Timer] = [:]
    private let maxVisibleToasts = 5
    private let stackSpacing: CGFloat = 8
    private let stackScaleFactor: CGFloat = 0.95
    private let stackOffsetFactor: CGFloat = 12

    public init() {}

    // MARK: - Public API

    public func show(_ toast: Toast) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            toasts.insert(toast, at: 0)
            if toasts.count > maxVisibleToasts {
                toasts.removeLast()
            }
        }
        scheduleDismissal(for: toast)
    }

    public func dismiss(_ id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            toasts.removeAll { $0.id == id }
        }
        dismissTimers[id]?.invalidate()
        dismissTimers.removeValue(forKey: id)
    }

    public func dismissAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            toasts.removeAll()
        }
        dismissTimers.values.forEach { $0.invalidate() }
        dismissTimers.removeAll()
    }

    public func toggleExpanded() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
    }

    // MARK: - Internal

    private func scheduleDismissal(for toast: Toast) {
        let id = toast.id
        let duration = toast.duration
        let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss(id)
            }
        }
        dismissTimers[id] = timer
    }

    // MARK: - Stack Geometry

    /// Returns the scale for a toast at the given index (0 = topmost/newest)
    public func scaleForIndex(_ index: Int) -> CGFloat {
        guard index < toasts.count else { return 1.0 }
        if isExpanded { return 1.0 }
        return pow(stackScaleFactor, CGFloat(index))
    }

    /// Returns the vertical offset for a toast at the given index
    public func offsetForIndex(_ index: Int) -> CGFloat {
        guard index < toasts.count else { return 0 }
        if isExpanded { return CGFloat(index) * 56 }
        return CGFloat(index) * stackOffsetFactor
    }

    /// Returns the z-index for proper layering
    public func zIndexForIndex(_ index: Int) -> Double {
        Double(toasts.count - index)
    }

    /// Returns opacity for a toast at the given index
    public func opacityForIndex(_ index: Int) -> CGFloat {
        guard index < toasts.count else { return 0 }
        if isExpanded { return 1.0 }
        return max(0.3, 1.0 - CGFloat(index) * 0.15)
    }
}

// MARK: - Toast View

public struct ToastView: View {
    let toast: Toast
    let index: Int
    let manager: ToastManager
    let onDismiss: () -> Void
    let onHover: (Bool) -> Void

    @State private var isHovered: Bool = false
    @State private var dragOffset: CGSize = .zero

    private var backgroundColor: Color {
        switch toast.kind {
        case .info: return Color.blue.opacity(0.12)
        case .success: return Color.green.opacity(0.12)
        case .warning: return Color.orange.opacity(0.12)
        case .error: return Color.red.opacity(0.12)
        case .milestone: return Color.purple.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch toast.kind {
        case .info: return Color.blue.opacity(0.3)
        case .success: return Color.green.opacity(0.3)
        case .warning: return Color.orange.opacity(0.3)
        case .error: return Color.red.opacity(0.3)
        case .milestone: return Color.purple.opacity(0.3)
        }
    }

    private var iconName: String {
        switch toast.kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .milestone: return "star.circle.fill"
        }
    }

    private var iconColor: Color {
        switch toast.kind {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .milestone: return .purple
        }
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .symbolEffect(.bounce, value: index == 0 && !isHovered)

            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let action = toast.action {
                Button(action.label) {
                    action.action()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(iconColor)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || manager.isExpanded ? 1 : 0.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .scaleEffect(manager.scaleForIndex(index))
        .offset(y: manager.offsetForIndex(index) + dragOffset.height)
        .opacity(manager.opacityForIndex(index))
        .zIndex(manager.zIndexForIndex(index))
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: manager.isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: index)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
            onHover(hovering)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = CGSize(width: value.translation.width, height: 0)
                    }
                }
                .onEnded { value in
                    if abs(value.translation.width) > 80 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .contextMenu {
            if let action = toast.action {
                Button(action.label) {
                    action.action()
                    onDismiss()
                }
            }
            Button("Dismiss", role: .destructive) {
                onDismiss()
            }
        }
    }
}

// MARK: - Toast Stack View

public struct ToastStackView: View {
    @ObservedObject var manager: ToastManager
    let position: Position

    public enum Position {
        case bottomTrailing
        case bottomCenter
        case topTrailing
        case topCenter
    }

    private var alignment: Alignment {
        switch position {
        case .bottomTrailing, .topTrailing: return .trailing
        case .bottomCenter, .topCenter: return .center
        }
    }

    private var stackAlignment: VerticalAlignment {
        switch position {
        case .bottomTrailing, .bottomCenter: return .bottom
        case .topTrailing, .topCenter: return .top
        }
    }

    public var body: some View {
        if manager.toasts.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: alignment.horizontal, spacing: 8) {
                ForEach(Array(manager.toasts.enumerated()), id: \.element.id) { index, toast in
                    ToastView(
                        toast: toast,
                        index: index,
                        manager: manager,
                        onDismiss: { manager.dismiss(toast.id) },
                        onHover: { hovering in
                            if hovering {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    manager.isExpanded = true
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .onHover { hovering in
                if !hovering && manager.isExpanded {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        manager.isExpanded = false
                    }
                }
            }
        }
    }
}

// MARK: - Global Toast Overlay (for app-wide usage)

public struct ToastOverlay: View {
    @ObservedObject var manager: ToastManager
    let position: ToastStackView.Position

    public init(manager: ToastManager, position: ToastStackView.Position = .bottomTrailing) {
        self.manager = manager
        self.position = position
    }

    public var body: some View {
        ToastStackView(manager: manager, position: position)
            .environmentObject(manager)
    }
}

// MARK: - Environment Key for Toast Manager

private struct ToastManagerKey: EnvironmentKey {
    nonisolated(unsafe) static var defaultValue: ToastManager = {
        // This will be initialized on first access from the main actor
        // Since ToastManager is @MainActor, we need to ensure we're on the main actor
        // For EnvironmentKey, we use a nonisolated(unsafe) workaround
        MainActor.assumeIsolated {
            ToastManager()
        }
    }()
}

public extension EnvironmentValues {
    var toastManager: ToastManager {
        get { self[ToastManagerKey.self] }
        set { self[ToastManagerKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Toast Presentation

public extension View {
    func withToasts(_ manager: ToastManager, position: ToastStackView.Position = .bottomTrailing) -> some View {
        overlay(alignment: position == .bottomTrailing || position == .bottomCenter ? .bottomTrailing : .topTrailing) {
            ToastOverlay(manager: manager, position: position)
        }
    }

    func toastManager(_ manager: ToastManager) -> some View {
        environmentObject(manager)
    }
}

// MARK: - Convenience Functions for DocumentController Integration

public extension ToastManager {
    func showSaveSuccess() {
        show(.success("Document saved", duration: 3.0))
    }

    func showSaveFailed(_ error: Error) {
        show(.error("Save failed: \(error.localizedDescription)", duration: 5.0))
    }

    func showWordCountMilestone(_ count: Int) {
        let formatted = count.formatted(.number)
        show(.milestone("🎉 \(formatted) words written!", kind: .milestone("\(formatted) words"), duration: 5.0))
    }

    func showPageCountMilestone(_ count: Int) {
        show(.milestone("📄 \(count) pages completed!", kind: .milestone("\(count) pages"), duration: 5.0))
    }

    func showFormatApplied(_ format: String) {
        show(.info("✨ \(format) applied", duration: 3.0))
    }

    func showExportCompleted(_ format: String) {
        show(.success("📤 Exported as \(format)", duration: 4.0))
    }

    func showImportCompleted(_ format: String) {
        show(.success("📥 Imported from \(format)", duration: 4.0))
    }

    func showAIActionCompleted(_ action: String) {
        show(.success("🤖 \(action) completed", duration: 4.0))
    }

    func showCitationStyleChanged(_ style: String) {
        show(.info("📚 Citation style: \(style)", duration: 3.0))
    }

    func showStyleProfileChanged(_ profile: String) {
        show(.info("✏️ Style profile: \(profile)", duration: 3.0))
    }

    func showUndoAvailable(action: @escaping () -> Void) {
        show(.info("↩️ Undo available", duration: 5.0, action: .init(label: "Undo", action: action)))
    }
}