path = "macos/LettersApp/Sources/LettersApp/MainEditorView.swift"
content = File.read(path)

# Fix (⌘F) issue
content.gsub!(/^\s*\(⌘F\)\s*\n/, "")

# Fix TextAlignment issue
old_align = <<-SWIFT
                    Menu {
                        Button("Left") { setAlignmentAction(.left) }
                        Button("Center") { setAlignmentAction(.center) }
                        Button("Right") { setAlignmentAction(.right) }
                        Button("Justified") { setAlignmentAction(.justified) }
                    } label: {
                        let align = selectionAttributes?.alignment ?? textAlignment
                        let alignIcon = align == .left ? "text.alignleft" : (align == .center ? "text.aligncenter" : (align == .right ? "text.alignright" : "text.justify"))
SWIFT

new_align = <<-SWIFT
                    Menu {
                        Button("Left") { setAlignmentAction(.leading) }
                        Button("Center") { setAlignmentAction(.center) }
                        Button("Right") { setAlignmentAction(.trailing) }
                    } label: {
                        let align = selectionAttributes?.alignment ?? textAlignment
                        let alignIcon = align == .leading ? "text.alignleft" : (align == .center ? "text.aligncenter" : "text.alignright")
SWIFT

content.sub!(old_align, new_align)
File.write(path, content)
