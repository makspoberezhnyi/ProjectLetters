import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Command palette, direct CLI commands, AI context & linter

extension MainEditorView {
    func executeDirectCLICommand(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()

        // 1. Font Size (e.g. "size 24", "font 18", "pt 14")
        if lower.hasPrefix("size ") || lower.hasPrefix("font ") || lower.hasPrefix("pt ") {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let pt = Double(parts[1]), pt >= 6 && pt <= 144 {
                setFontSizeAction(CGFloat(pt))
                return true
            }
        }

        // 2. Font Family (e.g. "font georgia", "font sf pro", "font times")
        if lower.hasPrefix("font ") {
            let arg = lower.replacingOccurrences(of: "font ", with: "").trimmingCharacters(in: .whitespaces)
            if arg.contains("georgia") { setFontFamilyAction("Default Serif (Georgia)"); return true }
            if arg.contains("times") { setFontFamilyAction("Times New Roman"); return true }
            if arg.contains("sf") || arg.contains("san") { setFontFamilyAction("SF Pro"); return true }
            if arg.contains("helvetica") { setFontFamilyAction("Helvetica"); return true }
            if arg.contains("charter") { setFontFamilyAction("Charter"); return true }
            if arg.contains("menlo") || arg.contains("mono") { setFontFamilyAction("Menlo (Monospace)"); return true }
            if arg.contains("courier") { setFontFamilyAction("Courier"); return true }
        }

        // 3. Zoom (e.g. "zoom 125", "zoom 100")
        if lower.hasPrefix("zoom ") {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let z = Double(parts[1]), z >= 25 && z <= 500 {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = CGFloat(z / 100.0)
                }
                showToast("✓ Zoom: \(Int(z))%")
                return true
            }
        }

        // 4. Margins (e.g. "documentController.margins narrow", "documentController.margins standard", "margin 0.5")
        if lower.hasPrefix("margin") {
            if lower.contains("narrow") { documentController.marginPreset = .narrow; showToast("✓ Margins: Narrow"); return true }
            if lower.contains("wide") { documentController.marginPreset = .wide; showToast("✓ Margins: Wide"); return true }
            if lower.contains("moderate") { documentController.marginPreset = .moderate; showToast("✓ Margins: Moderate"); return true }
            if lower.contains("standard") || lower.contains("normal") { documentController.marginPreset = .normal; showToast("✓ Margins: Normal"); return true }
        }

        // 5. Page Size (e.g. "page a4", "page letter", "page legal")
        if lower.hasPrefix("page ") {
            if lower.contains("a4") { documentController.pageSize = .a4; showToast("✓ Page Size: A4"); return true }
            if lower.contains("letter") { documentController.pageSize = .letter; showToast("✓ Page Size: US Letter"); return true }
            if lower.contains("legal") { documentController.pageSize = .legal; showToast("✓ Page Size: US Legal"); return true }
            if lower.contains("exec") { documentController.pageSize = .executive; showToast("✓ Page Size: Executive"); return true }
        }

        // 6. Line Spacing (e.g. "line 1.5", "spacing 2", "leading 1.25")
        if lower.hasPrefix("line ") || lower.hasPrefix("spacing ") || lower.hasPrefix("leading ") {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let sp = Double(parts[1]), sp >= 0.8 && sp <= 4.0 {
                setLineSpacingAction(CGFloat(sp))
                return true
            }
        }

        // 7. Headings (e.g. "h1 Intro", "h2 Methods", "title Overview")
        if lower.hasPrefix("h1 ") {
            insertSectionHeadingAction(level: 1, customTitle: String(trimmed.dropFirst(3)))
            return true
        }
        if lower.hasPrefix("h2 ") {
            insertSectionHeadingAction(level: 2, customTitle: String(trimmed.dropFirst(3)))
            return true
        }
        if lower.hasPrefix("h3 ") {
            insertSectionHeadingAction(level: 3, customTitle: String(trimmed.dropFirst(3)))
            return true
        }
        if lower.hasPrefix("title ") {
            insertSectionHeadingAction(level: 1, customTitle: String(trimmed.dropFirst(6)))
            return true
        }

        // 8. Header & Footer (e.g. "header", "edit header", "footer", "edit footer", "page number", "page numbers", "exit header", "close header")
        if lower == "header" || lower == "edit header" || lower == "headers" {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                activeHeaderFooterTarget = .header
                isEditingHeaderFooter = true
            }
            showToast("✓ Header editor activated")
            return true
        }
        if lower == "footer" || lower == "edit footer" || lower == "footers" {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                activeHeaderFooterTarget = .footer
                isEditingHeaderFooter = true
            }
            showToast("✓ Footer editor activated")
            return true
        }
        if lower == "page number" || lower == "page numbers" || lower == "pagenum" || lower == "numbering" {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                activeHeaderFooterTarget = .footer
                isEditingHeaderFooter = true
            }
            showToast("✓ Page numbering settings opened")
            return true
        }
        if lower == "close header" || lower == "close footer" || lower == "done header" || lower == "exit header" {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isEditingHeaderFooter = false
            }
            showToast("✓ Header & footer editor closed")
            return true
        }

        // 9. Find (e.g. "find keyword")
        if lower.hasPrefix("find ") {
            showFindReplace = true
            showToast("✓ Search opened for: \(trimmed.dropFirst(5))")
            return true
        }

        // 10. AI prompt execution
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showAIDrawer = true
        }
        showToast("✨ AI Assistant prompted: \"\(trimmed)\"")
        return true
    }

    var paletteCommands: [CommandItem] {
        [
            // === File & Document Operations ===
            CommandItem(title: "Save Native .letters Package", subtitle: "Lossless Project Letters document archive", icon: "tray.and.arrow.down.fill", category: .document, shortcut: "⌘S", keywords: ["save", "native", "package", "store"]) {
                saveDocumentAsLetters()
            },
            CommandItem(title: "Open Existing Document", subtitle: "Open .letters, .docx, or .md file from disk", icon: "folder", category: .document, shortcut: "⌘O", keywords: ["open", "import", "browse", "load"]) {
                openDocument()
            },
            CommandItem(title: "Export as Word Document (.docx)", subtitle: "Generate native lossless Microsoft Word document", icon: "doc.fill", category: .document, shortcut: "⌘⇧S", keywords: ["export", "word", "docx", "microsoft"]) {
                saveDocumentAsDocx()
            },
            CommandItem(title: "Export as Vector PDF (.pdf)", subtitle: "High resolution publication PDF ready for printing", icon: "arrow.down.doc", category: .document, shortcut: "⌘⌥E", keywords: ["pdf", "vector", "export", "print"]) {
                exportDocumentAsPDF()
            },
            CommandItem(title: "Print Document", subtitle: "Open native macOS Print setup & pagination dialog", icon: "printer", category: .document, shortcut: "⌘P", keywords: ["print", "paper", "dialog"]) {
                printDocument()
            },
            CommandItem(title: "Document Statistics & Word Count", subtitle: "\(wordCount) words, \(characterCount) characters, \(editorController.pageCount) pages", icon: "chart.bar.doc.horizontal", category: .document, shortcut: "⌘I", keywords: ["stats", "words", "count", "info"]) {
                showToast("📊 \(wordCount) words • \(characterCount) characters • \(editorController.pageCount) pages")
            },
            CommandItem(title: "Clear Document (New File)", subtitle: "Reset text, tables, figures, and sources", icon: "trash", category: .document, keywords: ["clear", "reset", "empty", "new"]) {
                newDocumentAction()
            },

            // === Formatting & Typography ===
            CommandItem(title: "Toggle Bold", subtitle: "Make selected text bold", icon: "bold", category: .formatting, shortcut: "⌘B", keywords: ["bold", "weight", "heavy"]) {
                toggleBoldAction()
            },
            CommandItem(title: "Toggle Italic", subtitle: "Make selected text italic", icon: "italic", category: .formatting, shortcut: "⌘I", keywords: ["italic", "oblique", "slant"]) {
                toggleItalicAction()
            },
            CommandItem(title: "Toggle Underline", subtitle: "Underline selected text", icon: "underline", category: .formatting, shortcut: "⌘U", keywords: ["underline"]) {
                toggleUnderlineAction()
            },
            CommandItem(title: "Toggle Strikethrough", subtitle: "Cross out selected text", icon: "strikethrough", category: .formatting, shortcut: "⇧⌘X", keywords: ["strike", "strikethrough", "cross"]) {
                toggleStrikethroughAction()
            },
            CommandItem(title: "Align Left", subtitle: "Set text alignment to leading edge", icon: "text.alignleft", category: .formatting, shortcut: "⌘{", keywords: ["align", "left", "leading"]) {
                setAlignmentAction(.leading)
            },
            CommandItem(title: "Align Center", subtitle: "Center text horizontally", icon: "text.aligncenter", category: .formatting, shortcut: "⌘|", keywords: ["align", "center"]) {
                setAlignmentAction(.center)
            },
            CommandItem(title: "Align Right", subtitle: "Set text alignment to trailing edge", icon: "text.alignright", category: .formatting, shortcut: "⌘}", keywords: ["align", "right", "trailing"]) {
                setAlignmentAction(.trailing)
            },
            CommandItem(title: "Line Spacing: 1.0 (Single)", subtitle: "Compact single line spacing", icon: "arrow.up.and.down.text.horizontal", category: .formatting, keywords: ["spacing", "single", "leading"]) {
                setLineSpacingAction(1.0)
            },
            CommandItem(title: "Line Spacing: 1.15 (Standard)", subtitle: "Default modern document spacing", icon: "arrow.up.and.down.text.horizontal", category: .formatting, keywords: ["spacing", "standard", "leading"]) {
                setLineSpacingAction(1.15)
            },
            CommandItem(title: "Line Spacing: 1.5 (1.5x)", subtitle: "Academic 1.5x line spacing", icon: "arrow.up.and.down.text.horizontal", category: .formatting, keywords: ["spacing", "academic", "leading"]) {
                setLineSpacingAction(1.5)
            },
            CommandItem(title: "Line Spacing: 2.0 (Double)", subtitle: "Double line spacing for manuscripts", icon: "arrow.up.and.down.text.horizontal", category: .formatting, keywords: ["spacing", "double", "leading"]) {
                setLineSpacingAction(2.0)
            },
            CommandItem(title: "Font: Georgia (Default Serif)", subtitle: "Classic editorial serif typeface", icon: "textformat", category: .formatting, keywords: ["font", "georgia", "serif"]) {
                setFontFamilyAction("Default Serif (Georgia)")
            },
            CommandItem(title: "Font: SF Pro (San Francisco)", subtitle: "Clean modern Apple sans-serif", icon: "textformat", category: .formatting, keywords: ["font", "sf pro", "sans"]) {
                setFontFamilyAction("SF Pro")
            },
            CommandItem(title: "Font: Times New Roman", subtitle: "Standard academic journal typeface", icon: "textformat", category: .formatting, keywords: ["font", "times", "academic"]) {
                setFontFamilyAction("Times New Roman")
            },
            CommandItem(title: "Font: Helvetica Neue", subtitle: "Swiss modernist sans-serif", icon: "textformat", category: .formatting, keywords: ["font", "helvetica", "swiss"]) {
                setFontFamilyAction("Helvetica")
            },
            CommandItem(title: "Font: Charter", subtitle: "High readability Bitstream serif", icon: "textformat", category: .formatting, keywords: ["font", "charter", "serif"]) {
                setFontFamilyAction("Charter")
            },
            CommandItem(title: "Font: Menlo Monospace", subtitle: "Fixed-width code and tabular font", icon: "character.textbox", category: .formatting, keywords: ["font", "menlo", "mono", "code"]) {
                setFontFamilyAction("Menlo (Monospace)")
            },
            CommandItem(title: "Transform to UPPERCASE", subtitle: "Convert selection to uppercase letters", icon: "textformat.size.larger", category: .formatting, keywords: ["case", "upper", "capitalize"]) {
                transformTextSelection(mode: "upper")
            },
            CommandItem(title: "Transform to lowercase", subtitle: "Convert selection to lowercase letters", icon: "textformat.size.smaller", category: .formatting, keywords: ["case", "lower"]) {
                transformTextSelection(mode: "lower")
            },
            CommandItem(title: "Transform to Title Case", subtitle: "Capitalize first letter of each word", icon: "textformat", category: .formatting, keywords: ["case", "title", "capitalize"]) {
                transformTextSelection(mode: "capitalized")
            },

            // === Insert Structural Elements ===
            CommandItem(title: "Insert Heading 1 (Title)", subtitle: "Top level document section title (#)", icon: "text.quote", category: .insert, shortcut: "⌘⌥1", keywords: ["h1", "title", "heading"]) {
                insertSectionHeadingAction(level: 1)
            },
            CommandItem(title: "Insert Heading 2 (Section)", subtitle: "Major section heading (##)", icon: "text.quote", category: .insert, shortcut: "⌘⌥2", keywords: ["h2", "section", "heading"]) {
                insertSectionHeadingAction(level: 2)
            },
            CommandItem(title: "Insert Heading 3 (Subsection)", subtitle: "Subsection heading (###)", icon: "text.quote", category: .insert, shortcut: "⌘⌥3", keywords: ["h3", "subsection", "heading"]) {
                insertSectionHeadingAction(level: 3)
            },
            CommandItem(title: "Insert Smart Table", subtitle: "Embed interactive calculation table with formulas", icon: "tablecells", category: .insert, shortcut: "⌘T", keywords: ["table", "grid", "spreadsheet", "formula"]) {
                handleToolAction(.table)
            },
            CommandItem(title: "Insert Bulleted List", subtitle: "Add bulleted list item (•)", icon: "list.bullet", category: .insert, shortcut: "⇧⌘8", keywords: ["bullet", "list", "item"]) {
                insertBulletListAction()
            },
            CommandItem(title: "Insert Numbered List", subtitle: "Add ordered numbered item (1.)", icon: "list.number", category: .insert, shortcut: "⇧⌘7", keywords: ["number", "ordered", "list"]) {
                insertNumberedListAction()
            },
            CommandItem(title: "Insert Task / Checklist", subtitle: "Interactive markdown check box (- [ ])", icon: "checkmark.square", category: .insert, keywords: ["task", "checklist", "todo", "box"]) {
                insertChecklistAction()
            },
            CommandItem(title: "Insert Blockquote", subtitle: "Styled pull quote with vertical rule (>)", icon: "quote.opening", category: .insert, keywords: ["quote", "blockquote", "callout"]) {
                insertBlockquoteAction()
            },
            CommandItem(title: "Insert Code Block", subtitle: "Monospaced syntax block (```)", icon: "chevron.left.forwardslash.chevron.right", category: .insert, keywords: ["code", "snippet", "block"]) {
                insertCodeBlockAction()
            },
            CommandItem(title: "Insert Image Figure", subtitle: "Add image with aspect ratio and caption", icon: "photo", category: .insert, keywords: ["image", "picture", "photo", "figure"]) {
                insertImageAction()
            },
            CommandItem(title: "Add Bibliographic Citation", subtitle: "Link source author, year, and DOI/URL", icon: "quote.bubble", category: .insert, keywords: ["cite", "citation", "source", "reference", "bibliography"]) {
                showingAddSourceSheet = true
            },
            CommandItem(title: "Insert Formatted Bibliography", subtitle: "Dynamic [[bibliography]] works cited block", icon: "books.vertical", category: .insert, keywords: ["bibliography", "works cited", "references"]) {
                insertBibliographyAction()
            },
            CommandItem(title: "Insert Table of Contents", subtitle: "Dynamic [[toc]] page reference listing", icon: "list.bullet.indent", category: .insert, keywords: ["toc", "table of contents", "outline"]) {
                insertTOCAction()
            },
            CommandItem(title: "Insert Page Break", subtitle: "Force document onto new page sheet", icon: "pagebreak", category: .insert, shortcut: "⌘↵", keywords: ["page", "break", "sheet"]) {
                insertPageBreakAction()
            },
            CommandItem(title: "Insert Horizontal Divider", subtitle: "Visual separator rule (---)", icon: "divide", category: .insert, keywords: ["divider", "line", "rule", "separator"]) {
                insertDividerAction()
            },
            CommandItem(title: "Insert Current Date & Time", subtitle: "Stamp current timestamp into document", icon: "clock", category: .insert, keywords: ["date", "time", "stamp", "now"]) {
                insertDateTimeAction()
            },

            // === Page Setup & Layout ===
            CommandItem(title: "Page Format: A4 (210 × 297 mm)", subtitle: "International standard document size", icon: "doc", category: .layout, keywords: ["a4", "format", "size", "iso"]) {
                documentController.pageSize = .a4
                showToast("✓ Page Format: A4")
            },
            CommandItem(title: "Page Format: US Letter (8.5 × 11 in)", subtitle: "North American standard paper size", icon: "doc", category: .layout, keywords: ["letter", "format", "size", "us"]) {
                documentController.pageSize = .letter
                showToast("✓ Page Format: US Letter")
            },
            CommandItem(title: "Page Format: US Legal (8.5 × 14 in)", subtitle: "Extended legal document format", icon: "doc", category: .layout, keywords: ["legal", "format", "size"]) {
                documentController.pageSize = .legal
                showToast("✓ Page Format: US Legal")
            },
            CommandItem(title: "Page Format: Executive", subtitle: "Compact 7.25 × 10.5 in executive format", icon: "doc", category: .layout, keywords: ["executive", "format", "size"]) {
                documentController.pageSize = .executive
                showToast("✓ Page Format: Executive")
            },
            CommandItem(title: "Margins: Standard (1 inch / 72 pt)", subtitle: "Balanced standard print margins", icon: "doc.viewfinder", category: .layout, keywords: ["margin", "standard", "1 inch"]) {
                documentController.marginPreset = .normal
                showToast("✓ Margins: Standard (72 pt)")
            },
            CommandItem(title: "Margins: Narrow (0.5 inch / 36 pt)", subtitle: "Maximized printable canvas area", icon: "doc.viewfinder", category: .layout, keywords: ["margin", "narrow", "0.5 inch"]) {
                documentController.marginPreset = .narrow
                showToast("✓ Margins: Narrow (36 pt)")
            },
            CommandItem(title: "Margins: Wide (1.5 inch / 108 pt)", subtitle: "Spacious margins for annotations and notes", icon: "doc.viewfinder", category: .layout, keywords: ["margin", "wide", "spacious"]) {
                documentController.marginPreset = .wide
                showToast("✓ Margins: Wide (108 pt)")
            },
            CommandItem(title: "Toggle Margin Guides", subtitle: "Show or hide canvas guideline borders", icon: "square.dashed", category: .layout, keywords: ["margin", "guides", "rulers", "border"]) {
                showMarginGuides.toggle()
                showToast(showMarginGuides ? "✓ Margin Guides Enabled" : "Margin Guides Hidden")
            },
            CommandItem(title: "Toggle Crop Marks", subtitle: "Display commercial printer alignment crop marks", icon: "crop", category: .layout, keywords: ["crop", "marks", "print", "bleed"]) {
                showCropMarks.toggle()
                showToast(showCropMarks ? "✓ Crop Marks Enabled" : "Crop Marks Hidden")
            },
            CommandItem(title: "Edit Running Header", subtitle: "Customize running header text, dynamic tokens, and alignment", icon: "arrow.up.to.line", category: .layout, shortcut: "⌥⌘H", keywords: ["header", "running header", "title", "top", "token"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    activeHeaderFooterTarget = .header
                    isEditingHeaderFooter = true
                }
            },
            CommandItem(title: "Edit Running Footer", subtitle: "Customize footer content and dynamic page number positioning", icon: "arrow.down.to.line", category: .layout, shortcut: "⌥⌘F", keywords: ["footer", "running footer", "bottom", "page number"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    activeHeaderFooterTarget = .footer
                    isEditingHeaderFooter = true
                }
            },
            CommandItem(title: "Configure Page Numbering", subtitle: "Select numbering format (X of Y, Roman, Page X) and placement", icon: "number.square", category: .layout, keywords: ["page numbers", "numbering", "pagination", "format", "roman", "footer"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    activeHeaderFooterTarget = .footer
                    isEditingHeaderFooter = true
                }
            },
            CommandItem(title: "Toggle Different First Page", subtitle: "Suppress running headers and footers on document title cover", icon: "doc.text", category: .layout, keywords: ["first page", "cover", "title page", "suppress", "header", "footer"]) {
                documentController.headerFooter.differentFirstPage.toggle()
                showToast(documentController.headerFooter.differentFirstPage ? "✓ Different First Page Enabled" : "Different First Page Disabled")
            },

            // === AI Assistant ===
            CommandItem(title: "Toggle AI Assistant", subtitle: "Open native BYOK intelligence drawer", icon: "sparkles", category: .ai, shortcut: "⌘J", keywords: ["ai", "chat", "assistant"]) {
                showAIDrawer.toggle()
            },
            CommandItem(title: "AI Polish Tone & Academic Flow", subtitle: "Refine phrasing and eliminate passive voice", icon: "wand.and.stars", category: .ai, keywords: ["polish", "academic", "tone", "flow", "refine"]) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showAIDrawer = true }
                showToast("✨ AI Assistant ready to polish")
            },
            CommandItem(title: "AI Instant Translation", subtitle: "Translate selected passage into target language", icon: "translate", category: .ai, keywords: ["translate", "language", "offline", "bilingual"]) {
                Task {
                    if let res = try? await TranslationService.shared.translate(text: selectedText.isEmpty ? documentController.rawText : selectedText) {
                        if !selectedText.isEmpty && selectionRange.length > 0 && selectionRange.location + selectionRange.length <= (documentController.rawText as NSString).length {
                            let ns = documentController.rawText as NSString
                            documentController.rawText = ns.replacingCharacters(in: selectionRange, with: res)
                        }
                        showToast("✓ Translated with Offline Engine")
                    }
                }
            },
            CommandItem(title: "AI Explain Selected Concept", subtitle: "Get an in-depth breakdown of selected text", icon: "brain.head.profile", category: .ai, keywords: ["explain", "understand", "summary", "concept"]) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showAIDrawer = true }
                showToast("✨ AI Assistant explaining selection")
            },
            CommandItem(title: "AI Generate Table of Contents", subtitle: "Analyze document and build hierarchical TOC", icon: "sparkles.rectangle.stack", category: .ai, keywords: ["ai", "toc", "structure", "outline"]) {
                insertTOCAction()
            },

            // === View, Canvas & Tools ===
            CommandItem(title: "Find & Replace", subtitle: "Search for terms across all page sheets", icon: "magnifyingglass", category: .view, shortcut: "⌘F", keywords: ["find", "search", "replace", "locate"]) {
                showFindReplace.toggle()
            },
            CommandItem(title: "Toggle Outline Navigator Drawer", subtitle: "Sidebar table of contents and structure tree", icon: "sidebar.left", category: .view, keywords: ["outline", "sidebar", "navigator", "drawer"]) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showOutlineDrawer.toggle()
                }
            },
            CommandItem(title: "Zoom In (+)", subtitle: "Enlarge workspace canvas scale (+15%)", icon: "plus.magnifyingglass", category: .view, shortcut: "⌘+", keywords: ["zoom", "in", "enlarge", "scale"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = min(2.5, zoomScale + 0.15)
                }
                showToast("✓ Zoom: \(Int(zoomScale * 100))%")
            },
            CommandItem(title: "Zoom Out (-)", subtitle: "Reduce workspace canvas scale (-15%)", icon: "minus.magnifyingglass", category: .view, shortcut: "⌘-", keywords: ["zoom", "out", "shrink", "scale"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = max(0.5, zoomScale - 0.15)
                }
                showToast("✓ Zoom: \(Int(zoomScale * 100))%")
            },
            CommandItem(title: "Reset Zoom (100%)", subtitle: "Set canvas scale to standard 100%", icon: "arrow.counterclockwise", category: .view, shortcut: "⌘0", keywords: ["zoom", "reset", "100", "actual"]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    zoomScale = 1.0
                }
                showToast("✓ Zoom: 100%")
            }
        ]
    }

    func buildDocumentAIContext() -> String {
        var context = "=== DOCUMENT METADATA ===\n"
        context += "Title: \(documentController.title)\n"
        context += "Page Format: \(documentController.pageSize.rawValue) (\(Int(currentSheetWidth))x\(Int(currentSheetHeight)) pt)\n"
        context += "Margins: Top \(Int(documentController.margins.top)) pt, Bottom \(Int(documentController.margins.bottom)) pt, Left \(Int(documentController.margins.left)) pt, Right \(Int(documentController.margins.right)) pt\n"
        context += "Word Count: \(wordCount) words, \(characterCount) characters\n\n"

        context += "=== DOCUMENT BODY TEXT ===\n"
        context += documentController.rawText + "\n\n"

        if !documentController.tables.isEmpty {
            context += "=== EMBEDDED SMART TABLES (\(documentController.tables.count)) ===\n"
            for (i, table) in documentController.tables.enumerated() {
                context += "Table \(i + 1):\n"
                context += "| " + table.headers.joined(separator: " | ") + " |\n"
                context += "| " + table.headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
                for row in table.rows {
                    context += "| " + row.joined(separator: " | ") + " |\n"
                }
                context += "\n"
            }
        }

        if !documentController.images.isEmpty {
            context += "=== EMBEDDED FIGURES & IMAGES (\(documentController.images.count)) ===\n"
            for (i, img) in documentController.images.enumerated() {
                context += "Figure \(i + 1): \(img.caption) [Alignment: \(img.alignment.rawValue), Aspect Ratio: \(img.aspectRatioPreset.rawValue)]\n"
            }
            context += "\n"
        }

        if !documentController.videos.isEmpty {
            context += "=== EMBEDDED MEDIA / VIDEOS (\(documentController.videos.count)) ===\n"
            for (i, vid) in documentController.videos.enumerated() {
                context += "Video \(i + 1): \(vid.title) (\(vid.platform.rawValue): \(vid.url))\n"
            }
            context += "\n"
        }

        if !documentController.document.sources.isEmpty {
            context += "=== LINKED BIBLIOGRAPHIC SOURCES (\(documentController.document.sources.count)) ===\n"
            for (id, src) in documentController.document.sources {
                let authorsStr = src.authors.joined(separator: ", ")
                let yearStr = src.year != nil ? String(src.year!) : "n.d."
                context += "[\(id)]: \(authorsStr) (\(yearStr)). \(src.title). [Type: \(src.sourceType.rawValue)]\n"
            }
            context += "\n"
        }

        if !lintIssues.isEmpty {
            context += "=== STYLE & CITATION LINT NOTICES (\(lintIssues.count)) ===\n"
            for issue in lintIssues.prefix(5) {
                let sugg = issue.suggestion ?? "Check rule guideline"
                context += "• [\(issue.ruleId)]: \(issue.message) -> Recommendation: \(sugg)\n"
            }
            context += "\n"
        }

        return context
    }

    func runLinter() {
        guard documentController.styleProfile != "none" else {
            lintIssues = []
            return
        }
        lintIssues = CoreBridge.shared.lint(text: documentController.rawText, profile: documentController.styleProfile)
    }
}
