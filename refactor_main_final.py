import re

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "r") as f:
    lines = f.readlines()

code = "".join(lines)

# 1. Remove the @State declarations
# Custom removes for multi-line:
code = re.sub(r'@State private var document = DocumentModel\(\s*title: "Letters Product Specification",\s*blocks: \[\]\s*\)\s*', '', code)
code = re.sub(r'@State private var rawText: String = """[\s\S]*?"""\n', '', code)
code = re.sub(r'@State private var studioTables: \[StudioTableData\] = \[[\s\S]*?\]\s*\]\n', '', code)
code = re.sub(r'@State private var coverBannerConfig: CoverBannerConfig = CoverBannerConfig\([\s\S]*?\n    \)\n', '', code)

# Single line removes
single_vars = ["documentTitle", "richTextData", "activeCitationStyle", "pageSize", "marginPreset", "margins", "headerFooterConfig", "studioImages", "studioVideos", "fontFamily", "fontSize", "lineSpacing", "paragraphSpacing", "textAlignment"]
for var_name in single_vars:
    code = re.sub(rf'[ \t]*@State private var {var_name}: [^\n]+\n', '', code)

# 2. Insert @StateObject
state_obj = "    @StateObject private var documentController = LettersDocumentController()\n"
code = re.sub(r'    @StateObject private var editorController = EditorActionController\(\)\n', 
              f'    @StateObject private var editorController = EditorActionController()\n{state_obj}', code)

# 3. Targeted replacements
lines = code.split('\n')
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

new_lines = []
for i, line in enumerate(lines):
    # Skip margin replacements in PaperMarginGuidesView (which is below line 2400)
    if i > 2400 and "struct PaperMarginGuidesView: View" in "\n".join(lines[i-10:i+10]):
        # Keep everything below 2400 as is, EXCEPT for actual MainEditorView closures...
        # Wait, PaperMarginGuidesView is independent. It doesn't use the document state directly.
        pass
    
    # Actually, it's safer to just skip line > 2500 for `margins`.
    new_line = line
    for old, new in replacements:
        if old == "margins" and i > 2400:
            continue
            
        binding_pattern = rf'\${old}(?![a-zA-Z0-9_:])'
        new_line = re.sub(binding_pattern, f'$documentController.{new}', new_line)
        
        pattern = rf'(?<![a-zA-Z0-9_\.]){old}(?![a-zA-Z0-9_:])'
        new_line = re.sub(pattern, f'documentController.{new}', new_line)
        
    new_lines.append(new_line)

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "w") as f:
    f.write("\n".join(new_lines))

