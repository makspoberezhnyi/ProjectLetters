path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# Regex to match the start of `body` up to `// 2. Interactive Spreadsheet Grid`
target_regex = /public var body: some View \{\s+VStack\(alignment: \.leading, spacing: 6\) \{\s+\/\/ 1\. Table Header & Toolbar.*?\/\/ 2\. Interactive Spreadsheet Grid/m

replacement = <<-SWIFT
public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 2. Interactive Spreadsheet Grid
SWIFT

if content.match?(target_regex)
  content.sub!(target_regex, replacement)
  File.write(path, content)
  puts "Successfully replaced the toolbar!"
else
  puts "Regex did not match!"
end
