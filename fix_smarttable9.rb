path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# Insert fontFamily and update init
target_regex = /@State private var activeEditingCell: String\? = nil\s+@State private var showingFormulaHelper: Bool = false\s+public init\(.*?tableData: StudioTableData,\s+onDelete: \(\(\) -> Void\)\? = nil,\s+onChange: \(\(\) -> Void\)\? = nil,\s+onToast: \(\(String\) -> Void\)\? = nil\s+\) \{\s+self\._tableData = State\(initialValue: tableData\)\s+self\.onDelete = onDelete\s+self\.onChange = onChange\s+self\.onToast = onToast\s+\}/m

new_content = <<-SWIFT
@State private var activeEditingCell: String? = nil
    @State private var showingFormulaHelper: Bool = false
    public var fontFamily: String

    public init(
        tableData: StudioTableData,
        fontFamily: String = "Default Serif (Georgia)",
        onDelete: (() -> Void)? = nil,
        onChange: (() -> Void)? = nil,
        onToast: ((String) -> Void)? = nil
    ) {
        self._tableData = State(initialValue: tableData)
        self.fontFamily = fontFamily
        self.onDelete = onDelete
        self.onChange = onChange
        self.onToast = onToast
    }
SWIFT

if content.match?(target_regex)
  content.sub!(target_regex, new_content)
  puts "Successfully replaced init."
else
  puts "Failed to match init!"
end

File.write(path, content)
