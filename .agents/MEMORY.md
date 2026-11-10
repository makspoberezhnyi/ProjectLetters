# Project Letters: Active Invariants & System Memory

## 🏛️ Verified Architectural Invariants
1. **Single-Container Text Backing**:
   - In TextKit 2 on macOS, never split a document across multiple `NSTextView` instances. Multi-view slicing breaks cross-page text selection, induces cursor-jumping race conditions during typing, and breaks native macOS `UndoManager`.
   - Use a continuous text container with visual page dividers or margin exclusion paths.

2. **Single Toolchain / Pure-Swift on macOS**:
   - Do not burden the macOS desktop client with a separate Rust dylib and C shim FFI. All styling, parsing, and linting rules run natively and faster in Swift.
   - If Windows support is added in the future, use the official Swift for Windows toolchain or a headless Swift/C core.

3. **Strict Document Block Model**:
   - Do not represent document structure using arbitrary text markers like `[[table:UUID]]` or `[[video:UUID]]` inside flat strings. Keep structural elements in a typed `Document` AST with dedicated block identifiers.

4. **UI De-Cluttering & Ergonomics**:
   - Avoid overlapping floating HUDs and islands. Use a unified three-pane layout:
     - Left: Word-style Document Outline / Navigation Pane with real-time scroll-spy.
     - Center: Pages-style Paper Canvas with triple-layer optical drop shadows.
     - Right: Single Contextual Inspector (Text & Style / Page Setup / Citations & Research) that automatically adapts to cursor selection.

5. **Typographic Rhythm & Line Height Invariant**:
   - Editorial body copy (New York) must strictly adhere to the 1.25x line height ratio (e.g. 12pt body with 15pt baseline leading) to ensure vertical rhythm and avoid diacritic collisions.
   - UI chrome and outline navigation must use SF Pro Text with tabular numbers (`.monospacedDigit()`).

6. **Ambient AI Interaction Paradigm**:
   - No generic modal chat windows on top of the document.
   - Use non-disruptive inline Ghostwriting (Tab to accept, 40% opacity grey text).
   - Use floating selection-anchored `Cmd+K` capsule with colored diff previews (red strikethrough, green addition).
   - Margin review cards pinned to paragraph baselines in the outer right canvas gutter.

## 🚀 Resolved Milestones
* **Sprint 1 (De-Bloat & Pure-Swift Consolidation)**: Excised JavaScriptCore from `SmartTableView`, removed video embeds and Notion cover banners. Pure Foundation math evaluation.
* **Sprint 2 (The Unified Canvas)**: Implemented continuous single-container TextKit 2 canvas (`unifiedSanctuaryCanvas`) with Pages-style triple-layer compound shadow, dynamic visual page dividers (`Page X of Y`), resizable `StudioTextView` intrinsic content sizing, and zero-latency cursor focus. All tests pass with zero warnings.
