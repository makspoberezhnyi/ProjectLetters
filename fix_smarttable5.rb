path = "macos/LettersApp/Sources/LettersApp/SmartTableView.swift"
content = File.read(path)

# 1. Add `fontFamily` property to SmartTableView
prop_regex = /@State private var activeEditingCell: String\? = nil\s+@State private var showingFormulaHelper: Bool = false\s+public init/m
new_props = <<-SWIFT
@State private var activeEditingCell: String? = nil
    @State private var showingFormulaHelper: Bool = false

    public var fontFamily: String

    public init
SWIFT
content.sub!(prop_regex, new_props)

# 2. Add `fontFamily` to initializer
init_regex = /public init\(\s+tableData: StudioTableData,\s+onDelete: \(\(\) -> Void\)\? = nil,\s+onChange: \(\(\) -> Void\)\? = nil,\s+onToast: \(\(String\) -> Void\)\? = nil\s+\) \{\s+self\._tableData = State\(initialValue: tableData\)\s+self\.onDelete = onDelete\s+self\.onChange = onChange\s+self\.onToast = onToast\s+\}/m

new_init = <<-SWIFT
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
content.sub!(init_regex, new_init)

# 3. Add font helper
font_helper = <<-SWIFT
    private func getTableFont(size: CGFloat) -> Font {
        switch fontFamily {
        case "SF Pro (Modern Sans)": return .system(size: size)
        case "New York (Editorial)": return .custom("NewYork-Regular", size: size)
        case "SF Mono (Code)": return .system(size: size, design: .monospaced)
        case "Default Serif (Georgia)": return .custom("Georgia", size: size)
        default: return .system(size: size)
        }
    }

    // MARK: - Actions
SWIFT
content.sub!("// MARK: - Actions", font_helper)

File.write(path, content)
