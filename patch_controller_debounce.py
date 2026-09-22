import re

with open("macos/LettersApp/Sources/LettersApp/LettersDocumentController.swift", "r") as f:
    code = f.read()

# Add Combine import
code = re.sub(r'import AppKit\n', 'import AppKit\nimport Combine\n', code)

# Add cancellables
code = re.sub(r'@Published public var historyIndex: Int = -1\n    private var isReverting: Bool = false', '@Published public var historyIndex: Int = -1\n    private var isReverting: Bool = false\n    private var cancellables = Set<AnyCancellable>()', code)

# Add init debounce listener
init_pattern = r'self\.textAlignment = textAlignment\n        \n        // Initial snapshot\n        DispatchQueue\.main\.async \{\n            self\.commitSnapshot\(actionName: "Created Document"\)\n        \}'
replacement = '''self.textAlignment = textAlignment
        
        // Initial snapshot
        DispatchQueue.main.async {
            self.commitSnapshot(actionName: "Created Document")
        }
        
        $rawText
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isReverting else { return }
                self.commitSnapshot(actionName: "Typing")
            }
            .store(in: &cancellables)'''
            
code = re.sub(init_pattern, replacement, code)

with open("macos/LettersApp/Sources/LettersApp/LettersDocumentController.swift", "w") as f:
    f.write(code)
