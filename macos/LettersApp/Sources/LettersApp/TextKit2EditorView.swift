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

    public var onSelectAllRequested: (() -> Void)?
    public var onImportFile: ((URL) -> Void)?
    public var onInsertImageBlock: ((StudioImageBlock) -> Void)?

    public func selectAllPages() {
        onSelectAllRequested?()
    }

    public var activeTextView: StudioTextView? {
        if let focused = pageViews.values.first(where: { $0.window?.firstResponder == $0 }) {
            return focused
        }
        if let selected = pageViews.values.first(where: { $0.selectedRange().length > 0 }) {
            return selected
        }
        if let tv = textView as? StudioTextView {
            return tv
        }
        return pageViews.values.first
    }

    public func pasteSpecial(mode: PasteSpecialMode) {
        guard let tv = activeTextView ?? (textView as? StudioTextView) ?? pageViews.values.first else { return }
        switch mode {
        case .regular:
            tv.paste(nil)
        case .matchStyle:
            tv.pasteWithCleanContrast()
        }
    }

    public func cleanContrastForCurrentSelection() {
        guard let tv = textView as? StudioTextView ?? pageViews.values.first else { return }
        let sel = tv.selectedRange()
        if sel.length > 0 {
            tv.cleanContrast(in: sel)
        } else if let storage = tv.textStorage {
            tv.cleanContrast(in: NSRange(location: 0, length: storage.length))
        }
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
        guard let textView = activeTextView else { return nil }
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
        guard let textView = activeTextView ?? textView else { return }
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
        guard let textView = activeTextView ?? textView else { return }
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
        guard let textView = activeTextView ?? textView else { return }
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
        guard let textView = activeTextView ?? textView else { return }
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
        guard let textView = activeTextView ?? textView else { return }
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
        guard let textView = activeTextView ?? textView, let textStorage = textView.textStorage else { return }
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
        guard let textView = activeTextView ?? textView, let textStorage = textView.textStorage else { return }
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
        guard let textView = activeTextView ?? textView else { return }
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
        let targetTextView = textView ?? pageViews[0] ?? pageViews.values.first
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
        let viewsToUpdate: [NSTextView]
        if let active = textView, active.selectedRange().length > 0 {
            viewsToUpdate = [active]
        } else if !pageViews.isEmpty {
            viewsToUpdate = Array(pageViews.values)
        } else if let active = textView {
            viewsToUpdate = [active]
        } else {
            return
        }

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
        let targetTextView = textView ?? pageViews[0] ?? pageViews.values.first
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
        let targetTextView = textView ?? pageViews[0] ?? pageViews.values.first
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
        let targetTextView = textView ?? pageViews[0] ?? pageViews.values.first
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
        guard let tv = activeTextView ?? (textView as? StudioTextView) ?? pageViews.values.first else { return }
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
        for otherTv in pageViews.values {
            var t = otherTv.typingAttributes
            t[.foregroundColor] = color
            otherTv.typingAttributes = t
        }
    }

    public func setTextHighlight(_ color: NSColor?) {
        guard let tv = activeTextView ?? (textView as? StudioTextView) ?? pageViews.values.first else { return }
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
        for otherTv in pageViews.values {
            var t = otherTv.typingAttributes
            if let color = color {
                t[.backgroundColor] = color
            } else {
                t.removeValue(forKey: .backgroundColor)
            }
            otherTv.typingAttributes = t
        }
    }

    public func clearFormatting() {
        guard let textView = activeTextView, let textStorage = textView.textStorage else { return }
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

public class StudioTextView: NSTextView {
    public weak var actionController: EditorActionController?
    public var pageIndex: Int = 0
    public var showLineNumbers: Bool = false

    public override var isFlipped: Bool { true }

    public override func selectAll(_ sender: Any?) {
        super.selectAll(sender)
        actionController?.selectAllPages()
    }

    public override func scrollRangeToVisible(_ range: NSRange) {
        self.bounds.origin = .zero
    }

    public override func scroll(_ point: NSPoint) {
        self.bounds.origin = .zero
    }

    public override func autoscroll(with event: NSEvent) -> Bool {
        self.bounds.origin = .zero
        return false
    }

    public override func scrollWheel(with event: NSEvent) {
        self.nextResponder?.scrollWheel(with: event)
    }

    public override func layout() {
        super.layout()
        if self.bounds.origin != .zero {
            self.bounds.origin = .zero
        }
    }

    public override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        // 1. Check if clipboard contains an image file URL
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "webp", "tiff", "heic"].contains(ext),
                   let data = try? Data(contentsOf: url) {
                    let block = StudioImageBlock(
                        base64Data: data.base64EncodedString(),
                        originalByteSize: data.count,
                        compressedByteSize: data.count,
                        caption: "Figure: \(url.deletingPathExtension().lastPathComponent)"
                    )
                    actionController?.onInsertImageBlock?(block)
                    return
                }
            }
        }
        // 2. Check if clipboard contains raw image bitmap data (e.g. screenshot)
        if pb.string(forType: .string) == nil,
           let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let img = images.first,
           let tiff = img.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let block = StudioImageBlock(
                base64Data: pngData.base64EncodedString(),
                originalByteSize: pngData.count,
                compressedByteSize: pngData.count,
                caption: "Pasted Figure"
            )
            actionController?.onInsertImageBlock?(block)
            return
        }
        super.paste(sender)
    }

    public override func pasteAsPlainText(_ sender: Any?) {
        super.pasteAsPlainText(sender)
    }

    public func pasteAndMatchStyle() {
        guard let pboard = NSPasteboard.general.string(forType: .string) else {
            super.paste(nil)
            return
        }
        self.insertText(pboard, replacementRange: self.selectedRange())
    }

    public func pasteWithCleanContrast() {
        let preSelection = self.selectedRange()
        super.paste(nil)
        let postSelection = self.selectedRange()
        if postSelection.location > preSelection.location {
            let pastedRange = NSRange(location: preSelection.location, length: postSelection.location - preSelection.location)
            cleanContrast(in: pastedRange)
        }
    }

    public func cleanContrast(in range: NSRange) {
        guard let storage = self.textStorage, range.location + range.length <= storage.length else { return }
        storage.beginEditing()
        storage.enumerateAttributes(in: range, options: []) { attrs, subRange, _ in
            var needsUpdate = false
            var updated = attrs

            if let fgColor = attrs[.foregroundColor] as? NSColor {
                if let rgb = fgColor.usingColorSpace(.deviceRGB) {
                    let lum = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
                    if lum > 0.82 { // Near-white or pure white
                        updated[.foregroundColor] = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
                        needsUpdate = true
                    }
                }
            }

            if let bgColor = attrs[.backgroundColor] as? NSColor {
                if let rgb = bgColor.usingColorSpace(.deviceRGB) {
                    let lum = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
                    // If dark background (e.g. from dark terminal/IDE) or pure white background block
                    if lum < 0.25 || lum > 0.98 {
                        updated.removeValue(forKey: .backgroundColor)
                        needsUpdate = true
                    }
                }
            }

            if needsUpdate {
                storage.setAttributes(updated, range: subRange)
            }
        }
        storage.endEditing()
        self.didChangeText()
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            var handled = false
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ext == "docx" || ext == "pdf" || ext == "txt" || ext == "md" {
                    actionController?.onImportFile?(url)
                    handled = true
                } else if ["png", "jpg", "jpeg", "webp", "tiff", "heic"].contains(ext),
                          let data = try? Data(contentsOf: url) {
                    let block = StudioImageBlock(
                        base64Data: data.base64EncodedString(),
                        originalByteSize: data.count,
                        compressedByteSize: data.count,
                        caption: "Figure: \(url.deletingPathExtension().lastPathComponent)"
                    )
                    actionController?.onInsertImageBlock?(block)
                    handled = true
                }
            }
            if handled { return true }
        }
        return super.performDragOperation(sender)
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
        let ns = self.string as NSString
        let sel = self.selectedRange()
        let strLen = ns.length

        // Command + Return = Insert Page Break
        if event.modifierFlags.contains(.command) && (event.keyCode == 36 || event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\n") {
            self.insertText("\n\n---pagebreak---\n\n", replacementRange: sel)
            return
        }

        // Smart List Return key continuation & exit (Word / Pages behavior)
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.command) && sel.length == 0 && strLen > 0 {
            let safeLoc = min(max(0, sel.location), max(0, strLen - 1))
            let lineRange = ns.lineRange(for: NSRange(location: safeLoc, length: 0))
            let currentLine = ns.substring(with: lineRange).replacingOccurrences(of: "\n", with: "")

            // Match bullet list: optional leading spaces + (•, ◦, ▪, - [ ], - [x]) + space
            if let bulletMatch = currentLine.range(of: #"^(\s*)([•◦▪]|-\s\[[ xX]\])\s+(.*)$"#, options: .regularExpression) {
                let prefixEnd = currentLine.range(of: #"^(\s*)([•◦▪]|-\s\[[ xX]\])\s+"#, options: .regularExpression)!
                let prefix = String(currentLine[prefixEnd])
                let body = String(currentLine[prefixEnd.upperBound...]).trimmingCharacters(in: .whitespaces)
                let _ = bulletMatch
                if body.isEmpty {
                    // Empty bullet item -> exit list on Return
                    let replaceLen = currentLine.count
                    self.insertText("", replacementRange: NSRange(location: lineRange.location, length: min(replaceLen, strLen - lineRange.location)))
                    return
                } else {
                    let nextPrefix = prefix.replacingOccurrences(of: "[x]", with: "[ ]").replacingOccurrences(of: "[X]", with: "[ ]")
                    self.insertText("\n" + nextPrefix, replacementRange: sel)
                    return
                }
            }

            // Match numbered list: optional leading spaces + number. + space
            if let numPrefixRange = currentLine.range(of: #"^(\s*)(\d+)\.\s+"#, options: .regularExpression) {
                let prefix = String(currentLine[numPrefixRange])
                let body = String(currentLine[numPrefixRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if body.isEmpty {
                    let replaceLen = currentLine.count
                    self.insertText("", replacementRange: NSRange(location: lineRange.location, length: min(replaceLen, strLen - lineRange.location)))
                    return
                } else {
                    let leadingSpaces = String(prefix.prefix(while: { $0 == " " || $0 == "\t" }))
                    let digitsStr = prefix.trimmingCharacters(in: .whitespaces).dropLast() // drop "."
                    let nextNum = (Int(digitsStr) ?? 1) + 1
                    self.insertText("\n\(leadingSpaces)\(nextNum). ", replacementRange: sel)
                    return
                }
            }
        }

        // Smart Tab / Shift+Tab list nesting (Word / Pages behavior)
        if event.keyCode == 48 && sel.length == 0 && strLen > 0 {
            let safeLoc = min(max(0, sel.location), max(0, strLen - 1))
            let lineRange = ns.lineRange(for: NSRange(location: safeLoc, length: 0))
            let currentLine = ns.substring(with: lineRange)
            if currentLine.range(of: #"^\s*([•◦▪]|\d+\.|-\s\[[ xX]\])\s+"#, options: .regularExpression) != nil {
                let isShift = event.modifierFlags.contains(.shift)
                if isShift {
                    if currentLine.hasPrefix("    ") {
                        let updated = String(currentLine.dropFirst(4))
                            .replacingOccurrences(of: "▪ ", with: "◦ ")
                            .replacingOccurrences(of: "◦ ", with: "• ")
                        self.insertText(updated, replacementRange: lineRange)
                        return
                    }
                } else {
                    let updated: String
                    if currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("• ") {
                        updated = "    " + currentLine.replacingOccurrences(of: "• ", with: "◦ ")
                    } else if currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("◦ ") {
                        updated = "    " + currentLine.replacingOccurrences(of: "◦ ", with: "▪ ")
                    } else {
                        updated = "    " + currentLine
                    }
                    self.insertText(updated, replacementRange: lineRange)
                    return
                }
            }
        }

        // Auto-markdown list triggers on Space (e.g. typing "* " or "- " or "1. " at start of line)
        if event.charactersIgnoringModifiers == " " && sel.length == 0 && strLen > 0 {
            let safeLoc = min(max(0, sel.location), strLen)
            let lineRange = ns.lineRange(for: NSRange(location: max(0, safeLoc - 1), length: 0))
            let prefixLen = safeLoc - lineRange.location
            if prefixLen > 0 && lineRange.location + prefixLen <= strLen {
                let linePrefix = ns.substring(with: NSRange(location: lineRange.location, length: prefixLen))
                if linePrefix == "*" || linePrefix == "-" {
                    self.insertText("• ", replacementRange: NSRange(location: lineRange.location, length: prefixLen))
                    return
                } else if linePrefix.range(of: #"^\d+\.$"#, options: .regularExpression) != nil {
                    self.insertText("\(linePrefix) ", replacementRange: NSRange(location: lineRange.location, length: prefixLen))
                    return
                }
            }
        }

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
    @Binding var richTextData: Data?
    @Binding var selectedText: String
    @Binding var selectionRange: NSRange
    var rawFullText: String
    var attributedText: NSAttributedString?
    var sliceRange: NSRange?
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
    var showLineNumbers: Bool
    var kern: CGFloat          // character tracking/kerning in points
    var hangingIndent: CGFloat // hanging indent for bibliography-style paragraphs
    var isContinuation: Bool   // True if this slice is the second half of a paragraph split across pages
    var hoveredCommentId: UUID?
    var onSelectionChanged: ((NSRange, String, EditorSelectionAttributes) -> Void)?
    var exclusionPaths: [NSBezierPath] = []

    public init(
        text: Binding<String>,
        richTextData: Binding<Data?> = .constant(nil),
        selectedText: Binding<String>,
        selectionRange: Binding<NSRange>,
        rawFullText: String = "",
        attributedText: NSAttributedString? = nil,
        sliceRange: NSRange? = nil,
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
        showLineNumbers: Bool = false,
        kern: CGFloat = 0.0,
        hangingIndent: CGFloat = 0.0,
        isContinuation: Bool = false,
        hoveredCommentId: UUID? = nil,
        onSelectionChanged: ((NSRange, String, EditorSelectionAttributes) -> Void)? = nil,
        exclusionPaths: [NSBezierPath] = []
    ) {
        self._text = text
        self._richTextData = richTextData
        self._selectedText = selectedText
        self._selectionRange = selectionRange
        self.rawFullText = rawFullText
        self.attributedText = attributedText
        self.sliceRange = sliceRange
        self.controller = controller
        self.exclusionPaths = exclusionPaths
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
        self.showLineNumbers = showLineNumbers
        self.kern = kern
        self.hangingIndent = hangingIndent
        self.isContinuation = isContinuation
        self.hoveredCommentId = hoveredCommentId
        self.onSelectionChanged = onSelectionChanged
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> StudioTextView {
        let textView: StudioTextView
        if #available(macOS 12.0, *) {
            textView = StudioTextView(usingTextLayoutManager: true)
        } else {
            textView = StudioTextView()
        }
        
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
        // Hanging indent: headIndent = hangingIndent pushes wrapped lines right,
        // firstLineHeadIndent = 0 keeps first line flush left
        if hangingIndent > 0 {
            paragraphStyle.headIndent = hangingIndent
            paragraphStyle.firstLineHeadIndent = isContinuation ? hangingIndent : 0
        }

        let textColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = NSColor.systemBlue
        textView.defaultParagraphStyle = paragraphStyle

        var typingAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        if kern != 0 {
            typingAttrs[.kern] = kern
        }
        textView.typingAttributes = typingAttrs

        textView.textContainerInset = NSSize(width: showLineNumbers ? 40 : 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 4.0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.exclusionPaths = exclusionPaths
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.autoresizingMask = [.width, .height]

        context.coordinator.isUpdatingProgrammatically = true
        if let attrText = attributedText, !attrText.string.isEmpty {
            textView.textStorage?.setAttributedString(attrText)
        } else {
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
                    paragraphSpacing: paragraphSpacing,
                    kern: kern,
                    hangingIndent: hangingIndent,
                    isContinuation: isContinuation
                )
            }
        }
        textView.pageIndex = pageIndex
        textView.showLineNumbers = showLineNumbers
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
        textView.showLineNumbers = showLineNumbers
        textView.actionController = controller
        textView.textContainerInset = NSSize(width: showLineNumbers ? 40 : 0, height: 0)
        textView.textContainer?.exclusionPaths = exclusionPaths
        textView.needsDisplay = true // Force redraw to update line numbers
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
        if textView.string != text || (attributedText == nil && typographyChanged) {
            context.coordinator.isUpdatingProgrammatically = true
            if textView.string != text {
                if let attrText = attributedText, !attrText.string.isEmpty {
                    textView.textStorage?.setAttributedString(attrText)
                } else {
                    textView.string = text
                }
            }
            if attributedText == nil {
                if let storage = textView.textStorage {
                    Self.applyTypographyStyling(
                        to: storage,
                        fontFamily: fontFamily,
                        baseFontSize: fontSize,
                        isBold: isBold,
                        isItalic: isItalic,
                        alignment: alignment,
                        lineSpacing: lineSpacing,
                        paragraphSpacing: paragraphSpacing,
                        kern: kern,
                        hangingIndent: hangingIndent,
                        isContinuation: isContinuation,
                        overrideAlignment: true,
                        overrideFontFamily: true
                    )
                    if #available(macOS 12.0, *),
                       let tlm = textView.textLayoutManager,
                       let contentManager = tlm.textContentManager {
                        let docRange = contentManager.documentRange
                        tlm.invalidateLayout(for: docRange)
                        tlm.ensureLayout(for: docRange)
                    }
                    textView.needsLayout = true
                    textView.needsDisplay = true
                }
            }
            context.coordinator.lastAppliedFontFamily = fontFamily
            context.coordinator.lastAppliedFontSize = fontSize
            context.coordinator.lastAppliedLineSpacing = lineSpacing
            context.coordinator.lastAppliedParagraphSpacing = paragraphSpacing
            context.coordinator.lastAppliedAlignment = alignment
            context.coordinator.isUpdatingProgrammatically = false
        }

        // Only sync selection if user is NOT currently focusing / interacting with this text view
        if textView.window?.firstResponder != textView {
            context.coordinator.isUpdatingProgrammatically = true
            if let slice = sliceRange {
                let intersection = NSIntersectionRange(selectionRange, slice)
                if intersection.length > 0 {
                    let localRange = NSRange(location: intersection.location - slice.location, length: intersection.length)
                    if localRange.location + localRange.length <= (textView.string as NSString).length {
                        textView.setSelectedRange(localRange)
                    }
                } else if selectionRange.location <= slice.location && selectionRange.location + selectionRange.length >= slice.location + slice.length {
                    // Fully contains
                    textView.setSelectedRange(NSRange(location: 0, length: (textView.string as NSString).length))
                } else if textView.selectedRange().length > 0 {
                    textView.setSelectedRange(NSRange(location: 0, length: 0))
                }
            }
            context.coordinator.isUpdatingProgrammatically = false
        }

        // Comment highlights: only apply when side notes or hover state actually changed
        let currentNotes = LettersDocumentController.active?.sideNotes ?? []
        let currentResolved = currentNotes.filter { $0.isResolved }.count
        let notesChanged = currentNotes.count != context.coordinator.lastAppliedSideNotesCount ||
                           currentResolved != context.coordinator.lastAppliedSideNotesResolvedCount ||
                           hoveredCommentId != context.coordinator.lastAppliedHoveredCommentId

        if notesChanged {
            context.coordinator.lastAppliedSideNotesCount = currentNotes.count
            context.coordinator.lastAppliedSideNotesResolvedCount = currentResolved
            context.coordinator.lastAppliedHoveredCommentId = hoveredCommentId
            Self.applyCommentHighlights(
                to: textView.textStorage,
                sliceRange: sliceRange,
                fullText: rawFullText,
                hoveredCommentId: hoveredCommentId
            )
        }

        // Revision highlights for Track Changes
        let currentRevisions = LettersDocumentController.active?.revisions ?? []
        let revsChanged = currentRevisions.count != context.coordinator.lastAppliedRevisionsCount
        if revsChanged {
            context.coordinator.lastAppliedRevisionsCount = currentRevisions.count
            Self.applyRevisionHighlights(
                to: textView.textStorage,
                sliceRange: sliceRange,
                fullText: rawFullText
            )
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
        paragraphSpacing: CGFloat,
        kern: CGFloat = 0.0,
        hangingIndent: CGFloat = 0.0,
        isContinuation: Bool = false,
        overrideAlignment: Bool = false,
        overrideFontFamily: Bool = true
    ) {
        let string = textStorage.string
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()

        let defaultFont = resolveFontNamed(family: fontFamily, size: baseFontSize, bold: isBold, italic: isItalic)
        let defaultTextColor = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)

        // Non-destructive update: preserve existing font sizes and manual styles
        textStorage.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            var newAttrs = attrs

            // 1. Update Paragraph Style
            let hasExistingParaStyle = attrs[.paragraphStyle] != nil
            let currentStyle = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            
            if overrideAlignment || !hasExistingParaStyle {
                switch alignment {
                case .leading: currentStyle.alignment = .left
                case .center: currentStyle.alignment = .center
                case .trailing: currentStyle.alignment = .right
                }
            }
            currentStyle.lineHeightMultiple = lineSpacing
            currentStyle.paragraphSpacing = paragraphSpacing
            currentStyle.paragraphSpacingBefore = paragraphSpacing * 0.5
            if hangingIndent > 0 {
                currentStyle.headIndent = hangingIndent
                
                // If this chunk is the continuation of a split paragraph, it should NOT have 
                // firstLineHeadIndent = 0. All lines of the continuation are indented.
                if isContinuation && range.location == 0 {
                    currentStyle.firstLineHeadIndent = hangingIndent
                } else {
                    currentStyle.firstLineHeadIndent = 0
                }
            }
            newAttrs[.paragraphStyle] = currentStyle

            // 2. Update Font Family, preserve size and traits
            if let currentFont = attrs[.font] as? NSFont {
                if overrideFontFamily {
                    let size = currentFont.pointSize
                    let traits = currentFont.fontDescriptor.symbolicTraits
                    
                    let isCurrentlyBold = traits.contains(.bold)
                    let isCurrentlyItalic = traits.contains(.italic)
                    
                    newAttrs[.font] = resolveFontNamed(family: fontFamily, size: size, bold: isCurrentlyBold, italic: isCurrentlyItalic)
                }
            } else {
                newAttrs[.font] = defaultFont
            }
            
            if attrs[.foregroundColor] == nil {
                newAttrs[.foregroundColor] = defaultTextColor
            }

            // 3. Apply kern (character tracking)
            if kern != 0 {
                newAttrs[.kern] = kern
            } else {
                newAttrs.removeValue(forKey: .kern)
            }

            textStorage.setAttributes(newAttrs, range: range)
        }

        textStorage.endEditing()
    }

    private static let commentHighlightKey = NSAttributedString.Key("StudioCommentHighlightKey")
    private static let revisionHighlightKey = NSAttributedString.Key("StudioRevisionHighlightKey")

    public static func applyRevisionHighlights(
        to textStorage: NSTextStorage?,
        sliceRange: NSRange?,
        fullText: String
    ) {
        guard let storage = textStorage, storage.length > 0 else { return }
        let fullLen = storage.length
        let fullStorageRange = NSRange(location: 0, length: fullLen)

        storage.beginEditing()
        storage.enumerateAttribute(revisionHighlightKey, in: fullStorageRange, options: []) { val, range, _ in
            if val != nil {
                storage.removeAttribute(revisionHighlightKey, range: range)
                storage.removeAttribute(.underlineStyle, range: range)
                storage.removeAttribute(.underlineColor, range: range)
            }
        }

        guard let doc = LettersDocumentController.active, doc.isTrackChangesEnabled, !doc.revisions.isEmpty else {
            storage.endEditing()
            return
        }

        let sliceOffset = sliceRange?.location ?? 0
        let nsFull = fullText as NSString

        for rev in doc.revisions {
            guard rev.kind == .insertion, !rev.text.isEmpty else { continue }
            var docRange: NSRange? = nil
            if let loc = rev.rangeLocation, loc + (rev.text as NSString).length <= nsFull.length {
                docRange = NSRange(location: loc, length: (rev.text as NSString).length)
            } else {
                let found = nsFull.range(of: rev.text)
                if found.location != NSNotFound {
                    docRange = found
                }
            }
            guard let validRange = docRange else { continue }
            let localRange: NSRange
            if let slice = sliceRange {
                let intersection = NSIntersectionRange(validRange, slice)
                guard intersection.length > 0 else { continue }
                localRange = NSRange(location: intersection.location - sliceOffset, length: intersection.length)
            } else {
                localRange = validRange
            }
            guard localRange.location + localRange.length <= storage.length else { continue }
            storage.addAttribute(revisionHighlightKey, value: rev.id.uuidString, range: localRange)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: localRange)
            storage.addAttribute(.underlineColor, value: NSColor.systemGreen, range: localRange)
        }
        storage.endEditing()
    }

    public static func applyCommentHighlights(
        to textStorage: NSTextStorage?,
        sliceRange: NSRange?,
        fullText: String,
        hoveredCommentId: UUID?
    ) {
        guard let storage = textStorage, storage.length > 0 else { return }
        let fullLen = storage.length
        let fullStorageRange = NSRange(location: 0, length: fullLen)

        storage.beginEditing()
        // 1. Clean previous dynamic comment highlights
        storage.enumerateAttribute(commentHighlightKey, in: fullStorageRange, options: []) { val, range, _ in
            if val != nil {
                storage.removeAttribute(commentHighlightKey, range: range)
                storage.removeAttribute(.backgroundColor, range: range)
                storage.removeAttribute(.underlineStyle, range: range)
                storage.removeAttribute(.underlineColor, range: range)
            }
        }

        // 2. Render active side notes
        guard let sideNotes = LettersDocumentController.active?.sideNotes, !sideNotes.isEmpty else {
            storage.endEditing()
            return
        }

        let nsFull = fullText as NSString
        let sliceOffset = sliceRange?.location ?? 0

        for sn in sideNotes {
            guard !sn.isResolved else { continue }
            var docRange: NSRange? = nil

            if let loc = sn.rangeLocation, let len = sn.rangeLength, len > 0, loc + len <= nsFull.length {
                docRange = NSRange(location: loc, length: len)
            } else if let anchor = sn.anchorText, !anchor.isEmpty {
                let found = nsFull.range(of: anchor)
                if found.location != NSNotFound {
                    docRange = found
                }
            }

            guard let validDocRange = docRange else { continue }

            let localRange: NSRange
            if let slice = sliceRange {
                let intersection = NSIntersectionRange(validDocRange, slice)
                guard intersection.length > 0 else { continue }
                localRange = NSRange(location: intersection.location - sliceOffset, length: intersection.length)
            } else {
                localRange = validDocRange
            }

            guard localRange.location + localRange.length <= storage.length else { continue }

            let isHovered = hoveredCommentId == sn.id
            if isHovered {
                storage.addAttribute(commentHighlightKey, value: sn.id.uuidString, range: localRange)
                storage.addAttribute(.backgroundColor, value: NSColor.systemOrange.withAlphaComponent(0.38), range: localRange)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: localRange)
                storage.addAttribute(.underlineColor, value: NSColor.systemOrange, range: localRange)
            } else {
                storage.addAttribute(commentHighlightKey, value: sn.id.uuidString, range: localRange)
                storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.20), range: localRange)
            }
        }

        storage.endEditing()
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
        var lastAppliedHoveredCommentId: UUID?
        var lastAppliedSideNotesCount: Int = -1
        var lastAppliedSideNotesResolvedCount: Int = -1
        var lastAppliedRevisionsCount: Int = -1

        init(_ parent: TextKit2EditorView) {
            self.parent = parent
            self.lastAppliedFontFamily = parent.fontFamily
            self.lastAppliedFontSize = parent.fontSize
            self.lastAppliedLineSpacing = parent.lineSpacing
            self.lastAppliedParagraphSpacing = parent.paragraphSpacing
            self.lastAppliedAlignment = parent.alignment
        }

        public func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard !isUpdatingProgrammatically else { return true }
            guard let doc = LettersDocumentController.active, doc.isTrackChangesEnabled else { return true }

            let ns = textView.string as NSString
            let repl = replacementString ?? ""
            let sliceOffset = self.parent.sliceRange?.location ?? 0
            let docLoc = sliceOffset + affectedCharRange.location

            if affectedCharRange.length > 0 && repl.isEmpty {
                // Deletion (Backspace, Delete key, Cut)
                if affectedCharRange.location + affectedCharRange.length <= ns.length {
                    let deletedText = ns.substring(with: affectedCharRange)
                    if !deletedText.isEmpty {
                        doc.recordRevision(kind: .deletion, text: "", originalText: deletedText, rangeLocation: docLoc, pageIndex: self.parent.pageIndex)
                    }
                }
            } else if affectedCharRange.length == 0 && !repl.isEmpty {
                // Insertion (Typing, Paste)
                doc.recordRevision(kind: .insertion, text: repl, originalText: nil, rangeLocation: docLoc, pageIndex: self.parent.pageIndex)
            } else if affectedCharRange.length > 0 && !repl.isEmpty {
                // Replacement of selected text
                if affectedCharRange.location + affectedCharRange.length <= ns.length {
                    let replacedText = ns.substring(with: affectedCharRange)
                    doc.recordRevision(kind: .insertion, text: repl, originalText: replacedText, rangeLocation: docLoc, pageIndex: self.parent.pageIndex)
                }
            }

            return true
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isUpdatingProgrammatically else { return }
            let string = textView.string
            let oldSliceRange = self.parent.sliceRange
            let oldRawFullText = self.parent.rawFullText

            // Sync rich text attributes back into the global richTextData BEFORE mutating parent.text
            if let storage = textView.textStorage {
                let immutableCopy = NSAttributedString(attributedString: storage)

                let baseFullDoc: NSMutableAttributedString
                if let rtf = self.parent.richTextData,
                   let fullDocObj = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: rtf),
                   fullDocObj.string == oldRawFullText {
                    baseFullDoc = NSMutableAttributedString(attributedString: fullDocObj)
                } else {
                    let baseFont = resolveFontNamed(family: self.parent.fontFamily, size: self.parent.fontSize, bold: self.parent.isBold, italic: self.parent.isItalic)
                    let baseParaStyle = NSMutableParagraphStyle()
                    switch self.parent.alignment {
                    case .leading: baseParaStyle.alignment = .left
                    case .center: baseParaStyle.alignment = .center
                    case .trailing: baseParaStyle.alignment = .right
                    }
                    baseParaStyle.lineHeightMultiple = self.parent.lineSpacing
                    baseParaStyle.paragraphSpacing = self.parent.paragraphSpacing
                    let fallbackStr = oldRawFullText.isEmpty ? self.parent.text : oldRawFullText
                    baseFullDoc = NSMutableAttributedString(string: fallbackStr, attributes: [
                        .font: baseFont,
                        .paragraphStyle: baseParaStyle
                    ])
                }

                if let range = oldSliceRange, range.location + range.length <= baseFullDoc.length {
                    baseFullDoc.replaceCharacters(in: range, with: immutableCopy)
                    if let newRtfData = try? NSKeyedArchiver.archivedData(withRootObject: baseFullDoc, requiringSecureCoding: false) {
                        self.parent.richTextData = newRtfData
                    }
                } else {
                    if let newRtfData = try? NSKeyedArchiver.archivedData(withRootObject: immutableCopy, requiringSecureCoding: false) {
                        self.parent.richTextData = newRtfData
                    }
                }
            }

            if self.parent.text != string {
                self.parent.text = string
            }
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isUpdatingProgrammatically else { return }
            let localRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let sub = localRange.length > 0 && localRange.location + localRange.length <= nsString.length ? nsString.substring(with: localRange) : ""
            let attrs = parent.controller?.currentSelectionAttributes() ?? EditorSelectionAttributes()
            
            let globalRange = NSRange(
                location: localRange.location + (self.parent.sliceRange?.location ?? 0), 
                length: localRange.length
            )

            if self.parent.selectionRange != globalRange {
                self.parent.selectionRange = globalRange
            }
            if self.parent.selectedText != sub {
                self.parent.selectedText = sub
            }
            self.parent.onSelectionChanged?(globalRange, sub, attrs)
        }
    }
}
