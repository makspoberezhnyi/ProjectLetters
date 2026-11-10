import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Native .letters package, import, export & print

extension MainEditorView {
    // MARK: - Native .letters / .ltt Lossless Package Save & Open
    func saveDocumentAsLetters() {
        let bundle = documentController.createBundle()

        guard let data = try? bundle.encodeToData() else {
            showToast("⚠️ Could not encode .letters bundle")
            return
        }

        // If already associated with a .letters or .ltt file on disk, save in-place immediately
        if let existingURL = documentController.currentFileURL {
            let ext = existingURL.pathExtension.lowercased()
            if ext == "letters" || ext == "ltt" {
                do {
                    try data.write(to: existingURL, options: .atomic)
                    documentController.markSaved(url: existingURL)
                    showToast("✓ Saved \(existingURL.lastPathComponent)")
                    return
                } catch {
                    showToast("⚠️ Failed to save: \(error.localizedDescription)")
                }
            }
        }

        let panel = NSSavePanel()
        panel.title = "Save Project Letters Document"
        panel.nameFieldStringValue = "\(documentController.title.replacingOccurrences(of: " ", with: "_")).letters"
        if let typeLetters = UTType(filenameExtension: "letters"),
           let typeLtt = UTType(filenameExtension: "ltt") {
            panel.allowedContentTypes = [typeLetters, typeLtt]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url, options: .atomic)
                documentController.markSaved(url: url)
                showToast("✓ Saved .letters package: \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write file: \(error.localizedDescription)")
            }
        }
    }

    func restoreAutosaveAction() {
        let shadowURL = LettersDocumentController.autosaveShadowURL
        guard FileManager.default.fileExists(atPath: shadowURL.path) else {
            showToast("⚠️ No autosave recovery snapshot found yet")
            return
        }
        do {
            let data = try Data(contentsOf: shadowURL)
            let bundle = try LettersDocumentBundle.decode(from: data)
            documentController.loadBundle(bundle)
            showToast("✓ Restored last autosave snapshot")
        } catch {
            showToast("⚠️ Failed to restore autosave: \(error.localizedDescription)")
        }
    }

    func extractImagesFromAttributedString(_ inputAttr: NSAttributedString) -> (NSAttributedString, [StudioImageBlock]) {
        let mutable = NSMutableAttributedString(attributedString: inputAttr)
        var extractedImages: [StudioImageBlock] = []
        var attachmentRanges: [(NSRange, StudioImageBlock)] = []

        let fullRange = NSRange(location: 0, length: mutable.length)
        if fullRange.length > 0 {
            mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
                guard let attachment = value as? NSTextAttachment else { return }
                var nsImg: NSImage? = attachment.image
                if nsImg == nil, let fileData = attachment.fileWrapper?.regularFileContents {
                    nsImg = NSImage(data: fileData)
                }
                if nsImg == nil, let contents = attachment.contents {
                    nsImg = NSImage(data: contents)
                }
                guard let validImg = nsImg,
                      let tiff = validImg.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let pngData = rep.representation(using: .png, properties: [:]) else {
                    return
                }
                let base64 = pngData.base64EncodedString()
                let block = StudioImageBlock(
                    base64Data: base64,
                    originalByteSize: pngData.count,
                    compressedByteSize: pngData.count,
                    caption: "Imported Figure \(extractedImages.count + 1)",
                    scaleWidthPercent: 85.0,
                    alignment: .center
                )
                extractedImages.append(block)
                attachmentRanges.append((range, block))
            }
        }

        // Replace attachment characters in reverse order with [[image:UUID]] markers
        for (range, block) in attachmentRanges.reversed() {
            let marker = "\n[[image:\(block.id.uuidString)]]\n"
            mutable.replaceCharacters(in: range, with: marker)
        }

        return (mutable, extractedImages)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.title = "Open Document"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let typeLetters = UTType(filenameExtension: "letters"),
           let typeLtt = UTType(filenameExtension: "ltt"),
           let typeDocx = UTType(filenameExtension: "docx"),
           let typeMd = UTType(filenameExtension: "md"),
           let typeTxt = UTType(filenameExtension: "txt") {
            panel.allowedContentTypes = [typeLetters, typeLtt, typeDocx, typeMd, typeTxt]
        }

        if panel.runModal() == .OK, let url = panel.url {
            openDocumentFromURL(url)
        }
    }

    func openDocumentFromURL(_ url: URL) {
        do {
            let ext = url.pathExtension.lowercased()
            if ext == "letters" || ext == "ltt" {
                let data = try Data(contentsOf: url)
                let bundle = try LettersDocumentBundle.decode(from: data)
                documentController.loadBundle(bundle)
                documentController.markSaved(url: url)
                showToast("✓ Opened .letters document: \(url.lastPathComponent)")
            } else if ext == "md" || ext == "txt" {
                let content = try String(contentsOf: url, encoding: .utf8)
                documentController.title = url.deletingPathExtension().lastPathComponent
                documentController.rawText = content
                documentController.richTextData = nil
                documentController.markSaved(url: url)
                showToast("✓ Opened file: \(url.lastPathComponent)")
            } else if ext == "docx" {
                let rawAttr = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.officeOpenXML], documentAttributes: nil)
                let (attrStr, extractedImages) = extractImagesFromAttributedString(rawAttr)
                documentController.title = url.deletingPathExtension().lastPathComponent
                if !extractedImages.isEmpty {
                    documentController.images.append(contentsOf: extractedImages)
                }
                documentController.rawText = attrStr.string
                if let data = try? NSKeyedArchiver.archivedData(withRootObject: attrStr, requiringSecureCoding: false) {
                    documentController.richTextData = data
                }
                documentController.markSaved(url: url)
                showToast("✓ Opened Word file natively: \(url.lastPathComponent)")
            }
        } catch {
            showToast("⚠️ Could not open document: \(error.localizedDescription)")
        }
    }

    func importWordOrPDF() {
        let panel = NSOpenPanel()
        panel.title = "Import Word or PDF"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let typeDocx = UTType(filenameExtension: "docx"),
           let typePdf = UTType(filenameExtension: "pdf") {
            panel.allowedContentTypes = [typeDocx, typePdf]
        }

        if panel.runModal() == .OK, let url = panel.url {
            importFileNatively(url: url)
        }
    }

    func importFileNatively(url: URL) {
        let ext = url.pathExtension.lowercased()
        do {
            if ext == "docx" {
                    let rawAttr = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.officeOpenXML], documentAttributes: nil)
                    let (attrStr, extractedImages) = extractImagesFromAttributedString(rawAttr)
                    if !extractedImages.isEmpty {
                        documentController.images.append(contentsOf: extractedImages)
                    }
                    
                    let text = attrStr.string
                    var finalAttrStr = attrStr
                    
                    if let oldData = documentController.richTextData, let oldAttr = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: oldData) {
                        let combined = NSMutableAttributedString(attributedString: oldAttr)
                        if selectionRange.location <= combined.length {
                            combined.replaceCharacters(in: selectionRange, with: attrStr)
                        } else {
                            if combined.length > 0 {
                                combined.append(NSAttributedString(string: "\n\n"))
                            }
                            combined.append(attrStr)
                        }
                        finalAttrStr = combined
                    }
                    
                    if let data = try? NSKeyedArchiver.archivedData(withRootObject: finalAttrStr, requiringSecureCoding: false) {
                        documentController.richTextData = data
                    }
                    
                    if selectionRange.location <= (documentController.rawText as NSString).length {
                        let ns = documentController.rawText as NSString
                        documentController.rawText = ns.replacingCharacters(in: selectionRange, with: text)
                    } else {
                        documentController.rawText += (documentController.rawText.isEmpty ? "" : "\n\n") + text
                    }
                    showToast("✓ Imported Word file natively: \(url.lastPathComponent)")
                } else if ext == "md" || ext == "txt" {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    if selectionRange.location <= (documentController.rawText as NSString).length {
                        let ns = documentController.rawText as NSString
                        documentController.rawText = ns.replacingCharacters(in: selectionRange, with: content)
                    } else {
                        documentController.rawText += (documentController.rawText.isEmpty ? "" : "\n\n") + content
                    }
                    showToast("✓ Imported text natively: \(url.lastPathComponent)")
                } else if ext == "pdf" {
                    if let pdf = PDFDocument(url: url), let text = pdf.string {
                        editorController.insertAtCaret(text)
                        showToast("✓ Imported PDF text from: \(url.lastPathComponent)")
                    } else {
                        showToast("⚠️ Could not extract text from PDF")
                    }
                }
            } catch {
                showToast("⚠️ Could not import file: \(error.localizedDescription)")
            }
        }

    // MARK: - Word, PDF & Print
    func buildExpandedMarkdownExport() -> String {
        var text = documentController.rawText
        var referencedTables = Set<UUID>()
        var referencedImages = Set<UUID>()
        var referencedVideos = Set<UUID>()

        for (idx, table) in documentController.tables.enumerated() {
            let marker = "[[table:\(table.id.uuidString)]]"
            let md = "\n\n" + table.toMarkdown() + "\n\n"
            if text.contains(marker) {
                text = text.replacingOccurrences(of: marker, with: md)
                referencedTables.insert(table.id)
            } else if idx == 0 && text.contains("[[table:budget]]") {
                text = text.replacingOccurrences(of: "[[table:budget]]", with: md)
                referencedTables.insert(table.id)
            }
        }

        for image in documentController.images {
            let marker = "[[image:\(image.id.uuidString)]]"
            if text.contains(marker) {
                text = text.replacingOccurrences(of: marker, with: "\n\n" + image.toMarkdown() + "\n\n")
                referencedImages.insert(image.id)
            }
        }

        for video in documentController.videos {
            let marker = "[[video:\(video.id.uuidString)]]"
            if text.contains(marker) {
                text = text.replacingOccurrences(of: marker, with: "\n\n" + video.toMarkdown() + "\n\n")
                referencedVideos.insert(video.id)
            }
        }

        if text.contains("[[toc]]") {
            var tocLines: [String] = ["## Table of Contents"]
            let regex = EditorPerformanceCache.shared.tocHeadingRegex
            let nsText = documentController.rawText as NSString
            var lineStart = 0
            for line in documentController.rawText.components(separatedBy: .newlines) {
                defer { lineStart += (line as NSString).length + 1 }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let pageNum = editorController.pageNumber(forCharacterOffset: min(lineStart, nsText.length))
                if trimmed.hasPrefix("# ") {
                    tocLines.append("- **\(trimmed.dropFirst(2))** (p. \(pageNum))")
                } else if trimmed.hasPrefix("## ") {
                    tocLines.append("  - \(trimmed.dropFirst(3)) (p. \(pageNum))")
                } else if trimmed.hasPrefix("### ") {
                    tocLines.append("    - \(trimmed.dropFirst(4)) (p. \(pageNum))")
                } else {
                    let ns = trimmed as NSString
                    if let m = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: ns.length)), m.range.location != NSNotFound {
                        tocLines.append("- \(trimmed) (p. \(pageNum))")
                    }
                }
            }
            text = text.replacingOccurrences(of: "[[toc]]", with: "\n\n" + tocLines.joined(separator: "\n") + "\n\n")
        }

        if text.contains("[[bibliography]]") {
            let sortedSources = documentController.document.sources.values.sorted {
                ($0.authors.first ?? $0.title).localizedCaseInsensitiveCompare($1.authors.first ?? $1.title) == .orderedAscending
            }
            var bibLines: [String] = ["## References"]
            for source in sortedSources {
                let authors = (source.authors.isEmpty ? [source.title] : source.authors).joined(separator: ", ")
                let yearStr = source.year.map { String($0) } ?? "n.d."
                bibLines.append("- \(authors) (\(yearStr)). *\(source.title)*. [\(source.sourceType.rawValue.capitalized)].")
            }
            text = text.replacingOccurrences(of: "[[bibliography]]", with: "\n\n" + bibLines.joined(separator: "\n") + "\n\n")
        }

        text = text.replacingOccurrences(of: "---pagebreak---", with: "\n\n---\n\n")

        let unrefTables = documentController.tables.filter { !referencedTables.contains($0.id) }
        if !unrefTables.isEmpty {
            text += "\n\n" + unrefTables.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        let unrefImages = documentController.images.filter { !referencedImages.contains($0.id) }
        if !unrefImages.isEmpty {
            text += "\n\n" + unrefImages.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        let unrefVideos = documentController.videos.filter { !referencedVideos.contains($0.id) }
        if !unrefVideos.isEmpty {
            text += "\n\n" + unrefVideos.map { $0.toMarkdown() }.joined(separator: "\n\n")
        }
        if !documentController.footnotes.isEmpty {
            var fnLines: [String] = ["### Footnotes"]
            for fn in documentController.footnotes {
                fnLines.append("[\(fn.referenceMarker)] \(fn.text)")
            }
            text += "\n\n" + fnLines.joined(separator: "\n")
        }

        return text
    }

    /// Vector PDF of the live canvas: one page per sheet, with the same fonts, headers and footers
    /// the writer sees (guides and seam labels are suppressed while exporting).
    func renderMultiPagePDFData() -> Data? {
        editorController.flushPendingEdits()
        return editorController.textView?.exportPDFData()
    }

    func buildRichAttributedStringForDocxExport() -> NSAttributedString {
        let baseFont = resolveFontNamed(family: documentController.fontFamily, size: documentController.fontSize, bold: isBold, italic: isItalic)
        let baseParaStyle = NSMutableParagraphStyle()
        switch documentController.textAlignment {
        case .leading: baseParaStyle.alignment = .left
        case .center: baseParaStyle.alignment = .center
        case .trailing: baseParaStyle.alignment = .right
        }
        baseParaStyle.lineHeightMultiple = documentController.lineSpacing
        baseParaStyle.paragraphSpacing = documentController.paragraphSpacing
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .paragraphStyle: baseParaStyle,
            .foregroundColor: NSColor.black
        ]

        let attrStr: NSMutableAttributedString
        if let data = documentController.richTextData,
           let unarchived = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data),
           unarchived.string == documentController.rawText {
            attrStr = NSMutableAttributedString(attributedString: unarchived)
            let fullRange = NSRange(location: 0, length: attrStr.length)
            if fullRange.length > 0 {
                attrStr.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, subRange, _ in
                    let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                    style.lineHeightMultiple = documentController.lineSpacing
                    style.paragraphSpacing = documentController.paragraphSpacing
                    attrStr.addAttribute(.paragraphStyle, value: style, range: subRange)
                }
            }
        } else {
            attrStr = NSMutableAttributedString(string: documentController.rawText, attributes: defaultAttrs)
        }

        func replaceMarker(_ marker: String, with replacement: String) {
            while true {
                let range = (attrStr.string as NSString).range(of: marker)
                if range.location == NSNotFound { break }
                let existingAttrs = range.location < attrStr.length
                    ? attrStr.attributes(at: range.location, effectiveRange: nil)
                    : defaultAttrs
                let repAttr = NSAttributedString(string: replacement, attributes: existingAttrs)
                attrStr.replaceCharacters(in: range, with: repAttr)
            }
        }

        func replaceMarkerWithAttributed(_ marker: String, with replacement: NSAttributedString) {
            while true {
                let range = (attrStr.string as NSString).range(of: marker)
                if range.location == NSNotFound { break }
                attrStr.replaceCharacters(in: range, with: replacement)
            }
        }

        for (idx, table) in documentController.tables.enumerated() {
            let marker = "[[table:\(table.id.uuidString)]]"
            let tableAttr = buildNativeTextTableAttributedString(from: table, baseFont: baseFont)
            replaceMarkerWithAttributed(marker, with: tableAttr)
            if idx == 0 {
                replaceMarkerWithAttributed("[[table:budget]]", with: tableAttr)
            }
        }
        for image in documentController.images {
            let marker = "[[image:\(image.id.uuidString)]]"
            if let data = Data(base64Encoded: image.base64Data),
               let nsImg = NSImage(data: data) {
                let attachment = NSTextAttachment()
                attachment.image = nsImg
                let imgAttr = NSMutableAttributedString(string: "\n")
                imgAttr.append(NSAttributedString(attachment: attachment))
                if !image.caption.isEmpty {
                    let capStyle = NSMutableParagraphStyle()
                    capStyle.alignment = .center
                    let capFont = resolveFontNamed(family: documentController.fontFamily, size: 11, bold: false, italic: true)
                    imgAttr.append(NSAttributedString(string: "\n\(image.caption)\n", attributes: [
                        .font: capFont,
                        .paragraphStyle: capStyle,
                        .foregroundColor: NSColor.darkGray
                    ]))
                } else {
                    imgAttr.append(NSAttributedString(string: "\n"))
                }
                replaceMarkerWithAttributed(marker, with: imgAttr)
            } else {
                replaceMarker(marker, with: "\n\n" + image.toMarkdown() + "\n\n")
            }
        }
        for video in documentController.videos {
            replaceMarker("[[video:\(video.id.uuidString)]]", with: "\n\n" + video.toMarkdown() + "\n\n")
        }
        replaceMarker("---pagebreak---", with: "\n\u{000C}\n")

        return attrStr
    }

    func buildNativeTextTableAttributedString(from tableData: StudioTableData, baseFont: NSFont) -> NSAttributedString {
        let numCols = max(1, tableData.headers.count)
        let textTable = NSTextTable()
        textTable.numberOfColumns = numCols
        textTable.collapsesBorders = true
        textTable.hidesEmptyCells = false

        let result = NSMutableAttributedString(string: "\n", attributes: [.font: baseFont])
        let headerFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)

        func appendCell(text: String, row: Int, col: Int, isHeader: Bool) {
            let block = NSTextTableBlock(table: textTable, startingRow: row, rowSpan: 1, startingColumn: col, columnSpan: 1)
            block.setWidth(1.0, type: .absoluteValueType, for: .border)
            block.setBorderColor(NSColor.gray.withAlphaComponent(0.5))
            block.setWidth(4.0, type: .absoluteValueType, for: .padding)
            if isHeader {
                block.backgroundColor = NSColor(white: 0.94, alpha: 1.0)
            }
            let paraStyle = NSMutableParagraphStyle()
            paraStyle.textBlocks = [block]
            let cellStr = (text.isEmpty ? " " : text) + "\n"
            let cellAttr = NSAttributedString(string: cellStr, attributes: [
                .font: isHeader ? headerFont : baseFont,
                .paragraphStyle: paraStyle,
                .foregroundColor: NSColor.black
            ])
            result.append(cellAttr)
        }

        for col in 0..<numCols {
            let hText = col < tableData.headers.count ? tableData.headers[col] : ""
            appendCell(text: hText, row: 0, col: col, isHeader: true)
        }

        for (rIdx, row) in tableData.rows.enumerated() {
            for col in 0..<numCols {
                let evaluated = tableData.evaluatedCell(row: rIdx + 1, col: col)
                let fallback = col < row.count ? row[col] : ""
                let cellText = evaluated.isEmpty ? fallback : evaluated
                appendCell(text: cellText, row: rIdx + 1, col: col, isHeader: false)
            }
        }

        result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont]))
        return result
    }

    func saveDocumentAsDocx() {
        let richAttr = buildRichAttributedStringForDocxExport()
        let fullRange = NSRange(location: 0, length: richAttr.length)

        var exportedData: Data? = nil
        if fullRange.length > 0 {
            exportedData = try? richAttr.data(
                from: fullRange,
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.officeOpenXML,
                    .title: documentController.title
                ]
            )
        }
        if exportedData == nil {
            let fullExport = buildExpandedMarkdownExport()
            exportedData = CoreBridge.shared.exportDocx(title: documentController.title, text: fullExport)
        }

        guard let docxData = exportedData else {
            showToast("⚠️ Could not generate DOCX")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Word Document"
        panel.nameFieldStringValue = "\(documentController.title.replacingOccurrences(of: " ", with: "_")).docx"
        if let type = UTType(filenameExtension: "docx") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try docxData.write(to: url)
                showToast("✓ Saved \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write file: \(error.localizedDescription)")
            }
        }
    }

    func exportDocumentAsPDF() {
        let panel = NSSavePanel()
        panel.title = "Export Vector PDF"
        panel.nameFieldStringValue = "\(documentController.title.replacingOccurrences(of: " ", with: "_")).pdf"
        if let type = UTType(filenameExtension: "pdf") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            guard let pdfData = renderMultiPagePDFData() else {
                showToast("⚠️ Could not render PDF")
                return
            }

            do {
                try pdfData.write(to: url)
                showToast("✓ Exported Vector PDF (\(editorController.pageCount) pages): \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write PDF: \(error.localizedDescription)")
            }
        }
    }

    func printDocument() {
        let paperSize = NSSize(width: currentSheetWidth, height: currentSheetHeight)
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = paperSize
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.orientation = .portrait

        if let pdfData = renderMultiPagePDFData(),
           let pdfDoc = PDFDocument(data: pdfData),
           let op = pdfDoc.printOperation(for: printInfo, scalingMode: .pageScaleNone, autoRotate: false) {
            op.showsPrintPanel = true
            op.run()
            return
        }

        let textView = NSTextView(frame: NSRect(origin: .zero, size: paperSize))
        textView.string = documentController.rawText
        textView.font = resolveFontNamed(family: documentController.fontFamily, size: documentController.fontSize, bold: isBold, italic: isItalic)

        let op = NSPrintOperation(view: textView, printInfo: printInfo)
        op.showsPrintPanel = true
        op.run()
    }

    func saveDocumentAsMarkdown() {
        let fullExport = buildExpandedMarkdownExport()

        let panel = NSSavePanel()
        panel.title = "Save Markdown"
        panel.nameFieldStringValue = "\(documentController.title.replacingOccurrences(of: " ", with: "_")).md"
        if let type = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [type]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try fullExport.write(to: url, atomically: true, encoding: .utf8)
                showToast("✓ Saved \(url.lastPathComponent)")
            } catch {
                showToast("⚠️ Failed to write file: \(error.localizedDescription)")
            }
        }
    }
}
