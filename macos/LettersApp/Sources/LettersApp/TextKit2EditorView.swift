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
    public var isKeepLinesTogether: Bool
    public var isKeepWithNext: Bool
    public var alignment: TextAlignment

    public init(
        fontFamily: String = "Default Serif (Georgia)",
        fontSize: CGFloat = 15.0,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isKeepLinesTogether: Bool = false,
        isKeepWithNext: Bool = false,
        alignment: TextAlignment = .leading
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isKeepLinesTogether = isKeepLinesTogether
        self.isKeepWithNext = isKeepWithNext
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

    public var onSelectAllRequested: (() -> Void)?
    public var onImportFile: ((URL) -> Void)?

    public func selectAllPages() {
        onSelectAllRequested?()
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

        return EditorSelectionAttributes(
            fontFamily: fam,
            fontSize: validFont.pointSize > 0 ? validFont.pointSize : 15.0,
            isBold: bold,
            isItalic: italic,
            isUnderline: isUnderlined,
            isKeepLinesTogether: isKeepLinesTogether,
            isKeepWithNext: isKeepWithNext,
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
        guard let textView = textView, let textStorage = textView.textStorage else { return }
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
    public var showLineNumbers: Bool = false

    public override var isFlipped: Bool { true }



    public override func selectAll(_ sender: Any?) {
        actionController?.selectAllPages()
    }

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

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            var handled = false
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ext == "docx" || ext == "pdf" || ext == "txt" || ext == "md" {
                    actionController?.onImportFile?(url)
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
    @Binding var richTextData: Data?
    @Binding var selectedText: String
    @Binding var selectionRange: NSRange
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
    var onSelectionChanged: ((NSRange, String, EditorSelectionAttributes) -> Void)?
    var exclusionPaths: [NSBezierPath] = []

    public init(
        text: Binding<String>,
        richTextData: Binding<Data?> = .constant(nil),
        selectedText: Binding<String>,
        selectionRange: Binding<NSRange>,
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
        onSelectionChanged: ((NSRange, String, EditorSelectionAttributes) -> Void)? = nil,
        exclusionPaths: [NSBezierPath] = []
    ) {
        self._text = text
        self._richTextData = richTextData
        self._selectedText = selectedText
        self._selectionRange = selectionRange
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
        if textView.string != text || typographyChanged {
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
                        isContinuation: isContinuation
                    )
                }
            }
            context.coordinator.lastAppliedFontFamily = fontFamily
            context.coordinator.lastAppliedFontSize = fontSize
            context.coordinator.lastAppliedLineSpacing = lineSpacing
            context.coordinator.lastAppliedParagraphSpacing = paragraphSpacing
            context.coordinator.lastAppliedAlignment = alignment
            context.coordinator.isUpdatingProgrammatically = false
        }

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
        } else {
            // Keep existing selection if not slicing
        }
        context.coordinator.isUpdatingProgrammatically = false
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
        isContinuation: Bool = false
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
            let currentStyle = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            
            switch alignment {
            case .leading: currentStyle.alignment = .left
            case .center: currentStyle.alignment = .center
            case .trailing: currentStyle.alignment = .right
            }
            currentStyle.lineHeightMultiple = lineSpacing
            currentStyle.paragraphSpacing = paragraphSpacing
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
                let size = currentFont.pointSize
                let traits = currentFont.fontDescriptor.symbolicTraits
                
                let isCurrentlyBold = traits.contains(.bold)
                let isCurrentlyItalic = traits.contains(.italic)
                
                newAttrs[.font] = resolveFontNamed(family: fontFamily, size: size, bold: isCurrentlyBold, italic: isCurrentlyItalic)
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
            
            // If we are editing rich text, update the global richTextData
            if let storage = textView.textStorage, self.parent.attributedText != nil, let rtf = self.parent.richTextData {
                if let fullDocObj = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: rtf),
                   let range = self.parent.sliceRange {
                    
                    let fullDoc = NSMutableAttributedString(attributedString: fullDocObj)
                    // Replace the chunk in the global document with the edited text storage
                    if range.location + range.length <= fullDoc.length {
                        fullDoc.replaceCharacters(in: range, with: storage)
                        
                        // Re-encode back to richTextData
                        if let newRtfData = try? NSKeyedArchiver.archivedData(withRootObject: fullDoc, requiringSecureCoding: false) {
                            self.parent.richTextData = newRtfData
                        }
                    }
                }
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
import AppKit
import SwiftUI
import Foundation
#if canImport(LettersKit)
import LettersKit
#endif

