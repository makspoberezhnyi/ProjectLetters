import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Editing actions & selection mutation

extension MainEditorView {
    var unreferencedTableIndices: [Int] {
        documentController.tables.indices.filter { idx in
            let idStr = documentController.tables[idx].id.uuidString
            let hasBudgetMarker = (idx == 0 && documentController.rawText.contains("[[table:budget]]"))
            return !documentController.rawText.contains("[[table:\(idStr)]]") && !hasBudgetMarker
        }
    }

    var unreferencedImageIndices: [Int] {
        documentController.images.indices.filter { idx in
            let idStr = documentController.images[idx].id.uuidString
            return !documentController.rawText.contains("[[image:\(idStr)]]")
        }
    }

    var unreferencedVideoIndices: [Int] {
        documentController.videos.indices.filter { idx in
            let idStr = documentController.videos[idx].id.uuidString
            return !documentController.rawText.contains("[[video:\(idStr)]]")
        }
    }

    // MARK: - Actions
    func newDocumentAction() {
        documentController.title = "Untitled Document"
        documentController.rawText = ""
        documentController.richTextData = nil
        documentController.tables = []
        documentController.images = []
        documentController.videos = []
        documentController.floatingElements = []
        documentController.footnotes = []
        documentController.sideNotes = []
        documentController.document.sources = [:]
        selectionAttributes = nil
        showToast("✓ Created New Document")
    }

    enum StudioTool {
        case select, text, table, image, citation, style, copilot, pan
    }

    func handleToolAction(_ tool: StudioTool) {
        switch tool {
        case .select:
            showToast("✓ Selection Tool active")
        case .text:
            documentController.rawText += "\n\nNew Section Heading\nType section body text here..."
            showToast("✓ Inserted Text Section")
        case .table:
            let newTable = StudioTableData(
                title: "",
                headers: ["", "", "", ""],
                rows: [
                    ["", "", "", ""],
                    ["", "", "", ""],
                    ["", "", "", ""]
                ]
            )

            let marker = "\n\n[[table:\(newTable.id.uuidString)]]\n\n"
            editorController.insertAtCaret(marker)
            // Append table AFTER modifying rawText so they are part of the same frame
            documentController.tables.append(newTable)
            documentController.commitSnapshot(actionName: "Insert Table", isMilestone: true)
            showToast("✓ Added Table with cell formula support")
        case .image:
            insertImageAction()
        case .citation:
            showingAddSourceSheet = true
            showToast("✓ Add Linked Citation")
        case .style:
            runLinter()
            showToast("✓ Scanned style rules: \(lintIssues.count) notices found")
        case .copilot:
            showAIDrawer.toggle()
            showToast("✓ AI Assistant toggled")
        case .pan:
            showToast("✓ Hand Pan tool active")
        }
    }

    func insertImageAction() {
        StudioImageView.pickImageFromDisk { block in
            if let block = block {
                documentController.images.append(block)
                let marker = "\n\n[[image:\(block.id.uuidString)]]\n\n"
                editorController.insertAtCaret(marker)
                showToast("✓ Inserted Image Figure")
            }
        }
    }

    func insertPageBreakAction() {
        editorController.insertAtCaret("\n\n---pagebreak---\n\n")
        showToast("✓ Inserted Page Break")
    }

    func insertTOCAction() {
        let marker = "\n\n[[toc]]\n\n"
        editorController.insertAtCaret(marker)
        showToast("✓ Inserted Table of Contents")
    }

    func insertBibliographyAction() {
        let marker = "\n\n[[bibliography]]\n\n"
        editorController.insertAtCaret(marker)
        showToast("✓ Inserted Bibliography / Works Cited")
    }

    func toggleStrikethroughAction() {
        editorController.toggleStrikethrough()
        showToast("✓ Strikethrough toggled")
    }

    func applyParagraphStyleAction(_ preset: DocumentParagraphStyle) {
        let fam = selectionAttributes?.fontFamily ?? documentController.fontFamily
        editorController.applyParagraphStyle(
            preset,
            fontFamily: fam,
            lineSpacing: documentController.lineSpacing,
            paragraphSpacing: documentController.paragraphSpacing
        )
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        showToast("✓ Applied Style: \(preset.rawValue)")
    }

    func insertSectionHeadingAction(level: Int = 1, customTitle: String? = nil) {
        if let customTitle = customTitle {
            let hashes = String(repeating: "#", count: max(1, min(6, level)))
            let item = "\(hashes) \(customTitle)"
            if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
                let ns = documentController.rawText as NSString
                documentController.rawText = ns.replacingCharacters(in: selectionRange, with: item)
            } else {
                documentController.rawText = documentController.rawText.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + item
            }
        }
        let preset: DocumentParagraphStyle = (level == 1) ? .heading1 : (level == 2 ? .heading2 : .heading3)
        applyParagraphStyleAction(preset)
    }

    func insertChecklistAction() {
        let item = "\n- [ ] Task item\n"
        editorController.insertAtCaret(item)
        showToast("✓ Inserted Checklist Item")
    }

    func insertBlockquoteAction() {
        let item = "\n> Quoted text block\n"
        editorController.insertAtCaret(item)
        showToast("✓ Inserted Blockquote")
    }

    func insertCodeBlockAction() {
        let item = "\n```swift\n// Code snippet\n```\n"
        editorController.insertAtCaret(item)
        showToast("✓ Inserted Code Block")
    }

    func insertDividerAction() {
        let item = "\n\n---\n\n"
        editorController.insertAtCaret(item)
        showToast("✓ Inserted Horizontal Divider")
    }

    func insertDateTimeAction() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let str = formatter.string(from: Date())
        editorController.insertAtCaret(str)
        showToast("✓ Inserted Date/Time: \(str)")
    }

    func transformTextSelection(mode: String) {
        guard !selectedText.isEmpty else {
            showToast("⚠️ Select text first to transform case")
            return
        }
        let transformed: String
        switch mode {
        case "upper": transformed = selectedText.uppercased()
        case "lower": transformed = selectedText.lowercased()
        case "capitalized": transformed = selectedText.capitalized
        default: transformed = selectedText
        }
        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: transformed)
        } else {
            documentController.rawText = documentController.rawText.replacingOccurrences(of: selectedText, with: transformed)
        }
        showToast("✓ Transformed Text: \(mode)")
    }

    func setLineSpacingAction(_ spacing: CGFloat) {
        documentController.lineSpacing = spacing
        editorController.applyLineSpacing(spacing, paragraphSpacing: documentController.paragraphSpacing)
        showToast("✓ Line Spacing: \(String(format: "%.2g", spacing))")
    }

    func setParagraphSpacingAction(_ spacing: CGFloat) {
        documentController.paragraphSpacing = spacing
        editorController.applyLineSpacing(documentController.lineSpacing, paragraphSpacing: spacing)
        showToast("✓ Paragraph Spacing: \(Int(spacing)) pt")
    }

    func insertBulletListAction() {
        editorController.toggleBulletList()
        showToast("✓ Toggled Bulleted List")
    }

    func insertNumberedListAction() {
        editorController.toggleNumberedList()
        showToast("✓ Toggled Numbered List")
    }

    func toggleBoldAction() {
        editorController.toggleBold()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isBold ? "✓ Bold enabled" : "Bold disabled")
        } else {
            isBold.toggle()
            showToast(isBold ? "✓ Bold enabled" : "Bold disabled")
        }
    }

    func setTextColorAction(_ color: NSColor) {
        editorController.setTextColor(color)
        showToast("✓ Text color applied")
    }

    func setTextHighlightAction(_ color: NSColor?) {
        editorController.setTextHighlight(color)
        showToast(color == nil ? "✓ Highlight removed" : "✓ Text highlighted")
    }

    func clearFormattingAction() {
        editorController.clearFormatting()
        showToast("✓ Formatting cleared (Reset to Black)")
    }

    func toggleKeepLinesTogetherAction() {
        editorController.toggleKeepLinesTogether()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isKeepLinesTogether ? "✓ Keep Lines Together enabled" : "Keep Lines Together disabled")
        }
    }

    func toggleKeepWithNextAction() {
        editorController.toggleKeepWithNext()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isKeepWithNext ? "✓ Keep With Next enabled" : "Keep With Next disabled")
        }
    }

    func toggleItalicAction() {
        editorController.toggleItalic()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isItalic ? "✓ Italic enabled" : "Italic disabled")
        } else {
            isItalic.toggle()
            showToast(isItalic ? "✓ Italic enabled" : "Italic disabled")
        }
    }

    func toggleUnderlineAction() {
        editorController.toggleUnderline()
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
            showToast(attrs.isUnderline ? "✓ Underline enabled" : "Underline disabled")
        } else {
            isUnderline.toggle()
            showToast(isUnderline ? "✓ Underline enabled" : "Underline disabled")
        }
    }

    func setAlignmentAction(_ align: TextAlignment) {
        if selectionRange.length == 0 && (documentController.rawText as NSString).length == 0 {
            documentController.textAlignment = align
        }
        editorController.applyAlignment(align, lineSpacing: documentController.lineSpacing, paragraphSpacing: documentController.paragraphSpacing)
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        let name = align == .leading ? "Left" : align == .center ? "Center" : "Right"
        showToast("✓ Alignment: \(name)")
    }

    func setFontFamilyAction(_ font: String) {
        let sizeToApply = selectionAttributes?.fontSize ?? documentController.fontSize
        editorController.applyFontFamily(font, size: sizeToApply)
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        showToast("✓ Font: \(font)")
    }

    func setFontSizeAction(_ size: CGFloat) {
        editorController.applyFontSize(size)
        if let attrs = editorController.currentSelectionAttributes() {
            self.selectionAttributes = attrs
        }
        showToast("✓ Font Size: \(Int(size)) pt")
    }

    func insertCitationForSelection() {
        showingAddSourceSheet = true
    }

    func insertFootnote() {
        let fnNumber = documentController.footnotes.count + 1
        let footnoteId = UUID()
        let marker = "\(fnNumber)"
        
        // Add model
        documentController.footnotes.append(StudioFootnote(id: footnoteId, referenceMarker: marker, text: "New Footnote Text"))
        
        // Insert into text
        let refStr = "[\(marker)]"
        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            let replaced = ns.replacingCharacters(in: selectionRange, with: refStr)
            documentController.rawText = replaced
        } else {
            // Append to current location if cursor is available, else append to end
            documentController.rawText += refStr
        }
        
        documentController.commitSnapshot(actionName: "Insert Footnote", isMilestone: false)
    }

    func insertCrossReference(targetId: String, type: String) {
        if documentController.richTextData == nil {
            let attrStr = NSAttributedString(string: documentController.rawText)
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: attrStr, requiringSecureCoding: false) {
                documentController.richTextData = data
            }
        }
        
        let attachment = CrossReferenceAttachment(targetId: targetId, targetType: type)
        editorController.insertAttachment(attachment)
        documentController.commitSnapshot(actionName: "Insert Cross Reference", isMilestone: false)
    }

    func insertSideNote() {
        let snNumber = documentController.sideNotes.count + 1
        let snId = UUID()
        let marker = "note:\(snNumber)"

        // Non-destructive: extract anchor text snippet and range from selection
        var anchorSnippet: String? = nil
        let ns = documentController.rawText as NSString
        let hasSelection = selectionRange.length > 0 && selectionRange.location + selectionRange.length <= ns.length
        if hasSelection {
            anchorSnippet = ns.substring(with: selectionRange)
        }

        documentController.sideNotes.append(
            StudioSideNote(
                id: snId,
                referenceMarker: marker,
                text: "Comment...",
                anchorText: anchorSnippet,
                rangeLocation: hasSelection ? selectionRange.location : nil,
                rangeLength: hasSelection ? selectionRange.length : nil,
                author: NSFullUserName().isEmpty ? "Reviewer" : NSFullUserName(),
                createdAt: Date(),
                isResolved: false
            )
        )

        // Document text stays 100% clean and pristine (no ugly [note:N] injected!)
        documentController.commitSnapshot(actionName: "Insert Margin Comment", isMilestone: false)
        showToast("💬 Added comment on selection")
    }

    func figureNumber(for imgId: UUID) -> Int {
        (documentController.images.firstIndex(where: { $0.id == imgId }) ?? 0) + 1
    }

    func replaceSelection(with newText: String) {
        if documentController.isTrackChangesEnabled {
            documentController.recordRevision(
                kind: .insertion,
                text: newText,
                originalText: selectedText.isEmpty ? nil : selectedText,
                author: "AI Assistant"
            )
        }
        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: newText)
        } else if !selectedText.isEmpty && documentController.rawText.contains(selectedText) {
            documentController.rawText = documentController.rawText.replacingOccurrences(of: selectedText, with: newText)
        } else {
            documentController.rawText += "\n\n" + newText
        }
        selectedText = ""
        selectionRange = NSRange(location: 0, length: 0)
        showToast("✓ Applied AI changes to canvas")
    }

    func insertBelowSelection(newText: String) {
        if documentController.isTrackChangesEnabled {
            documentController.recordRevision(
                kind: .insertion,
                text: newText,
                originalText: nil,
                author: "AI Assistant"
            )
        }
        if selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
            let ns = documentController.rawText as NSString
            let insertPos = selectionRange.location + selectionRange.length
            let head = ns.substring(to: insertPos)
            let tail = ns.substring(from: insertPos)
            documentController.rawText = head + "\n\n" + newText + tail
        } else if !selectedText.isEmpty, let range = documentController.rawText.range(of: selectedText) {
            documentController.rawText.insert(contentsOf: "\n\n" + newText, at: range.upperBound)
        } else {
            documentController.rawText += "\n\n" + newText
        }
        selectedText = ""
        selectionRange = NSRange(location: 0, length: 0)
        showToast("✓ Inserted AI content below selection")
    }

    func applyLintFix(_ issue: StyleLintMatch) {
        guard let suggestion = issue.suggestion, !suggestion.isEmpty else { return }
        let ns = documentController.rawText as NSString
        guard issue.spanStart >= 0, issue.spanEnd <= ns.length, issue.spanStart <= issue.spanEnd else { return }
        let range = NSRange(location: issue.spanStart, length: issue.spanEnd - issue.spanStart)
        let oldSnippet = ns.substring(with: range)
        if documentController.isTrackChangesEnabled {
            documentController.recordRevision(
                kind: .insertion,
                text: suggestion,
                originalText: oldSnippet,
                author: "Style Linter"
            )
        }

        // Update richTextData synchronously so formatting is never lost across the document
        if let data = documentController.richTextData,
           let richDoc = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data),
           richDoc.length == ns.length {
            let mutableRich = NSMutableAttributedString(attributedString: richDoc)
            let existingAttrs = range.length > 0 ? richDoc.attributes(at: range.location, effectiveRange: nil) : [:]
            let replacementAttrStr = NSAttributedString(string: suggestion, attributes: existingAttrs)
            mutableRich.replaceCharacters(in: range, with: replacementAttrStr)
            if let updatedData = try? NSKeyedArchiver.archivedData(withRootObject: mutableRich, requiringSecureCoding: false) {
                documentController.richTextData = updatedData
            }
        }

        let replaced = ns.replacingCharacters(in: range, with: suggestion)
        documentController.rawText = replaced
        documentController.commitSnapshot(actionName: "Apply Fix: \(issue.ruleId)", isMilestone: false)
        runLinter()
        showToast("✓ Applied fix: \(suggestion)")
    }
}
