import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public enum HeaderFooterTarget: String, CaseIterable, Identifiable {
    case header = "Header"
    case footer = "Footer"

    public var id: String { rawValue }
}

public func resolveNSHeaderFont(fontFamily: String, size: CGFloat = 11.0, weight: NSFont.Weight = .regular) -> NSFont {
    switch fontFamily {
    case "SF Pro (Modern Sans)":
        return NSFont.systemFont(ofSize: size, weight: weight)
    case "New York (Editorial)":
        if weight == .bold {
            if let custom = NSFont(name: "NewYork-Bold", size: size) { return custom }
        }
        if let custom = NSFont(name: "NewYork-Regular", size: size) { return custom }
        return NSFont.systemFont(ofSize: size, weight: weight)
    case "SF Mono (Code)":
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    case "Default Serif (Georgia)":
        if weight == .bold {
            if let custom = NSFont(name: "Georgia-Bold", size: size) { return custom }
        }
        if let custom = NSFont(name: "Georgia", size: size) { return custom }
        return NSFont.systemFont(ofSize: size, weight: weight)
    default:
        if weight == .bold {
            if let custom = NSFont(name: "\(fontFamily)-Bold", size: size) { return custom }
        }
        if let custom = NSFont(name: fontFamily, size: size) { return custom }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }
}

public struct NativeFootnoteField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont
    var textColor: NSColor
    var isEditable: Bool
    var onCommit: (() -> Void)? = nil

    public init(
        text: Binding<String>,
        placeholder: String = "Footnote text…",
        font: NSFont,
        textColor: NSColor = .labelColor,
        isEditable: Bool = true,
        onCommit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.textColor = textColor
        self.isEditable = isEditable
        self.onCommit = onCommit
    }

    public func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBezeled = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.backgroundColor = .clear
        tf.focusRingType = .none
        tf.alignment = .left
        tf.font = font
        tf.textColor = textColor
        tf.isEditable = isEditable
        tf.isSelectable = true
        tf.delegate = context.coordinator
        tf.maximumNumberOfLines = 0
        tf.cell?.wraps = true
        tf.cell?.isScrollable = false
        tf.cell?.usesSingleLineMode = false
        tf.wantsLayer = true
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        tf.layer?.contentsScale = scale
        tf.layer?.rasterizationScale = scale
        tf.layer?.shouldRasterize = false
        if !placeholder.isEmpty {
            tf.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: NSColor.placeholderTextColor,
                    .font: font
                ]
            )
        }
        return tf
    }

    public func updateNSView(_ nsView: NSTextField, context: Context) {
        let scale = nsView.window?.backingScaleFactor ?? (NSScreen.main?.backingScaleFactor ?? 2.0)
        nsView.layer?.contentsScale = scale
        nsView.layer?.rasterizationScale = scale
        nsView.layer?.shouldRasterize = false
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = font
        nsView.textColor = textColor
        nsView.isEditable = isEditable
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeFootnoteField

        init(_ parent: NativeFootnoteField) {
            self.parent = parent
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        public func controlTextDidEndEditing(_ obj: Notification) {
            parent.onCommit?()
        }
    }
}
