# Letters: Product Specification (v3)

Originally scoped for academic copywriting. Expanded here to cover business reporting, legal drafting, journalism, and content marketing, since all of them need the same three things underneath: native docx fidelity, sources that stay linked to what they support, and style rules the document can be checked against.

## 1. Core Architecture and Native Engine
* **SwiftUI Frontend (macOS First):** The initial interface is built entirely in Swift and SwiftUI, wrapping TextKit 2 for viewport based rendering. This ensures it feels incredibly lightweight, handles massive documents smoothly, and natively supports dynamic themes across Apple platforms.
* **Headless Rust Core:** Beneath the UI runs a headless Rust engine exposed via a Foreign Function Interface (FFI) on desktop and compiled to WebAssembly (Wasm) for the browser. This engine parses, edits, and writes native .docx files, ensuring zero format loss across all platforms.
* **Future Windows & Web Portability:** By encapsulating all business logic, document parsing, citation engines, and style verification in the portable Rust core:
    * **Windows Version:** Can connect directly via native C FFI using WinUI 3.
    * **Web / Cloud Version:** Can run the exact same core compiled to WebAssembly (Wasm) inside the browser (enabling client-side, zero-server DOCX rendering and privacy-preserving document manipulation).
* **Native macOS Integrations:** Deep hooks into CoreSpotlight for document indexing and native tabbed window management for a first party feel.

## 2. Bring Your Own Key (BYOK) Artificial Intelligence
* **Universal Cloud API Gateway:** Connect directly to major vendors like Anthropic, OpenAI, or Google using personal API keys. You pay only for the exact tokens you consume without ongoing software subscriptions.
* **Native Credential Security:** API keys are stored securely using the native macOS Keychain on Apple platforms, Windows Credential Locker on Windows, and encrypted client-side storage (Web Crypto API) for the Web version, rather than custom cloud-side security layers.
* **Contextual Chat Assistant:** A persistent sidebar companion that can summarize highlighted text, suggest structural improvements, or brainstorm angles on complex topics.

## 3. Linked Sources and Style Profiles
* **Linked Source System:** A citation, a case reference, or a cited data point is not typed as flat text. It is a pointer into a source table, storing raw fields (author, year, title, publisher, DOI, URL, or interview and date for a quote) rather than a pre-formatted string. Editing a source once updates every place it is used, including bibliography order and numbering.
* **Configurable Citation Rendering:** The same linked source renders differently depending on the active profile, APA, MLA, Chicago, Bluebook for legal, or a plain attribution line for a business report or a news story. Switching styles is a re-render, not a rewrite.
* **Source Validation:** Runs as a check over the linked source table rather than a blind cleanup pass on flat text. Flags incomplete fields, sources with no citation pointing to them anywhere in the document, and citations pointing to a source that no longer exists. Never deletes automatically, always surfaces the issue for review.
* **Style Profiles:** Custom rule sets, academic style guide, firm house style, a client's brand voice guidelines, can be saved and swapped per document. Each profile carries its own banned phrases, tone rules, and formatting requirements, and the document is checked against whichever profile is active.
* **Semantic Argument Mapping:** View your structural outline on one side and a visual node map on the other, to track logical flow in long reports, briefs, or academic projects alike.
* **Redlining and Track Changes:** Full markup and comment support for client review cycles, contract negotiation, and editorial passes, with changes attributable to the reviewer.

## 4. Modern UX Innovations and Shortcuts
* **Command Palette Control:** Manage all document formatting, margins, and generation actions via a simple keyboard shortcut (Cmd+K), completely eliminating cluttered legacy ribbon menus.
* **Floating Context Menu:** A minimalist frosted glass menu appears instantly when you highlight a block of text, offering standard formatting, AI quick actions, and reference tagging.
* **Native Translation & Explanations:**
    * **Live Offline Translation:** Utilizing Apple's native Translation framework for Swift, users can highlight text and instantly translate it between languages completely offline and for free, with inline replacements.
    * **AI Explanations:** Users can highlight jargon and select "Explain," which pings the BYOK AI to generate a contextual breakdown, drawing on the glossary tied to the active style profile so legal, medical, or financial terms get field appropriate explanations.
* **Classic Word Keymap Preset:** Muscle memory is preserved by mapping the most ingrained commands directly into Letters. A simple preference toggle maps everything to the expected Cmd layout for Mac OS, adapting seamlessly.
* **Markdown to DOCX:** The editor allows fluid Markdown typing, instantly rendering syntax into native Word styles without leaving raw formatting marks on the page.
* **Multi Format Export:** Beyond docx, export the same document as clean Markdown or HTML for CMS publishing, so content writers are not locked into a format built for print.

## 5. Smart Tables and Data Integration
* **Data Manipulation Sandboxes:** Tables function as embedded data environments. A user can drop a dataset into the document, and an invisible local Python environment utilizing Pandas or NumPy can instantly render the data into a beautifully formatted table.
* **Advanced Formula Support:** The internal engine supports complex calculations and syntax similar to DAX formulas for data filtering and dynamic summaries.
* **Inline Variable Referencing:** Tag a specific cell in a table and reference that exact variable in the body text of your paper. Updating a raw number in the table automatically updates the calculated results and the paragraph text.
* **Flawless Word Compatibility:**
    * **Hardcoded Value Caching:** Final rendered numbers are saved directly into the standard text nodes of the document file.
    * **Native Word Field Codes:** Basic mathematical functions are translated into native field codes.
    * **Graceful Degradation:** Complex logic is executed and exported strictly as a standard, styled table, ensuring recipients see a perfectly structured document without errors or macro warnings.
