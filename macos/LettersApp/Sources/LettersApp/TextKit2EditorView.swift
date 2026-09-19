import SwiftUI
import AppKit
import Foundation
#if canImport(LettersKit)
import LettersKit
#endif

public struct EditorSelectionAttributes: Equatable {
    public var fontFamily: String
    public var fontSize: CGFloat
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var alignment: TextAlignment

    public init(
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        alignment: TextAlignment = .leading
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.alignment = alignment
    }
}

@MainActor
public class EditorActionController: ObservableObject {
    public weak var textView: NSTextView?
    private var pageViews: [Int: StudioTextView] = [:]

    public init() {}

    public func register(pageIndex: Int, textView: StudioTextView) {
        pageViews[pageIndex] = textView
    }

    public func hasPage(_ pageIndex: Int) -> Bool {
        return pageViews[pageIndex] != nil
    }

    public func focusPage(_ pageIndex: Int, at cursorLoc: Int = 0, retries: Int = 8) {
        DispatchQueue.main.async {
            if let tv = self.pageViews[pageIndex] {
                tv.window?.makeFirstResponder(tv)
                self.textView = tv
                let length = (tv.string as NSString).length
                let safeLoc = max(0, min(cursorLoc, length))
                tv.setSelectedRange(NSRange(location: safeLoc, length: 0))
            } else if retries > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                    self.focusPage(pageIndex, at: cursorLoc, retries: retries - 1)
                }
            }
        }
    }

    public func focusPreviousPage(from pageIndex: Int, deleteTrailing: Bool = false) {
        let prevPage = pageIndex - 1
        guard prevPage >= 0 else { return }
        DispatchQueue.main.async {
            guard let prevTv = self.pageViews[prevPage] else { return }
            prevTv.window?.makeFirstResponder(prevTv)
            self.textView = prevTv
            let len = (prevTv.string as NSString).length
            if deleteTrailing && len > 0 {
                prevTv.setSelectedRange(NSRange(location: len, length: 0))
                prevTv.deleteBackward(nil)
            } else {
                prevTv.setSelectedRange(NSRange(location: len, length: 0))
            }
        }
    }

    public func focusNextPage(from pageIndex: Int) {
        let nextPage = pageIndex + 1
        DispatchQueue.main.async {
            guard let nextTv = self.pageViews[nextPage] else { return }
            nextTv.window?.makeFirstResponder(nextTv)
            self.textView = nextTv
            nextTv.setSelectedRange(NSRange(location: 0, length: 0))
        }
    }

    public func currentSelectionAttributes() -> EditorSelectionAttributes? {
        guard let textView = textView else { return nil }
        let range = textView.selectedRange()
        var font: NSFont? = nil
        var isUnderlined = false
        var align: TextAlignment = .leading

        if let textStorage = textView.textStorage, textStorage.length > 0 {
            let loc: Int
            if range.length > 0 {
                loc = range.location
            } else {
                loc = max(0, min(range.location, textStorage.length - 1))
            }
            if loc < textStorage.length {
                let attrs = textStorage.attributes(at: loc, effectiveRange: nil)
                font = attrs[.font] as? NSFont
                if let u = attrs[.underlineStyle] as? Int, u != 0 {
                    isUnderlined = true
                }
                if let p = attrs[.paragraphStyle] as? NSParagraphStyle {
                    switch p.alignment {
                    case .center: align = .center
                    case .right: align = .trailing
                    default: align = .leading
                    }
                }
            }
        }

        if font == nil {
            font = (textView.typingAttributes[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 15)
            if let u = textView.typingAttributes[.underlineStyle] as? Int, u != 0 {
                isUnderlined = true
            }
            if let p = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle {
                switch p.alignment {
                case .center: align = .center
                case .right: align = .trailing
                default: align = .leading
                }
            }
        }

        let validFont = font ?? NSFont.systemFont(ofSize: 15)
        let traits = NSFontManager.shared.traits(of: validFont)
        let bold = traits.contains(.boldFontMask)
        let italic = traits.contains(.italicFontMask)
        let fam = fontDisplayName(for: validFont)

        return EditorSelectionAttributes(
            fontFamily: fam,
            fontSize: validFont.pointSize > 0 ? validFont.pointSize : 15.0,
            isBold: bold,
            isItalic: italic,
            isUnderline: isUnderlined,
            alignment: align
        )
    }

    public func toggleBold() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard let textStorage = textView.textStorage else { return }

        if range.length > 0 {
            textStorage.beginEditing()
            var allBold = true
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
                let isBold = NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)
                if !isBold {
                    allBold = false
                    stop.pointee = true
                }
            }
            let targetTraitBold = !allBold

            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
                let newFont = targetTraitBold
                    ? NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                    : NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
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
            var allItalic = true
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
                let isItalic = NSFontManager.shared.traits(of: currentFont).contains(.italicFontMask)
                if !isItalic {
                    allItalic = false
                    stop.pointee = true
                }
            }
            let targetTraitItalic = !allItalic

            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: 15)
                let newFont = targetTraitItalic
                    ? NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                    : NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask)
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
            var allUnderlined = true
            textStorage.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
                let isUnderlined = ((value as? Int) ?? 0) != 0
                if !isUnderlined {
                    allUnderlined = false
                    stop.pointee = true
                }
            }
            if allUnderlined {
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
        if range.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: size)
                let isBold = NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)
                let isItalic = NSFontManager.shared.traits(of: currentFont).contains(.italicFontMask)
                let ptSize = currentFont.pointSize > 0 ? currentFont.pointSize : size
                let newFont = resolveFontNamed(family: family, size: ptSize, bold: isBold, italic: isItalic)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
            textStorage.endEditing()
            textView.didChangeText()
        } else {
            var attrs = textView.typingAttributes
            let currentFont = (attrs[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: size)
            let isBold = NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)
            let isItalic = NSFontManager.shared.traits(of: currentFont).contains(.italicFontMask)
            let ptSize = currentFont.pointSize > 0 ? currentFont.pointSize : size
            let newFont = resolveFontNamed(family: family, size: ptSize, bold: isBold, italic: isItalic)
            attrs[.font] = newFont
            textView.typingAttributes = attrs
        }
    }

    public func applyFontSize(_ size: CGFloat) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        if range.length > 0 {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: size)
                let newFont = NSFontManager.shared.convert(currentFont, toSize: size)
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
            textStorage.endEditing()
            textView.didChangeText()
        } else {
            var attrs = textView.typingAttributes
            let currentFont = (attrs[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: size)
            let newFont = NSFontManager.shared.convert(currentFont, toSize: size)
            attrs[.font] = newFont
            textView.typingAttributes = attrs
        }
    }

    public func toggleStrikethrough() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard let textStorage = textView.textStorage else { return }

        if range.length > 0 {
            textStorage.beginEditing()
            var allStrikethrough = true
            textStorage.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, _, stop in
                let isStruck = ((value as? Int) ?? 0) != 0
                if !isStruck {
                    allStrikethrough = false
                    stop.pointee = true
                }
            }
            if allStrikethrough {
                textStorage.removeAttribute(.strikethroughStyle, range: range)
            } else {
                textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            textStorage.endEditing()
            textView.didChangeText()
        } else {
            var attrs = textView.typingAttributes
            let isStruck = ((attrs[.strikethroughStyle] as? Int) ?? 0) != 0
            attrs[.strikethroughStyle] = isStruck ? nil : NSUnderlineStyle.single.rawValue
            textView.typingAttributes = attrs
        }
    }

    public func applyAlignment(_ alignment: TextAlignment, lineSpacing: CGFloat, paragraphSpacing: CGFloat) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let nsString = textStorage.string as NSString
        guard nsString.length > 0 else { return }

        let range = textView.selectedRange()
        let targetRange: NSRange
        if range.length > 0 {
            targetRange = nsString.paragraphRange(for: range)
        } else {
            let safeLoc = min(max(0, range.location), max(0, nsString.length - 1))
            targetRange = nsString.paragraphRange(for: NSRange(location: safeLoc, length: 0))
        }

        let existingStyle = (textStorage.attribute(.paragraphStyle, at: max(0, targetRange.location), effectiveRange: nil) as? NSParagraphStyle)
        let style = (existingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        switch alignment {
        case .leading: style.alignment = .left
        case .center: style.alignment = .center
        case .trailing: style.alignment = .right
        }
        style.lineHeightMultiple = lineSpacing
        style.paragraphSpacing = paragraphSpacing

        textStorage.beginEditing()
        textStorage.addAttribute(.paragraphStyle, value: style, range: targetRange)
        textStorage.endEditing()

        var attrs = textView.typingAttributes
        attrs[.paragraphStyle] = style
        textView.typingAttributes = attrs

        textView.didChangeText()
    }

    public func applyLineSpacing(_ lineSpacing: CGFloat, paragraphSpacing: CGFloat) {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let nsString = textStorage.string as NSString
        guard nsString.length > 0 else { return }

        let range = textView.selectedRange()
        let targetRange: NSRange
        if range.length > 0 {
            targetRange = nsString.paragraphRange(for: range)
        } else {
            let safeLoc = min(max(0, range.location), max(0, nsString.length - 1))
            targetRange = nsString.paragraphRange(for: NSRange(location: safeLoc, length: 0))
        }

        let existingStyle = (textStorage.attribute(.paragraphStyle, at: max(0, targetRange.location), effectiveRange: nil) as? NSParagraphStyle)
        let style = (existingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        style.lineHeightMultiple = lineSpacing
        style.paragraphSpacing = paragraphSpacing

        textStorage.beginEditing()
        textStorage.addAttribute(.paragraphStyle, value: style, range: targetRange)
        textStorage.endEditing()

        var attrs = textView.typingAttributes
        attrs[.paragraphStyle] = style
        textView.typingAttributes = attrs

        textView.didChangeText()
    }
}

public func fontDisplayName(for font: NSFont) -> String {
    let name = font.fontName.lowercased()
    let familyName = font.familyName?.lowercased() ?? ""
    if name.contains("georgia") || familyName.contains("georgia") {
        return "Default Serif (Georgia)"
    } else if name.contains("times") || familyName.contains("times") {
        return "Times New Roman"
    } else if name.contains("helvetica") || familyName.contains("helvetica") {
        return "Helvetica"
    } else if name.contains("menlo") || familyName.contains("menlo") {
        return "Menlo (Monospace)"
    } else if name.contains("courier") || familyName.contains("courier") {
        return "Courier"
    } else if name.contains("charter") || familyName.contains("charter") {
        return "Charter"
    } else if name.contains("system") || name.contains("sfpro") || familyName.contains("sf pro") || familyName.contains("system") {
        return "SF Pro"
    }
    return font.familyName ?? "Default Serif (Georgia)"
}

public func resolveFontNamed(family: String, size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
    EditorPerformanceCache.shared.resolveFont(family: family, size: size, bold: bold, italic: italic)
}

public class StudioTextView: NSTextView {
    public weak var actionController: EditorActionController?
    public var pageIndex: Int = 0

    public override var isFlipped: Bool { true }



    public override func scrollRangeToVisible(_ range: NSRange) {
        // In physical page canvas mode, bounds origin must stay strictly (0, 0)
        self.bounds.origin = .zero
    }

    public override func scroll(_ point: NSPoint) {
        // Pin bounds origin to zero to prevent text from scrolling off the top of the sheet
        self.bounds.origin = .zero
    }

    public override func autoscroll(with event: NSEvent) -> Bool {
        self.bounds.origin = .zero
        return false
    }

    public override func scrollWheel(with event: NSEvent) {
        // Forward scrollWheel to canvas scroll view so text never scrolls inside physical paper
        self.nextResponder?.scrollWheel(with: event)
    }

    public override func layout() {
        super.layout()
        if self.bounds.origin != .zero {
            self.bounds.origin = .zero
        }
    }

    public override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok {
            actionController?.textView = self
        }
        return ok
    }

    public override func mouseDown(with event: NSEvent) {
        actionController?.textView = self
        super.mouseDown(with: event)
    }

    public override func keyDown(with event: NSEvent) {
        actionController?.textView = self
        // Command + Return = Insert Page Break
        if event.modifierFlags.contains(.command) && (event.keyCode == 36 || event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\n") {
            self.insertText("\n\n---pagebreak---\n\n", replacementRange: self.selectedRange())
            return
        }

        let sel = self.selectedRange()
        let strLen = (self.string as NSString).length

        // Backspace at beginning of page -> hop to end of previous page & delete
        if event.keyCode == 51 && sel.location == 0 && sel.length == 0 && pageIndex > 0 {
            actionController?.focusPreviousPage(from: pageIndex, deleteTrailing: true)
            return
        }

        // Left arrow at beginning of page -> hop to end of previous page
        if event.keyCode == 123 && sel.location == 0 && sel.length == 0 && pageIndex > 0 {
            actionController?.focusPreviousPage(from: pageIndex, deleteTrailing: false)
            return
        }

        // Right arrow at end of page -> hop to beginning of next page
        if event.keyCode == 124 && sel.location == strLen && sel.length == 0 {
            if let ac = actionController, ac.hasPage(pageIndex + 1) {
                ac.focusNextPage(from: pageIndex)
                return
            }
        }

        super.keyDown(with: event)
    }
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
    var pageIndex: Int
    var onSelectionChanged: ((NSRange, String, EditorSelectionAttributes) -> Void)?

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
        pageIndex: Int = 0,
        onSelectionChanged: ((NSRange, String, EditorSelectionAttributes) -> Void)? = nil
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
        self.pageIndex = pageIndex
        self.onSelectionChanged = onSelectionChanged
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> StudioTextView {
        let textView = StudioTextView()
        textView.actionController = controller
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isSelectable = true
        textView.isEditable = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.focusRingType = .none

        if #available(macOS 15.0, *) {
            textView.writingToolsBehavior = .complete
        }

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
        textView.defaultParagraphStyle = paragraphStyle

        let typingAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        textView.typingAttributes = typingAttrs

        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 4.0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.autoresizingMask = [.width, .height]

        if let layoutManager = textView.layoutManager {
            layoutManager.allowsNonContiguousLayout = true
        }

        context.coordinator.isUpdatingProgrammatically = true
        textView.string = text
        if let storage = textView.textStorage {
            Self.applyTypographyStyling(
                to: storage,
                fontFamily: fontFamily,
                baseFontSize: fontSize,
                isBold: isBold,
                isItalic: isItalic,
                alignment: alignment,
                lineSpacing: lineSpacing,
                paragraphSpacing: paragraphSpacing
            )
        }
        textView.pageIndex = pageIndex
        textView.actionController = controller
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.lastAppliedFontFamily = fontFamily
        context.coordinator.lastAppliedFontSize = fontSize
        context.coordinator.lastAppliedLineSpacing = lineSpacing
        context.coordinator.lastAppliedParagraphSpacing = paragraphSpacing
        context.coordinator.lastAppliedAlignment = alignment
        controller?.textView = textView
        controller?.register(pageIndex: pageIndex, textView: textView)
        context.coordinator.isUpdatingProgrammatically = false

        return textView
    }

    public func updateNSView(_ textView: StudioTextView, context: Context) {
        context.coordinator.parent = self
        textView.pageIndex = pageIndex
        textView.actionController = controller
        controller?.register(pageIndex: pageIndex, textView: textView)
        if context.coordinator.textView == nil {
            context.coordinator.textView = textView
        }

        let typographyChanged = context.coordinator.lastAppliedFontFamily != fontFamily ||
            context.coordinator.lastAppliedFontSize != fontSize ||
            context.coordinator.lastAppliedLineSpacing != lineSpacing ||
            context.coordinator.lastAppliedParagraphSpacing != paragraphSpacing ||
            context.coordinator.lastAppliedAlignment != alignment

        // Only update text when changed externally from SwiftUI/File loading or when typography settings changed
        if textView.string != text || typographyChanged {
            context.coordinator.isUpdatingProgrammatically = true
            let selected = textView.selectedRange()
            if textView.string != text {
                textView.string = text
            }
            if let storage = textView.textStorage {
                Self.applyTypographyStyling(
                    to: storage,
                    fontFamily: fontFamily,
                    baseFontSize: fontSize,
                    isBold: isBold,
                    isItalic: isItalic,
                    alignment: alignment,
                    lineSpacing: lineSpacing,
                    paragraphSpacing: paragraphSpacing
                )
            }
            if selected.location + selected.length <= (textView.string as NSString).length {
                textView.setSelectedRange(selected)
            }
            context.coordinator.lastAppliedFontFamily = fontFamily
            context.coordinator.lastAppliedFontSize = fontSize
            context.coordinator.lastAppliedLineSpacing = lineSpacing
            context.coordinator.lastAppliedParagraphSpacing = paragraphSpacing
            context.coordinator.lastAppliedAlignment = alignment
            context.coordinator.isUpdatingProgrammatically = false
        }
    }

    public static func applyTypographyStyling(
        to textStorage: NSTextStorage,
        fontFamily: String,
        baseFontSize: CGFloat,
        isBold: Bool = false,
        isItalic: Bool = false,
        alignment: TextAlignment,
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat
    ) {
        let string = textStorage.string
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        guard fullRange.length > 0 else { return }

        let baseFont = resolveFontNamed(family: fontFamily, size: baseFontSize, bold: isBold, italic: isItalic)
        let baseParagraphStyle = NSMutableParagraphStyle()
        switch alignment {
        case .leading: baseParagraphStyle.alignment = .left
        case .center: baseParagraphStyle.alignment = .center
        case .trailing: baseParagraphStyle.alignment = .right
        }
        baseParagraphStyle.lineHeightMultiple = lineSpacing
        baseParagraphStyle.paragraphSpacing = paragraphSpacing

        let baseTextColor = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)

        textStorage.beginEditing()
        textStorage.setAttributes([
            .font: baseFont,
            .foregroundColor: baseTextColor,
            .paragraphStyle: baseParagraphStyle
        ], range: fullRange)

        // 1. Heading 1: ^# (.*)$
        if let h1Regex = try? NSRegularExpression(pattern: "^#\\s+(.*)$", options: [.anchorsMatchLines]) {
            let matches = h1Regex.matches(in: string, options: [], range: fullRange)
            let h1Font = resolveFontNamed(family: fontFamily, size: baseFontSize * 1.5, bold: true, italic: false)
            let h1Style = baseParagraphStyle.mutableCopy() as! NSMutableParagraphStyle
            h1Style.paragraphSpacing = max(paragraphSpacing, 10)
            h1Style.paragraphSpacingBefore = 0
            for m in matches {
                textStorage.addAttributes([
                    .font: h1Font,
                    .foregroundColor: NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0),
                    .paragraphStyle: h1Style
                ], range: m.range)
            }
        }

        // 2. Heading 2: ^## (.*)$
        if let h2Regex = try? NSRegularExpression(pattern: "^##\\s+(.*)$", options: [.anchorsMatchLines]) {
            let matches = h2Regex.matches(in: string, options: [], range: fullRange)
            let h2Font = resolveFontNamed(family: fontFamily, size: baseFontSize * 1.3, bold: true, italic: false)
            let h2Style = baseParagraphStyle.mutableCopy() as! NSMutableParagraphStyle
            h2Style.paragraphSpacing = max(paragraphSpacing, 8)
            h2Style.paragraphSpacingBefore = 0
            for m in matches {
                textStorage.addAttributes([
                    .font: h2Font,
                    .foregroundColor: NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0),
                    .paragraphStyle: h2Style
                ], range: m.range)
            }
        }

        // 3. Heading 3: ^### (.*)$
        if let h3Regex = try? NSRegularExpression(pattern: "^###\\s+(.*)$", options: [.anchorsMatchLines]) {
            let matches = h3Regex.matches(in: string, options: [], range: fullRange)
            let h3Font = resolveFontNamed(family: fontFamily, size: baseFontSize * 1.15, bold: true, italic: false)
            for m in matches {
                textStorage.addAttributes([
                    .font: h3Font,
                    .foregroundColor: NSColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0)
                ], range: m.range)
            }
        }

        // 4. Bold: \*\*(.+?)\*\*
        if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: []) {
            let matches = boldRegex.matches(in: string, options: [], range: fullRange)
            let boldFont = resolveFontNamed(family: fontFamily, size: baseFontSize, bold: true, italic: false)
            for m in matches {
                textStorage.addAttribute(.font, value: boldFont, range: m.range)
            }
        }

        // 5. Italic: \*(.+?)\*
        if let italicRegex = try? NSRegularExpression(pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)", options: []) {
            let matches = italicRegex.matches(in: string, options: [], range: fullRange)
            let italicFont = resolveFontNamed(family: fontFamily, size: baseFontSize, bold: false, italic: true)
            for m in matches {
                textStorage.addAttribute(.font, value: italicFont, range: m.range)
            }
        }

        // 6. Blockquote: ^>\s*(.*)$
        if let quoteRegex = try? NSRegularExpression(pattern: "^>\\s*(.*)$", options: [.anchorsMatchLines]) {
            let matches = quoteRegex.matches(in: string, options: [], range: fullRange)
            let italicFont = resolveFontNamed(family: fontFamily, size: baseFontSize, bold: false, italic: true)
            let quoteStyle = baseParagraphStyle.mutableCopy() as! NSMutableParagraphStyle
            quoteStyle.headIndent = 16
            quoteStyle.firstLineHeadIndent = 16
            for m in matches {
                textStorage.addAttributes([
                    .font: italicFont,
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: quoteStyle
                ], range: m.range)
            }
        }

        textStorage.endEditing()
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextKit2EditorView
        weak var textView: NSTextView?
        var isUpdatingProgrammatically = false
        var lastAppliedFontFamily: String = ""
        var lastAppliedFontSize: CGFloat = 0
        var lastAppliedLineSpacing: CGFloat = 0
        var lastAppliedParagraphSpacing: CGFloat = 0
        var lastAppliedAlignment: TextAlignment = .leading

        init(_ parent: TextKit2EditorView) {
            self.parent = parent
            self.lastAppliedFontFamily = parent.fontFamily
            self.lastAppliedFontSize = parent.fontSize
            self.lastAppliedLineSpacing = parent.lineSpacing
            self.lastAppliedParagraphSpacing = parent.paragraphSpacing
            self.lastAppliedAlignment = parent.alignment
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isUpdatingProgrammatically else { return }
            let string = textView.string
            if self.parent.text != string {
                self.parent.text = string
            }
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isUpdatingProgrammatically else { return }
            let range = textView.selectedRange()
            let nsString = textView.string as NSString
            let sub = range.length > 0 && range.location + range.length <= nsString.length ? nsString.substring(with: range) : ""
            let attrs = parent.controller?.currentSelectionAttributes() ?? EditorSelectionAttributes()

            if self.parent.selectionRange != range {
                self.parent.selectionRange = range
            }
            if self.parent.selectedText != sub {
                self.parent.selectedText = sub
            }
            self.parent.onSelectionChanged?(range, sub, attrs)
        }
    }
}
