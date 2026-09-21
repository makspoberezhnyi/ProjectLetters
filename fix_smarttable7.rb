path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# Remove the contextMenu block from dataCellView
context_regex = /\.contextMenu \{\s+Button\("Add Row Above"\).*?Button\("Delete Table".*?\}\s+\}\s+\}\s+\}/m

new_context = <<-SWIFT
        }
    }
SWIFT

content.sub!(context_regex, new_context)
File.write(path, content)
