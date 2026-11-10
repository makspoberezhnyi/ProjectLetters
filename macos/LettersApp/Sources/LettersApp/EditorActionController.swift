import SwiftUI
import AppKit
import Foundation
#if canImport(LettersKit)
import LettersKit
#endif

public enum DocumentParagraphStyle: String, CaseIterable, Identifiable {
    case title = "Title"
    case subtitle = "Subtitle"
    case heading1 = "Heading 1"
    case heading2 = "Heading 2"
    case heading3 = "Heading 3"
    case body = "Body"
    case blockquote = "Blockquote"
    case caption = "Caption"

    public var id: String { rawValue }

    public var fontSize: CGFloat {
        switch self {
        case .title: return 28
        case .subtitle: return 18
        case .heading1: return 22
        case .heading2: return 18
        case .heading3: return 15
        case .body: return 15
        case .blockquote: return 15
        case .caption: return 12
        }
    }

    public var isBold: Bool {
        switch self {
        case .title, .heading1, .heading2, .heading3: return true
        default: return false
        }
    }

    public var isItalic: Bool {
        switch self {
        case .subtitle, .blockquote, .caption: return true
        default: return false
        }
    }

    public static func infer(fontSize: CGFloat, isBold: Bool, isItalic: Bool) -> DocumentParagraphStyle {
        if fontSize >= 26 { return .title }
        if fontSize >= 20 && isBold { return .heading1 }
        if fontSize >= 17 && isBold { return .heading2 }
        if fontSize >= 17 && isItalic { return .subtitle }
        if isBold && abs(fontSize - 15) <= 1.5 { return .heading3 }
        if fontSize <= 12.5 { return .caption }
        if isItalic && abs(fontSize - 15) <= 1.5 { return .blockquote }
        return .body
    }
}

public struct EditorSelectionAttributes: Equatable {
    public var fontFamily: String
    public var fontSize: CGFloat
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var isKeepLinesTogether: Bool
    public var isKeepWithNext: Bool
    public var alignment: TextAlignment
    public var paragraphStylePreset: DocumentParagraphStyle
    public var textColor: Color?
    public var highlightColor: Color?

    public init(
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isKeepLinesTogether: Bool = false,
        isKeepWithNext: Bool = false,
        alignment: TextAlignment = .leading,
        paragraphStylePreset: DocumentParagraphStyle = .body,
        textColor: Color? = nil,
        highlightColor: Color? = nil
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isKeepLinesTogether = isKeepLinesTogether
        self.isKeepWithNext = isKeepWithNext
        self.alignment = alignment
        self.paragraphStylePreset = paragraphStylePreset
        self.textColor = textColor
        self.highlightColor = highlightColor
    }
}

public enum PasteSpecialMode: String, CaseIterable, Identifiable {
    case regular = "Regular Paste (Keep Source Formatting)"
    case matchStyle = "Match Document Style (Clean Text)"

    public var id: String { rawValue }
    public var description: String {
        switch self {
        case .regular:
            return "Pastes content verbatim without changes, keeping the original fonts, colors, and layout from the source application."
        case .matchStyle:
            return "Adapts the text to the document's font and size, sanitizing dark-mode contrast and removing incompatible web styling."
        }
    }
    public var icon: String {
        switch self {
        case .regular: return "doc.on.clipboard"
        case .matchStyle: return "textformat"
        }
    }
}

/// Bridges toolbar / menu / inspector commands to the one text view on the canvas.
/// There is exactly one `PaperTextView` per document, so there is no page registry,
/// no "which view is active" heuristic, and no cross-view focus hopping.
@MainActor
public final class EditorActionController: ObservableObject {
    public weak var textView: PaperTextView?

    public init() {}

    public var onImportFile: ((URL) -> Void)?
    public var onInsertImageBlock: ((StudioImageBlock) -> Void)?
    /// Set by the canvas: pushes the live attributed string into the document model.
    public var onFlush: (() -> Void)?

    /// Call before anything reads the document model (save, export, snapshot).
    public func flushPendingEdits() { onFlush?() }

    /// Number of sheets currently on the canvas.
    public var pageCount: Int { textView?.pageCount ?? 1 }

    /// 1-based page that contains a character offset.
    public func pageNumber(forCharacterOffset offset: Int) -> Int {
        textView?.pageNumber(forCharacterOffset: offset) ?? 1
    }

    /// Inserts text at the caret (or over the selection) through the text view, so it is undoable
    /// and inherits the formatting at the caret.
    public func insertAtCaret(_ string: String) {
        guard let tv = textView else { return }
        tv.insertText(string, replacementRange: tv.selectedRange())
    }

    /// First words on a page, for the outline's Pages tab.
    public func snippet(forPage page: Int) -> String {
        guard let tv = textView, let config = tv.config else { return "" }
        let g = config.geometry
        let y = CGFloat(page) * g.sheetSize.height + g.margins.top + 2
        let start = tv.characterIndexForInsertion(at: NSPoint(x: g.margins.left + 2, y: y))
        let ns = tv.string as NSString
        guard start != NSNotFound, start < ns.length else { return "" }
        return ns.substring(with: NSRange(location: start, length: min(80, ns.length - start)))
    }

    /// Scrolls so that the top of `page` (0-based) is at the top of the viewport.
    public func scrollToPage(_ page: Int) {
        guard let tv = textView, let config = tv.config, let scroll = tv.enclosingScrollView else { return }
        let y = tv.frame.minY + CGFloat(max(0, page)) * config.geometry.sheetSize.height - 12
        let clip = scroll.contentView
        clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: max(0, y)))
        scroll.reflectScrolledClipView(clip)
    }

    public func pasteSpecial(mode: PasteSpecialMode) {
        guard let tv = textView else { return }
        switch mode {
        case .regular:
            tv.paste(nil)
        case .matchStyle:
            tv.pasteWithCleanContrast()
        }
    }

    public func cleanContrastForCurrentSelection() {
        guard let tv = textView else { return }
        let sel = tv.selectedRange()
        if sel.length > 0 {
            tv.cleanContrast(in: sel)
        } else if let storage = tv.textStorage {
            tv.cleanContrast(in: NSRange(location: 0, length: storage.length))
        }
    }

    /// Moves the caret to `offset`, scrolls it into view and gives the canvas keyboard focus.
    public func jumpToCharacterOffset(_ offset: Int) {
        guard let tv = textView else { return }
        let length = (tv.string as NSString).length
        let range = NSRange(location: max(0, min(offset, length)), length: 0)
        tv.window?.makeFirstResponder(tv)
        tv.setSelectedRange(range)
        tv.scrollRangeToVisible(range)
    }

    /// Gives the canvas keyboard focus (used on launch and after sheets / popovers close).
    public func focusCanvas() {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
    }

    public func currentSelectionAttributes() -> EditorSelectionAttributes? {
        guard let textView = textView else { return nil }
        let range = textView.selectedRange()
        var font: NSFont? = nil
        var fgColor: NSColor? = nil
        var bgColor: NSColor? = nil
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
                fgColor = attrs[.foregroundColor] as? NSColor
                bgColor = attrs[.backgroundColor] as? NSColor
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
        if fgColor == nil {
            fgColor = textView.typingAttributes[.foregroundColor] as? NSColor
        }
        if bgColor == nil {
            bgColor = textView.typingAttributes[.backgroundColor] as? NSColor
        }

        let validFont = font ?? NSFont.systemFont(ofSize: 15)
        let traits = NSFontManager.shared.traits(of: validFont)
        let bold = traits.contains(.boldFontMask)
        let italic = traits.contains(.italicFontMask)
        let fam = fontDisplayName(for: validFont)

        var isKeepLinesTogether = false
        var isKeepWithNext = false
        
        if range.length > 0 {
            if let str = textView.textStorage {
                if let attr = str.attribute(.keepLinesTogether, at: range.location, effectiveRange: nil) as? Bool {
                    isKeepLinesTogether = attr
                }
                if let attr = str.attribute(.keepWithNext, at: range.location, effectiveRange: nil) as? Bool {
                    isKeepWithNext = attr
                }
            }
        } else {
            if let attr = textView.typingAttributes[.keepLinesTogether] as? Bool {
                isKeepLinesTogether = attr
            }
            if let attr = textView.typingAttributes[.keepWithNext] as? Bool {
                isKeepWithNext = attr
            }
        }

        let ptSize = validFont.pointSize > 0 ? validFont.pointSize : 15.0
        let preset = DocumentParagraphStyle.infer(fontSize: ptSize, isBold: bold, isItalic: italic)
        let textColor = fgColor != nil ? Color(nsColor: fgColor!) : nil
        let highlightColor = bgColor != nil ? Color(nsColor: bgColor!) : nil

        return EditorSelectionAttributes(
            fontFamily: fam,
            fontSize: ptSize,
            isBold: bold,
            isItalic: italic,
            isUnderline: isUnderlined,
            isKeepLinesTogether: isKeepLinesTogether,
            isKeepWithNext: isKeepWithNext,
            alignment: align,
            paragraphStylePreset: preset,
            textColor: textColor,
            highlightColor: highlightColor
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

    public func toggleKeepLinesTogether() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard let textStorage = textView.textStorage else { return }

        // Expand range to cover full paragraphs
        let paragraphRange = (textStorage.string as NSString).paragraphRange(for: range)

        if paragraphRange.length > 0 {
            var allKeep = true
            textStorage.enumerateAttribute(.keepLinesTogether, in: paragraphRange, options: []) { value, _, stop in
                let val = (value as? Bool) ?? false
                if !val {
                    allKeep = false
                    stop.pointee = true
                }
            }

            textStorage.beginEditing()
            if allKeep {
                textStorage.removeAttribute(.keepLinesTogether, range: paragraphRange)
            } else {
                textStorage.addAttribute(.keepLinesTogether, value: true, range: paragraphRange)
            }
            textStorage.endEditing()
            textView.didChangeText()
        } else {
            var attrs = textView.typingAttributes
            let isKeep = (attrs[.keepLinesTogether] as? Bool) ?? false
            if isKeep { attrs.removeValue(forKey: .keepLinesTogether) }
            else { attrs[.keepLinesTogether] = true }
            textView.typingAttributes = attrs
        }
    }

    public func toggleKeepWithNext() {
        guard let textView = textView else { return }
        let range = textView.selectedRange()
        guard let textStorage = textView.textStorage else { return }

        let paragraphRange = (textStorage.string as NSString).paragraphRange(for: range)

        if paragraphRange.length > 0 {
            var allKeep = true
            textStorage.enumerateAttribute(.keepWithNext, in: paragraphRange, options: []) { value, _, stop in
                let val = (value as? Bool) ?? false
                if !val {
                    allKeep = false
                    stop.pointee = true
                }
            }

            textStorage.beginEditing()
            if allKeep {
                textStorage.removeAttribute(.keepWithNext, range: paragraphRange)
            } else {
                textStorage.addAttribute(.keepWithNext, value: true, range: paragraphRange)
            }
            textStorage.endEditing()
            textView.didChangeText()
        } else {
            var attrs = textView.typingAttributes
            let isKeep = (attrs[.keepWithNext] as? Bool) ?? false
            if isKeep { attrs.removeValue(forKey: .keepWithNext) }
            else { attrs[.keepWithNext] = true }
            textView.typingAttributes = attrs
        }
    }
    
    public func insertAttachment(_ attachment: NSTextAttachment) {
        guard let textView = textView, textView.textStorage != nil else { return }
        let range = textView.selectedRange()
        let attrStr = NSAttributedString(attachment: attachment)
        
        if range.location != NSNotFound {
            textView.insertText(attrStr, replacementRange: range)
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

    private func invalidateTextKitLayout(for textView: NSTextView, range: NSRange) {
        if #available(macOS 12.0, *),
           let tlm = textView.textLayoutManager,
           let contentManager = tlm.textContentManager {
            let docRange = contentManager.documentRange
            tlm.invalidateLayout(for: docRange)
            tlm.ensureLayout(for: docRange)
        }
        textView.layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        textView.needsLayout = true
        textView.needsDisplay = true
    }

    public func applyAlignment(_ alignment: TextAlignment, lineSpacing: CGFloat, paragraphSpacing: CGFloat) {
        let targetTextView = textView
        guard let tv = targetTextView, let textStorage = tv.textStorage else { return }
        let nsString = textStorage.string as NSString
        guard nsString.length > 0 else { return }

        let range = tv.selectedRange()
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
        style.paragraphSpacingBefore = paragraphSpacing * 0.5

        textStorage.beginEditing()
        textStorage.addAttribute(.paragraphStyle, value: style, range: targetRange)
        textStorage.endEditing()

        var attrs = tv.typingAttributes
        attrs[.paragraphStyle] = style
        tv.typingAttributes = attrs
        tv.defaultParagraphStyle = style

        invalidateTextKitLayout(for: tv, range: targetRange)
        tv.didChangeText()
    }

    public func applyLineSpacing(_ lineSpacing: CGFloat, paragraphSpacing: CGFloat) {
        guard let active = textView else { return }
        let viewsToUpdate: [NSTextView] = [active]

        for tv in viewsToUpdate {
            guard let textStorage = tv.textStorage else { continue }
            let nsString = textStorage.string as NSString
            guard nsString.length > 0 else { continue }

            let range = tv.selectedRange()
            let targetRange: NSRange
            if range.length > 0 {
                targetRange = nsString.paragraphRange(for: range)
            } else {
                targetRange = NSRange(location: 0, length: nsString.length)
            }

            textStorage.beginEditing()
            textStorage.enumerateAttribute(.paragraphStyle, in: targetRange, options: []) { value, subRange, _ in
                let style = ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                style.lineHeightMultiple = lineSpacing
                style.paragraphSpacing = paragraphSpacing
                style.paragraphSpacingBefore = paragraphSpacing * 0.5
                textStorage.addAttribute(.paragraphStyle, value: style, range: subRange)
            }
            textStorage.endEditing()

            let typingStyle = ((tv.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            typingStyle.lineHeightMultiple = lineSpacing
            typingStyle.paragraphSpacing = paragraphSpacing
            typingStyle.paragraphSpacingBefore = paragraphSpacing * 0.5
            var attrs = tv.typingAttributes
            attrs[.paragraphStyle] = typingStyle
            tv.typingAttributes = attrs
            tv.defaultParagraphStyle = typingStyle

            invalidateTextKitLayout(for: tv, range: targetRange)
            tv.didChangeText()
        }
    }

    public func applyParagraphStyle(_ preset: DocumentParagraphStyle, fontFamily: String, lineSpacing: CGFloat, paragraphSpacing: CGFloat) {
        let targetTextView = textView
        guard let tv = targetTextView, let textStorage = tv.textStorage else { return }
        let nsString = textStorage.string as NSString
        let targetFont = resolveFontNamed(family: fontFamily, size: preset.fontSize, bold: preset.isBold, italic: preset.isItalic)

        if nsString.length > 0 {
            let range = tv.selectedRange()
            let safeLoc = min(max(0, range.location), max(0, nsString.length - 1))
            let paraRange = range.length > 0
                ? nsString.paragraphRange(for: range)
                : nsString.paragraphRange(for: NSRange(location: safeLoc, length: 0))

            let existingStyle = textStorage.attribute(.paragraphStyle, at: max(0, paraRange.location), effectiveRange: nil) as? NSParagraphStyle
            let style = (existingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            style.lineHeightMultiple = lineSpacing
            style.paragraphSpacing = (preset == .heading1 || preset == .heading2 || preset == .title) ? max(10, paragraphSpacing) : paragraphSpacing
            style.paragraphSpacingBefore = (preset == .heading1 || preset == .heading2 || preset == .heading3) ? 10 : paragraphSpacing * 0.5
            if preset == .blockquote {
                style.headIndent = 24
                style.firstLineHeadIndent = 24
            } else {
                style.headIndent = 0
                style.firstLineHeadIndent = 0
            }

            textStorage.beginEditing()
            textStorage.addAttribute(.font, value: targetFont, range: paraRange)
            textStorage.addAttribute(.paragraphStyle, value: style, range: paraRange)
            if preset == .heading1 || preset == .heading2 || preset == .heading3 {
                textStorage.addAttribute(.keepWithNext, value: true, range: paraRange)
            }
            textStorage.endEditing()

            invalidateTextKitLayout(for: tv, range: paraRange)
            tv.didChangeText()
        }

        var typing = tv.typingAttributes
        typing[.font] = targetFont
        tv.typingAttributes = typing
    }

    public func toggleBulletList() {
        let targetTextView = textView
        guard let tv = targetTextView, let textStorage = tv.textStorage else { return }
        let ns = textStorage.string as NSString
        let sel = tv.selectedRange()
        if ns.length == 0 {
            tv.insertText("• ", replacementRange: NSRange(location: 0, length: 0))
            return
        }
        let safeLoc = min(max(0, sel.location), max(0, ns.length - 1))
        let paraRange = sel.length > 0 ? ns.paragraphRange(for: sel) : ns.paragraphRange(for: NSRange(location: safeLoc, length: 0))
        let paraStr = ns.substring(with: paraRange)
        let lines = paraStr.components(separatedBy: "\n")
        var updatedLines: [String] = []
        for (i, line) in lines.enumerated() {
            if i == lines.count - 1 && line.isEmpty && paraStr.hasSuffix("\n") {
                updatedLines.append("")
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("• ") || trimmed.hasPrefix("◦ ") || trimmed.hasPrefix("▪ ") {
                if let range = line.range(of: #"^\s*[•◦▪]\s+"#, options: .regularExpression) {
                    var copy = line
                    copy.removeSubrange(range)
                    updatedLines.append(copy)
                } else {
                    updatedLines.append(line)
                }
            } else if let range = line.range(of: #"^\s*\d+\.\s+"#, options: .regularExpression) {
                var copy = line
                copy.replaceSubrange(range, with: "• ")
                updatedLines.append(copy)
            } else {
                updatedLines.append("• " + line)
            }
        }
        let replacement = updatedLines.joined(separator: "\n")
        tv.insertText(replacement, replacementRange: paraRange)
    }

    public func toggleNumberedList() {
        let targetTextView = textView
        guard let tv = targetTextView, let textStorage = tv.textStorage else { return }
        let ns = textStorage.string as NSString
        let sel = tv.selectedRange()
        if ns.length == 0 {
            tv.insertText("1. ", replacementRange: NSRange(location: 0, length: 0))
            return
        }
        let safeLoc = min(max(0, sel.location), max(0, ns.length - 1))
        let paraRange = sel.length > 0 ? ns.paragraphRange(for: sel) : ns.paragraphRange(for: NSRange(location: safeLoc, length: 0))
        let paraStr = ns.substring(with: paraRange)
        let lines = paraStr.components(separatedBy: "\n")
        var updatedLines: [String] = []
        var counter = 1
        for (i, line) in lines.enumerated() {
            if i == lines.count - 1 && line.isEmpty && paraStr.hasSuffix("\n") {
                updatedLines.append("")
                continue
            }
            if let range = line.range(of: #"^\s*\d+\.\s+"#, options: .regularExpression) {
                var copy = line
                copy.removeSubrange(range)
                updatedLines.append(copy)
            } else if let range = line.range(of: #"^\s*[•◦▪]\s+"#, options: .regularExpression) {
                var copy = line
                copy.replaceSubrange(range, with: "\(counter). ")
                updatedLines.append(copy)
                counter += 1
            } else {
                updatedLines.append("\(counter). " + line)
                counter += 1
            }
        }
        let replacement = updatedLines.joined(separator: "\n")
        tv.insertText(replacement, replacementRange: paraRange)
    }

    public func setTextColor(_ color: NSColor) {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        if let textStorage = tv.textStorage, range.length > 0 {
            textStorage.beginEditing()
            textStorage.addAttribute(.foregroundColor, value: color, range: range)
            textStorage.endEditing()
            tv.didChangeText()
        }
        var typing = tv.typingAttributes
        typing[.foregroundColor] = color
        tv.typingAttributes = typing
    }

    public func setTextHighlight(_ color: NSColor?) {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        if let textStorage = tv.textStorage, range.length > 0 {
            textStorage.beginEditing()
            if let color = color {
                textStorage.addAttribute(.backgroundColor, value: color, range: range)
            } else {
                textStorage.removeAttribute(.backgroundColor, range: range)
            }
            textStorage.endEditing()
            tv.didChangeText()
        }
        var typing = tv.typingAttributes
        if let color = color {
            typing[.backgroundColor] = color
        } else {
            typing.removeValue(forKey: .backgroundColor)
        }
        tv.typingAttributes = typing
    }

    public func clearFormatting() {
        guard let textView = textView, let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let defaultFont = resolveFontNamed(family: "Default Serif (Georgia)", size: 15.0, bold: false, italic: false)
        let defaultColor = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        if range.length > 0 {
            textStorage.beginEditing()
            textStorage.removeAttribute(.underlineStyle, range: range)
            textStorage.removeAttribute(.strikethroughStyle, range: range)
            textStorage.removeAttribute(.backgroundColor, range: range)
            textStorage.addAttribute(.foregroundColor, value: defaultColor, range: range)
            textStorage.addAttribute(.font, value: defaultFont, range: range)
            textStorage.endEditing()
            textView.didChangeText()
        }
        var typing = textView.typingAttributes
        typing[.font] = defaultFont
        typing[.foregroundColor] = defaultColor
        typing.removeValue(forKey: .underlineStyle)
        typing.removeValue(forKey: .strikethroughStyle)
        typing.removeValue(forKey: .backgroundColor)
        textView.typingAttributes = typing
    }
}

public func fontDisplayName(for font: NSFont) -> String {
    let name = font.fontName.lowercased()
    let familyName = font.familyName?.lowercased() ?? ""
    if name.contains("georgia") || familyName.contains("georgia") {
        return "Default Serif (Georgia)"
    } else if name.contains("newyork") || familyName.contains("new york") {
        return "New York (Editorial)"
    } else if name.contains("times") || familyName.contains("times") {
        return "Times New Roman"
    } else if name.contains("helvetica") || familyName.contains("helvetica") {
        return "Helvetica Neue"
    } else if name.contains("avenir") || familyName.contains("avenir") {
        return "Avenir Next"
    } else if name.contains("baskerville") || familyName.contains("baskerville") {
        return "Baskerville"
    } else if name.contains("palatino") || familyName.contains("palatino") {
        return "Palatino"
    } else if name.contains("sfmono") || familyName.contains("sf mono") {
        return "SF Mono (Code)"
    } else if name.contains("menlo") || familyName.contains("menlo") {
        return "Menlo (Monospace)"
    } else if name.contains("courier") || familyName.contains("courier") {
        return "Courier New"
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
