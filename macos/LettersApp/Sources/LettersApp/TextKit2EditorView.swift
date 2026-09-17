import SwiftUI
import AppKit
import Foundation
#if canImport(LettersKit)
import LettersKit
#endif

@MainActor
public class EditorActionController: ObservableObject {
    public weak var textView: NSTextView?

    public init() {}

    public func toggleBold() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard let textStorage = textView.textStorage else { return }

        if range.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
                let isBold = NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)
                let newFont = isBold
                    ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
                    : NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
            textStorage.endEditing()
            textView.didChangeText()
        } else {
            var attrs = textView.typingAttributes
            let currentFont = (attrs[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 15)
            let isBold = NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)
            let newFont = isBold
                ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
            attrs[.font] = newFont
            textView.typingAttributes = attrs
        }
    }

    public func toggleItalic() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard let textStorage = textView.textStorage else { return }

        if range.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
                let isItalic = NSFontManager.shared.traits(of: currentFont).contains(.italicFontMask)
                let newFont = isItalic
                    ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask)
                    : NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
            textStorage.endEditing()
            textView.didChangeText()
        } else {
            var attrs = textView.typingAttributes
            let currentFont = (attrs[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 15)
            let isItalic = NSFontManager.shared.traits(of: currentFont).contains(.italicFontMask)
            let newFont = isItalic
                ? NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask)
                : NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
            attrs[.font] = newFont
            textView.typingAttributes = attrs
        }
    }

    public func toggleUnderline() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard let textStorage = textView.textStorage else { return }

        if range.length > 0 {
            textStorage.beginEditing()
            var hasUnderline = false
            textStorage.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
                if let val = value as? Int, val != 0 {
                    hasUnderline = true
                    stop.pointee = true
                }
            }
            if hasUnderline {
                textStorage.removeAttribute(.underlineStyle, range: range)
            } else {
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            textStorage.endEditing()
            textView.didChangeText()
        } else {
            var attrs = textView.typingAttributes
            let isUnderlined = ((attrs[.underlineStyle] as? Int) ?? 0) != 0
            attrs[.underlineStyle] = isUnderlined ? nil : NSUnderlineStyle.single.rawValue
            textView.typingAttributes = attrs
        }
    }

    public func applyFontFamily(_ family: String, size: CGFloat) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let targetRange = range.length > 0 ? range : NSRange(location: 0, length: textStorage.length)
        if targetRange.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: targetRange, options: []) { value, subRange, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: size)
                let isBold = NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)
                let isItalic = NSFontManager.shared.traits(of: currentFont).contains(.italicFontMask)
                let newFont = resolveFontNamed(family: family, size: currentFont.pointSize > 0 ? currentFont.pointSize : size, bold: isBold, italic: isItalic)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
            textStorage.endEditing()
            textView.didChangeText()
        }
    }

    public func applyFontSize(_ size: CGFloat) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let targetRange = range.length > 0 ? range : NSRange(location: 0, length: textStorage.length)
        if targetRange.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: targetRange, options: []) { value, subRange, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: size)
                let newFont = NSFontManager.shared.convert(currentFont, toSize: size)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
            textStorage.endEditing()
            textView.didChangeText()
        }
    }

    public func applyAlignment(_ alignment: TextAlignment, lineSpacing: CGFloat, paragraphSpacing: CGFloat) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let style = NSMutableParagraphStyle()
        switch alignment {
        case .leading: style.alignment = .left
        case .center: style.alignment = .center
        case .trailing: style.alignment = .right
        }
        style.lineHeightMultiple = lineSpacing
        style.paragraphSpacing = paragraphSpacing

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        textStorage.addAttribute(.paragraphStyle, value: style, range: fullRange)
        textStorage.endEditing()
        textView.defaultParagraphStyle = style
        textView.didChangeText()
    }
}

public func resolveFontNamed(family: String, size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
    var baseName = "Georgia"
    if family.contains("SF Pro") || family.contains("Modern Sans") {
        let weight: NSFont.Weight = bold ? .bold : .regular
        let systemFont = NSFont.systemFont(ofSize: size, weight: weight)
        if italic {
            let descriptor = systemFont.fontDescriptor.withSymbolicTraits(.italic)
            return NSFont(descriptor: descriptor, size: size) ?? systemFont
        }
        return systemFont
    } else if family.contains("Times New Roman") {
        baseName = bold ? (italic ? "TimesNewRomanPS-BoldItalicMT" : "TimesNewRomanPS-BoldMT") : (italic ? "TimesNewRomanPS-ItalicMT" : "TimesNewRomanPSMT")
        if let custom = NSFont(name: baseName, size: size) { return custom }
    } else if family.contains("Helvetica Neue") {
        baseName = bold ? (italic ? "HelveticaNeue-BoldItalic" : "HelveticaNeue-Bold") : (italic ? "HelveticaNeue-Italic" : "HelveticaNeue")
        if let custom = NSFont(name: baseName, size: size) { return custom }
    } else if family.contains("Courier") {
        baseName = bold ? (italic ? "Courier-BoldOblique" : "Courier-Bold") : (italic ? "Courier-Oblique" : "Courier")
        if let custom = NSFont(name: baseName, size: size) { return custom }
    } else if family.contains("Charter") {
        baseName = bold ? (italic ? "Charter-BoldItalic" : "Charter-Bold") : (italic ? "Charter-Italic" : "Charter-Roman")
        if let custom = NSFont(name: baseName, size: size) { return custom }
    } else {
        baseName = bold ? (italic ? "Georgia-BoldItalic" : "Georgia-Bold") : (italic ? "Georgia-Italic" : "Georgia")
        if let custom = NSFont(name: baseName, size: size) { return custom }
    }

    return NSFont(name: baseName, size: size) ?? NSFont.systemFont(ofSize: size)
}

public struct TextKit2EditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedText: String
    @Binding var selectionRange: NSRange
    var controller: EditorActionController?
    var fontFamily: String
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var alignment: TextAlignment
    var lineSpacing: CGFloat
    var paragraphSpacing: CGFloat
    var margins: PageMargins
    var onSelectionChanged: ((NSRange, String) -> Void)?

    public init(
        text: Binding<String>,
        selectedText: Binding<String>,
        selectionRange: Binding<NSRange>,
        controller: EditorActionController? = nil,
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        alignment: TextAlignment = .leading,
        lineSpacing: CGFloat = 1.15,
        paragraphSpacing: CGFloat = 12.0,
        margins: PageMargins = PageMargins(),
        onSelectionChanged: ((NSRange, String) -> Void)? = nil
    ) {
        self._text = text
        self._selectedText = selectedText
        self._selectionRange = selectionRange
        self.controller = controller
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.margins = margins
        self.onSelectionChanged = onSelectionChanged
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true

        let font = resolveFontNamed(family: fontFamily, size: fontSize, bold: isBold, italic: isItalic)
        let paragraphStyle = NSMutableParagraphStyle()
        switch alignment {
        case .leading: paragraphStyle.alignment = .left
        case .center: paragraphStyle.alignment = .center
        case .trailing: paragraphStyle.alignment = .right
        }
        paragraphStyle.lineHeightMultiple = lineSpacing
        paragraphStyle.paragraphSpacing = paragraphSpacing

        let textColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = NSColor.systemBlue
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.defaultParagraphStyle = paragraphStyle

        let typingAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        textView.typingAttributes = typingAttrs

        // Dynamic Document Page Insets
        textView.textContainerInset = NSSize(width: margins.left, height: margins.top)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        if let layoutManager = textView.layoutManager {
            layoutManager.allowsNonContiguousLayout = true
        }

        context.coordinator.isInitializing = true
        textView.string = text
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        controller?.textView = textView
        scrollView.documentView = textView

        DispatchQueue.main.async {
            context.coordinator.isInitializing = false
        }

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        controller?.textView = textView

        // Update margins if changed
        let targetInset = NSSize(width: margins.left, height: margins.top)
        if textView.textContainerInset != targetInset {
            textView.textContainerInset = targetInset
        }

        // Update text if changed externally
        if textView.string != text && !context.coordinator.isInitializing {
            context.coordinator.isInitializing = true
            let selected = textView.selectedRange()
            textView.string = text
            if selected.location + selected.length <= (text as NSString).length {
                textView.setSelectedRange(selected)
            }
            DispatchQueue.main.async {
                context.coordinator.isInitializing = false
            }
        }
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextKit2EditorView
        weak var textView: NSTextView?
        var isInitializing = false

        init(_ parent: TextKit2EditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isInitializing else { return }
            let string = textView.string
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.parent.text != string {
                    self.parent.text = string
                }
            }
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isInitializing else { return }
            let range = textView.selectedRange()
            let nsString = textView.string as NSString
            let sub = range.length > 0 && range.location + range.length <= nsString.length ? nsString.substring(with: range) : ""

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.parent.selectionRange != range {
                    self.parent.selectionRange = range
                }
                if self.parent.selectedText != sub {
                    self.parent.selectedText = sub
                }
                self.parent.onSelectionChanged?(range, sub)
            }
        }
    }
}

