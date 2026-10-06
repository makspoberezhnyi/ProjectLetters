# Project Letters

**Letters** is a modern, high-performance document editor designed to replace legacy word processors. It combines a lightweight, native SwiftUI frontend (for macOS) with a headless, highly portable Rust core that handles `.docx` parsing, editing, and rendering with zero format loss.

Originally scoped for academic copywriting, Letters is built for business reporting, legal drafting, journalism, and content marketing—providing deep structural tools, intelligent source linking, and dynamic style rules.

## Key Features

- **Native SwiftUI & Rust Core**: A blazing-fast, TextKit 2-based macOS interface powered by a headless Rust engine. Future-proofed for Windows and Web via WebAssembly.
- **Flawless `.docx` Compatibility**: The Rust core directly parses and writes native Word files.
- **Bring Your Own Key (BYOK) AI**: Connect to Anthropic, OpenAI, or Google using your own API keys. Features a persistent AI sidebar companion for summarization, structural suggestions, and contextual explanations.
- **Linked Sources & Citations**: Sources aren't just text—they are data pointers. Update a source once, and every citation and bibliography entry updates automatically. Switch between APA, MLA, Chicago, or Bluebook with a single click.
- **Style Profiles & Rule Checking**: Enforce academic, legal, or brand guidelines by checking the document against configurable style rules and banned phrases.
- **Modern UX**: A clean Command Palette (`Cmd+K`), a floating context menu for instant formatting and AI actions, and Markdown-to-DOCX fluid typing.
- **Smart Tables**: Embedded data sandboxes with Python/Pandas support, DAX-like formulas, and inline variable referencing that updates your body text automatically when data changes.

## Architecture

- `macos/`: Contains the SwiftUI native macOS application.
- `core/`: The headless Rust engine handling document structure, formatting, and logic.

*For more details, see the [Letters Product Specification](Letters_Product_Specification.md).*
