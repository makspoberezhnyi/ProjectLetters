# Project Letters: Master Engineering & Orchestration Plan
**Methodology**: `model-orchestration` Specialist Ensemble  
**Branch**: `feat/reboot-clean-architecture`  
**Vision**: The Best of Apple Pages (Sanctuary Canvas) + Google Docs (Frictionless Typing & Reviews) + MS Word (Structure & Citations) + Ambient AI Agents.

---

## 🎭 The Specialist Ensemble Roster

| Specialist | Role & Responsibilities | Model / Provider |
| :--- | :--- | :--- |
| **🏛️ Arthur** | **The Architect**: Pure-Swift AST architecture, protocol contracts, actor boundaries, single-container TextKit 2 topology. | `nvidia/nemotron-3-ultra-550b-a55b` on `acpRegistry_qwen_code` |
| **⚡ Finn** | **Lead Builder**: Code surgery, excision of dead micro-apps, single-container refactoring, zero-warning builds. | `codestral-latest` / `gemini-3.8-flash` on `antigravity` |
| **🎨 Iris** | **UI/UX Director**: Pages canvas drop-shadow, New York + SF Pro typography rhythm, single contextual inspector, outline tree. | `gemini-3.8-flash` on `antigravity` |
| **🛡️ Victor** | **Auditor & QA Custodian**: Compilation verification, test matrices, regression prevention, `MEMORY.md` updates. | `openai/gpt-oss-120b` / `gemini-3.8-flash` |
| **🔍 Sam** | **Research Specialist**: TextKit 2 `NSTextLayoutManager` multi-page exclusion paths & printing APIs. | `gemini-3.8-flash` on `antigravity` |

---

## 🚀 Sprint-by-Sprint Execution Roadmap

### Sprint 1: Surgical De-Bloat & Pure-Swift Consolidation (Immediate)
* **Goal**: Strip away dead weight, uncouple from Rust FFI, and get `swift build` down to a lightning-fast, zero-warning build.
* **Arthur's Task**: Define Swift-native replacement for `letters_core` (consolidate the 40+ lint rules in `CoreBridge.swift` into pure Swift; remove C shims).
* **Finn's Task**:
  1. Remove `StudioVideoView.swift` (video players have no place in a print/docx editor).
  2. Remove `StudioCoverBannerView.swift` (Notion cover emojis violate document margins).
  3. Strip JavaScriptCore formula evaluation from `SmartTableView.swift` (retain clean table borders, padding, and cell styling).
  4. Remove references in `MainEditorView.swift` and `DocumentModel.swift`.
* **Victor's Task**: Run `swift build` after every file removal; verify clean compilation; record invariants in `MEMORY.md`.

---

### Sprint 2: The Unified Canvas (Kill the Slicing Paginator)
* **Goal**: Fix the #1 complaint: jumping cursors, lagging typing, and broken cross-page selections.
* **Architectural Pivot**: Retire the multi-`NSTextView` loop in `DocumentPaginator.swift`. Transition to a **Continuous Single-Container TextKit 2 Canvas** with visual page dividers.
* **Arthur & Sam's Task**: Specify the single `NSTextContainer` flow with visual card backgrounds and margin exclusion paths.
* **Finn's Task**: Refactor `TextKit2EditorView.swift` to host a single primary `StudioTextView`. Eliminate cross-view async focus retry loops (`focusPage` with `asyncAfter`).
* **Iris's Task**: Style the canvas backdrop (Pages-style neutral slate, centered white paper cards with optical drop shadows).
* **Victor's Task**: Verify keystroke latency (<16ms), seamless text selection across page breaks, and working native Undo/Redo (`Cmd+Z`).

---

### Sprint 3: Document Model & Navigation Rigor (MS Word DNA)
* **Goal**: Give the document professional structural organization.
* **Tasks**:
  1. **Strict Swift Block AST**: Formalize `Document` into typed blocks (`Heading(level, text)`, `Paragraph(runs)`, `Table(cells)`, `Figure(image, caption)`, `Citation(key)`).
  2. **Left Outline Navigation Pane**: Live heading tree extracted from the document AST with 1-click jump and drag-to-reorganize sections.
  3. **Right Contextual Inspector**: Replace 5 floating toolbars with Pages' clean single inspector (Text / Table / Layout tabs).
  4. **Dynamic Bibliography**: Polish the existing APA 7, MLA 9, and Chicago reference engine.

---

### Sprint 4: Ambient AI Co-Authoring (Next-Gen Writing)
* **Goal**: Turn AI into an intuitive co-author, not a generic chat box.
* **Tasks**:
  1. **Inline Ghostwriting (Tab to Complete)**: Subtle grey predicted completions on pause. Press `Tab` to accept, continue typing to dismiss.
  2. **Inline Transform (`Cmd+K`)**: Highlight text $\to$ `Cmd+K` $\to$ prompt $\to$ **Live inline diff view** (green additions, red strikethrough) with Accept/Reject.
  3. **Background Margin Reviewer**: Background agent flags style violations or unverified claims as Google Docs-style margin suggestion cards.
  4. **Multi-Model BYOK Gateway**: Direct support for Anthropic Claude, OpenAI, and local Ollama models.

---

## 🛡️ Active Invariants & Lessons Learned (to sync with `MEMORY.md`)
1. **Never use multiple `NSTextView`s for pagination in TextKit 2**: It breaks selection across page boundaries and causes focus-flicker race conditions.
2. **Never store structural blocks as raw regex strings (`[[table:...]]`)**: Always use a typed AST.
3. **Keep the toolchain 100% native Swift for macOS**: Minimizes build time, removes ABI mismatch, and ensures sub-second compilation.
