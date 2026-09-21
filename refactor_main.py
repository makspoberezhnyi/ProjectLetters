import re

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "r") as f:
    code = f.read()

# Variables to migrate
replacements = [
    ("documentTitle", "title"),
    ("document", "document"),
    ("richTextData", "richTextData"),
    ("rawText", "rawText"),
    ("activeCitationStyle", "citationStyle"),
    ("pageSize", "pageSize"),
    ("marginPreset", "marginPreset"),
    ("margins", "margins"),
    ("headerFooterConfig", "headerFooter"),
    ("studioTables", "tables"),
    ("studioImages", "images"),
    ("studioVideos", "videos"),
    ("fontFamily", "fontFamily"),
    ("fontSize", "fontSize"),
    ("lineSpacing", "lineSpacing"),
    ("paragraphSpacing", "paragraphSpacing"),
    ("textAlignment", "textAlignment"),
    ("coverBannerConfig", "coverBanner")
]

# 1. Remove the @State declarations
for var_name, _ in replacements:
    # Need to match @State private var var_name ... until the next @State or the end of the block
    if var_name == "document":
        # special case for multi-line DocumentModel init
        pattern = r'@State private var document = DocumentModel\([\s\S]*?margins: PageMargins\(top: 72, bottom: 72, left: 72, right: 72\)\n    \)\n'
        code = re.sub(pattern, '', code)
    elif var_name == "rawText":
        pattern = r'@State private var rawText: String = """[\s\S]*?"""\n'
        code = re.sub(pattern, '', code)
    elif var_name == "studioTables":
        pattern = r'@State private var studioTables: \[StudioTableData\] = \[[\s\S]*?\n    \]\n'
        code = re.sub(pattern, '', code)
    elif var_name == "coverBannerConfig":
        pattern = r'@State private var coverBannerConfig: CoverBannerConfig = CoverBannerConfig\([\s\S]*?\n    \)\n'
        code = re.sub(pattern, '', code)
    else:
        pattern = rf'[ \t]*@State private var {var_name}: [^\n]+\n'
        code = re.sub(pattern, '', code)

# 2. Insert @StateObject
state_obj = "    @StateObject private var documentController = LettersDocumentController()\n"
code = re.sub(r'    @StateObject private var editorController = EditorActionController\(\)\n', 
              f'    @StateObject private var editorController = EditorActionController()\n{state_obj}', code)

# 3. Replace all occurrences
for old, new in replacements:
    # Be careful not to replace substrings of other words
    # e.g. document -> documentController.document
    # This requires looking at boundaries. 
    # Use negative lookbehind/lookahead for alphanumeric
    pattern = rf'(?<![a-zA-Z0-9_]){old}(?![a-zA-Z0-9_])'
    # EXCEPT when they are $document
    # \$document -> \$documentController\.document
    
    # First handle the binding prefix $
    binding_pattern = rf'\${old}(?![a-zA-Z0-9_])'
    code = re.sub(binding_pattern, f'$documentController.{new}', code)
    
    # Then handle the normal prefix
    code = re.sub(pattern, f'documentController.{new}', code)

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "w") as f:
    f.write(code)

