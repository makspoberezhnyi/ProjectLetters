import re

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "r") as f:
    code = f.read()

pattern = r'    public func createBundle\(\) -> LettersDocumentBundle \{\n        LettersDocumentBundle\([\s\S]*?modifiedAt: Date\(\)\n        \)'

replacement = '''    public func createBundle() -> LettersDocumentBundle {
        LettersDocumentBundle(
            title: title,
            rawText: rawText,
            richTextData: richTextData,
            tables: tables,
            images: images,
            videos: videos,
            sources: document.sources,
            citationStyle: citationStyle,
            pageSizePreset: pageSize,
            marginPreset: marginPreset,
            margins: margins,
            fontFamily: fontFamily,
            fontSize: Double(fontSize),
            lineSpacing: Double(lineSpacing),
            paragraphSpacing: Double(paragraphSpacing),
            headerFooter: headerFooter,
            coverBanner: coverBanner
        )'''
        
code = re.sub(pattern, replacement, code)

with open("macos/LettersApp/Sources/LettersApp/MainEditorView.swift", "w") as f:
    f.write(code)
