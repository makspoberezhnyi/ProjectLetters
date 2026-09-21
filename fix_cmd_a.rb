path = "macos/LettersApp/Sources/LettersApp/MainEditorView.swift"
content = File.read(path)

target_shortcuts = /\.keyboardShortcut\("0", modifiers: \[\.command\]\)\n\s+\}/m
new_shortcuts = <<-SWIFT
.keyboardShortcut("0", modifiers: [.command])
                
                // Global Command+A routing
                Button(action: {
                    NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
                }) { EmptyView() }
                    .keyboardShortcut("a", modifiers: [.command])
            }
SWIFT

if content.match?(target_shortcuts)
  content.sub!(target_shortcuts, new_shortcuts)
  puts "Added Command+A routing."
else
  puts "Failed to match shortcuts block!"
end

File.write(path, content)
