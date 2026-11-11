# Letters — UI/UX Craft Architecture & Design Specification
**Director**: Iris, Interface Craft & UI/UX Director (`model-orchestration` Studio)  
**Project**: Letters (macOS Native DTP & Editorial Word Processor)  
**Target Repository**: `/Users/mpob/Developer/projectletters`  
**Branch**: `feat/reboot-clean-architecture`  
**Document Status**: Official Approved Craft Specification (Sprint 1–4)

---

## Executive Design Manifesto: The Triad Synthesis

The rebooted **Letters** application synthesizes three distinct desktop paradigms into a unified, distraction-free macOS native document environment:
1. **Apple Pages (The Aesthetic Sanctuary)**: Neutral canvas backdrop, floating paper sheets with physically authentic optical shadows, refined margins, and print-grade typography rhythm.
2. **Google Docs (Frictionless Review & Clarity)**: Non-intrusive margin annotations, clear diff previews, collaborative clarity, and instantaneous feedback without modal friction.
3. **Microsoft Word (Navigational & Structural Rigor)**: Deep document outline tree, persistent heading hierarchy, reliable citation formatting (APA/MLA/Chicago), and structured block integrity.

Crucially, Letters elevates this triad with **Ambient AI Co-Authoring**: intelligence integrated into the editorial flow rather than segregated into a chat sidebar.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   LETTERS WINDOW CHROME                                │
├───────────────┬────────────────────────────────────────────────────────┬───────────────┤
│ OUTLINE PANE  │                   CANVAS SANCTUARY                     │  INSPECTOR    │
│ (Word Rigor)  │                    (Pages Optics)                      │ (Pages / HIG) │
│               │                                                        │               │
│ • Live Tree   │   ┌────────────────────────────────────────────────┐   │ [Text]        │
│ • H1 / H2 / H3│   │ Document Sheet (US Letter / A4)                │   │ [Page]        │
│ • Scroll-Spy  │   │                                                │   │ [Citations]   │
│ • Drag-Order  │   │  Heading 1 (SF Pro Display, 20pt)              │   │               │
│ • Word Counts │   │                                                │   │ Adaptive to:  │
│               │   │  Body paragraph rendered in New York 12pt      │   │ • Selection   │
│               │   │  with exact 1.25x leading (15pt baseline).     │   │ • Table Cell  │
│               │   │  Ghostwriting suggestion in 40% muted grey...  │   │ • Image       │
│               │   │                                                │   │ • Citation    │
│               │   └────────────────────────────────────────────────┘   │               │
│               │         Margin Review Note ──► [Grammar Card]          │               │
└───────────────┴────────────────────────────────────────────────────────┴───────────────┘
```

---

## 1. Canvas Sanctuary Architecture

### 1.1 Neutral Canvas Background & Dynamic Surface Optics
The canvas serves as an acoustic dampener for the visual senses. It isolates the working paper surface from macOS chrome and ambient desktop wallpaper.

* **Light Mode Canvas Backdrop**:
  - Color: Dynamic warm stone slate (`#F2F1EE` / `NSColor(name: nil, dynamicProvider: { $0.name == .darkAqua ? ... : ... })`).
  - Subtle noise texture / vignette: 0% opacity (pure flat neutral tone, avoiding artificial skeuomorphic noise).
* **Dark Mode Canvas Backdrop**:
  - Color: Deep graphite charcoal (`#1C1C1E`).
  - Neutrality: Avoids pure black (`#000000`) to preserve contrast with paper card borders and prevent OLED smearing.

```swift
// Theme Tokens for Canvas
extension StudioTheme {
    public static let canvasBackdrop = Color(
        NSColor(name: "CanvasBackdrop", dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0) // #1C1C1E
                : NSColor(red: 0.949, green: 0.945, blue: 0.933, alpha: 1.0) // #F2F1EE
        })
    )

    public static let paperBackdrop = Color(
        NSColor(name: "PaperBackdrop", dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.155, green: 0.155, blue: 0.165, alpha: 1.0) // #27272A
                : NSColor.white
        })
    )
}
```

### 1.2 Floating Paper Shadow Optics
To produce physical depth without heavy, muddy blur, Letters utilizes a **triple-layer compound optical shadow**:
1. **Contact Occlusion Shadow**: Mimics the micro-gap between the paper sheet and the desk surface.
2. **Ambient Diffuse Shadow**: Casts the primary soft dispersion of overhead ambient light.
3. **Ground Elevation Shadow**: Establishes the sheet's 8pt elevation above the canvas.
4. **Dark-Mode Optical Keyline**: In dark mode, shadows disappear into the black floor. A crisp 0.5pt hairline border provides optical definition.

```swift
public struct PaperElevationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content
            // Layer 1: Sharp contact shadow
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04),
                radius: 1.5,
                x: 0,
                y: 1
            )
            // Layer 2: Mid-range ambient diffusion
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.07),
                radius: 12,
                x: 0,
                y: 6
            )
            // Layer 3: Deep elevation drop
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05),
                radius: 28,
                x: 0,
                y: 16
            )
            // Optical perimeter border for high-contrast sheet boundary
            .overlay(
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.09)
                            : Color.black.opacity(0.04),
                        lineWidth: 0.5
                    )
            )
    }
}
```

### 1.3 Page Division Aesthetics (Continuous Single-Container)
In accordance with `MEMORY.md` invariant #1, Letters uses a **Continuous Single-Container TextKit 2 Canvas** with optical page breaks rather than slicing documents across multiple `NSTextView`s.

* **Inter-Page Gutter Height**: Exactly `32pt` spacing between virtual pages.
* **Page Boundary Graphic**:
  - Horizontal hairline: 1pt dashed line (`stroke: [3, 3]`), color `Color.secondary.opacity(0.18)`.
  - Margins: Inset by `48pt` from each sheet edge.
  - Page Number Badge: Pill badge positioned in the right gutter (`p. 2 of 5`), font `SF Pro Text 10pt Medium`, background `.ultraThinMaterial`, padding `horizontal: 8pt, vertical: 3pt`.
* **Print Sheet Dimensions**:
  - US Letter: `612pt × 792pt` (8.5 × 11.0 in).
  - Standard Margin: `72pt` (1.0 in) uniform.
  - Printable Text Column Width: `468pt` (`612 - 144`). This yields the ideal 65–75 characters per line for optimal reading ergonomics.
  - A4: `595pt × 842pt` (210 × 297 mm) with `70pt` margins.

---

## 2. Typographic Hierarchy & Vertical Rhythm

### 2.1 The Two-System Typographic Pairing
* **Application Chrome & UI (High-Density Humanist)**: `SF Pro` and `SF Pro Text`
  - High legibility at 10–13pt desktop densities.
  - Tabular numbers (`.monospacedDigit()`) for metrics, line counters, and zoom steppers.
* **Document Body & Editorial Prose (Literary Craft)**: `Apple New York`
  - Optical sizes dynamically matched to point size:
    - `Small`: 6pt – 10pt (footnotes, source indices).
    - `Medium`: 10pt – 14pt (body copy, blockquotes).
    - `Large`: 15pt – 24pt (subheadings, section headers).
    - `Extra Large`: 25pt+ (document title, chapter covers).
* **Alternate Humanist Sans Body Option**: `SF Pro Text`
  - Selectable in document inspector for technical papers, business reports, or modern pitch decks.

### 2.2 Exact Metrics & Line Height Multipliers

All leading and spacing are governed by a strict **1.20x – 1.25x line height ratio** to eliminate collisions with diacritics while preserving tight, cohesive paragraph density.

| Role | Font Family | Size | Leading (Line Height) | Ratio | Weight | Tracking | Space Before | Space After |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Document Title** | SF Pro Display | 28pt | 34pt | 1.21x | Bold (700) | -0.30pt | 0pt | 12pt |
| **Subtitle** | New York Large | 16pt | 21pt | 1.25x | Regular Italic | -0.10pt | 0pt | 20pt |
| **Heading 1 (H1)** | SF Pro Display | 20pt | 25pt | 1.25x | Semi-Bold (600) | -0.20pt | 22pt | 6pt |
| **Heading 2 (H2)** | SF Pro Display | 15pt | 19pt | 1.26x | Semi-Bold (600) | -0.10pt | 16pt | 4pt |
| **Heading 3 (H3)** | SF Pro Text | 13pt | 16.5pt | 1.27x | Medium (500) | 0.00pt | 12pt | 3pt |
| **Body (Editorial)** | New York Medium | 12pt | 15pt | **1.25x** | Regular (400) | 0.00pt | 0pt | 8pt |
| **Body (Humanist Sans)** | SF Pro Text | 11.5pt | 14.5pt | **1.26x** | Regular (400) | -0.05pt | 0pt | 8pt |
| **Blockquote** | New York Medium | 11.5pt | 15pt | 1.30x | Italic (400) | 0.00pt | 10pt | 10pt |
| **Footnote / Citation** | New York Small | 9pt | 11.5pt | 1.27x | Regular (400) | +0.05pt | 4pt | 2pt |
| **Inspector Labels** | SF Pro Text | 11pt | 13pt | 1.18x | Medium (500) | 0.00pt | 0pt | 0pt |
| **Badge / Counter** | SF Pro Compact | 10pt | 12pt | 1.20x | Bold (700) | +0.10pt | 0pt | 0pt |

### 2.3 Paragraph Indentation & Spacing Modes
Letters supports two distinct paragraph styles with a 1-click toggle in the inspector:
1. **Modern Block Style (Default)**: `0pt` first-line indent, `8pt` paragraph bottom spacing.
2. **Academic / Literary Style**: `24pt` (`0.33in`) first-line indent, `0pt` paragraph bottom spacing. (First paragraph directly following a heading automatically suppresses indent).

---

## 3. Left Outline Navigation Pane (Word Rigor + macOS HIG)

The left navigation pane replaces floating TOC modals with a persistent, collapsible sidebar adhering to macOS 3-pane `NavigationSplitView` architecture.

```
┌──────────────────────────────────────────────────┐
│  OUTLINE                                [ \u2318F ]  │
├──────────────────────────────────────────────────┤
│  Q  Filter Headings...                           │
├──────────────────────────────────────────────────┤
│  ▼  1. Introduction                       180 w  │
│  │    1.1 Background & Motivation          94 w  │
│  │    1.2 Problem Statement                65 w  │
│  │                                               │
│  ▼ ▌2. Theoretical Framework              412 w  │ ◄── Active Scroll-Spy
│       2.1 Semantic Parsing Models         120 w  │     (Accent Pill Indicator)
│       2.2 Dynamic Citation Graph          292 w  │
│                                                  │
│  ▶  3. Experimental Evaluation            830 w  │
│                                                  │
│  ▼  4. Bibliography & Sources              14 s  │
└──────────────────────────────────────────────────┘
```

### 3.1 Structural Hierarchy & Visual Indentation
* **Base Width**: Default `240pt`, resizable between `180pt` and `340pt`.
* **Indentation Grid**:
  - H1: `12pt` leading padding. Font: `SF Pro Text 12pt Semi-Bold`. Color: `.primary`.
  - H2: `24pt` leading padding. Font: `SF Pro Text 11.5pt Regular`. Color: `.primary.opacity(0.85)`.
  - H3: `36pt` leading padding. Font: `SF Pro Text 11pt Regular`. Color: `.secondary`.
* **Disclosure Indicator**:
  - 8pt `chevron.right` icon rotating smoothly 90° on toggle with `.spring(response: 0.22, dampingFraction: 0.8)`.

### 3.2 Real-Time Scroll-Spy Active Indicator
As the user scrolls the document or moves the cursor, the active section is highlighted without latency:
* **The Active Beacon**: A vertical capsule indicator (`2.5pt` width, `16pt` height, `CornerRadius: 1.25pt`) pinned to the far leading edge of the active item.
* **Color**: Native `Color.accentColor` (or deep cobalt).
* **Row Highlight**: Background fill `Color.accentColor.opacity(0.08)` with continuous rounded rectangle corners (`cornerRadius: 6pt`).

### 3.3 Drag-to-Reorganize Interaction
* **Hover Affordance**: Hovering over an outline row reveals a 6-dot drag grip (`Image(systemName: "line.3.horizontal")`) on the leading edge (opacity: 0.4 on hover, 0.8 on press).
* **Drag Execution**:
  - Dragging an H1 automatically drags all subordinate H2 and H3 children.
  - Drop Target Feedback: A 2pt solid horizontal accent line with a leading circle indicator (`●───────────`) appears between rows.
  - AST Operation: Triggers atomic relocation of the corresponding document section in the Swift block AST, maintaining undo history (`Cmd+Z`).

### 3.4 Micro-Interactions & Keyboard Accessibility
* `Cmd+Alt+LeftArrow` / `RightArrow`: Collapse or expand all outline nodes.
* `Cmd+Alt+UpArrow` / `DownArrow`: Move selected section up/down in document structure.
* Search Filter: Top search field filters the tree instantly, dimming unmatched headings to 20% opacity.

---

## 4. Single Contextual Right Inspector

### 4.1 Consolidating the Floating Clutter
Previous builds of Letters had accumulated five competing overlay elements:
1. `StudioFloatingSidebar` (vertical floating bar)
2. `StudioFloatingBottomBar` (status + controls pill)
3. `FloatingActionMenu` (hovering formatting menu)
4. `StudioPageDesignView` (floating popover sheet)
5. `AssistantSidebarView` (secondary assistant drawer)

**The Architectural Solution**: All five HUDs are retired in favor of a single, unified macOS Inspector panel (`.inspector(isPresented:)`), docked to the right edge with a fixed width of `280pt`.

### 4.2 The Unified Three-Tab System

```
┌────────────────────────────────────────────────────────┐
│  [  Text & Style  ]   [  Page Setup  ]   [  Citations  ]│
├────────────────────────────────────────────────────────┤
│  TYPOGRAPHY                                            │
│  ┌─────────────────────────────┬────────────────────┐  │
│  │ New York (Serif)          ▼ │ 12 pt            ▼ │  │
│  └─────────────────────────────┴────────────────────┘  │
│  B   I   U   S   |   A   |   \u2261   \u2261   \u2261   \u2261             │
│                                                        │
│  SPACING & RHYTHM                                      │
│  Line Height Multiplier:  [ 1.25x ▼ ]                  │
│  Paragraph Spacing:       [  8 pt   ]                  │
│  First Line Indent:       [  0 pt   ]                  │
│                                                        │
│  STYLE PRESET                                          │
│  [  Body Text                  ▼  ]   [ Update Style ] │
├────────────────────────────────────────────────────────┤
│  DYNAMIC CONTEXTUAL SECTION:                           │
│  (Automatically transforms when table or media active) │
└────────────────────────────────────────────────────────┘
```

#### Tab 1: Text & Style
* **Font Family Selector**: Quick-segmented toggle between `New York (Serif)` and `SF Pro (Sans)`, plus system font picker dropdown.
* **Optical Size Indicator**: Automatic optical size badge (`Small`, `Medium`, `Large`, `Expanded`) displayed next to size.
* **Formatting Bar**: Native toggle button group: Bold, Italic, Underline, Strikethrough, Superscript, Subscript.
* **Line Height & Spacing Multiplier**: Exact stepper control: `1.15x`, `1.20x`, `1.25x`, `1.50x`, `2.00x`.
* **Paragraph Indent Modes**: Toggle between Block (space after) and Academic (first-line indent 0.33in).

#### Tab 2: Page Setup & Layout
* **Paper Dimension Presets**: US Letter (8.5 × 11"), A4 (210 × 297mm), Executive, Legal.
* **Orientation**: Portrait / Landscape visual icons.
* **Margin Editors**: Exact 4-axis stepper (Top, Bottom, Left, Right in inches or millimeters).
* **Layout Guides**:
  - Show Margin Boundary Hairlines (toggle).
  - Show Page Break Dividers (toggle).
* **Header & Footer**: Distance from edge (default: `36pt` / 0.5in), Different First Page checkbox.

#### Tab 3: Citations & Research
* **Citation Style Preset**: Segmented picker: `APA 7`, `MLA 9`, `Chicago 17`, `Bluebook`.
* **Linked Sources Table**: Clean list of all cited references in the document with completeness check indicators (green check = complete, yellow exclamation = missing year/author).
* **Add Source Action**: `+ Add New Source` button opening the standard source attribution sheet.
* **Bibliography Section**: 1-click `Insert / Refresh Bibliography` button formatting the bibliography block at the end of the document according to the active citation style.

### 4.3 Selection-Adaptive Contextual Intelligence
The inspector dynamically morphs its primary content based on cursor selection:
* **Cursor in Text**: Displays standard **Text & Style** tab.
* **Cursor in Smart Table**: Text tab injects a top priority **Table Geometry & Cell Styling** panel (Row/Col Insert, Border Weights, Cell Background Tint, Alignment, Number Formatting).
* **Image / Figure Selected**: Inspector immediately adapts to **Media Properties** (Dimensions, Aspect Ratio Lock, Text Wrapping: Inline, Wrap Tight, Break Text, Caption Text, Alt Text).
* **Citation Tag Clicked**: Automatically navigates to **Citations** tab, scrolling to and highlighting the referenced source.

---

## 5. Ambient AI Interaction Design

Letters rejects generic chat boxes. AI co-authoring is woven directly into the text editing canvas with three ambient interaction models:

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ 1. INLINE GHOSTWRITING (Tab to Accept)                                        │
│                                                                               │
│ In recent years, dynamic document architectures have begun to prioritize      │
│ native compilation over web wrappers [because sub-16ms latency ensures       │
│ tactile direct manipulation for long-form authoring.] ◄─ 40% Grey Ghost Text  │
│                                              └── [Tab] Accept  [Esc] Dismiss  │
└───────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│ 2. CMD+K INLINE TRANSFORM BAR                                                 │
│                                                                               │
│ ┌───────────────────────────────────────────────────────────────────────────┐ │
│ │  ✦ Ask AI to transform selection...                    [ \u21b5 Return to run ] │ │
│ ├───────────────────────────────────────────────────────────────────────────┤ │
│ │ [ Make Concise ]   [ Academic Tone ]   [ Fix Grammar ]   [ Add APA Cite ] │ │
│ └───────────────────────────────────────────────────────────────────────────┘ │
│                               ▲                                               │
│ ┌─────────────────────────────┴─────────────────────────────────────────────┐ │
│ │  DIFF PREVIEW:                                                            │ │
│ │  The system ~~utilizes a heavy Electron stack~~                           │ │
│ │  {++leverages a lightweight pure-Swift TextKit 2 engine++} to achieve     │ │
│ │  sub-second launch times.                                                 │ │
│ │                                                  [ \u2318\u21b5 Accept ]  [ Esc Reject ] │ │
│ └───────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│ 3. MARGIN EDITORIAL REVIEW NOTES (Google Docs Clarity + Pages Polish)        │
│                                                                               │
│  ...for all academic publications.────┐                                       │
│                                       │ (Connecting Hairline)                 │
│                                       ▼                                       │
│                               ┌─────────────────────────────────────────────┐ │
│                               │ ⚠ Style Invariant (APA 7)                   │ │
│                               │ Prefer active voice over passive voice.     │ │
│                               │ "Publications require..."                   │ │
│                               │                                             │ │
│                               │ [ Apply Fix ]              [ Dismiss ]      │ │
│                               └─────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 5.1 Inline Ghostwriting (Tab to Complete)
* **Trigger Mechanism**: Activates after a `650ms` idle pause following the entry of a sentence-ending space or punctuation mark.
* **Visual Rendering**:
  - Ghost text is drawn directly within the active TextKit 2 layout line fragment.
  - Matches the exact font family, optical size, tracking, and leading of the current text run.
  - Color: `Color.primary.opacity(0.38)` (or `NSColor.placeholderTextColor`).
  - No layout jitter: Existing wrapped text lines remain stationary while the ghost completion trails into the margin.
* **Keyboard Commands**:
  - `Tab`: Accept full suggestion and append to text storage.
  - `Option + RightArrow`: Accept next word only (incremental acceptance).
  - Any alphanumeric keystroke or `Esc`: Instantly and silently dismisses the prediction.

### 5.2 `Cmd+K` Inline Transform Bar
* **Invocation**: Selecting any text range and pressing `Cmd+K` spawns the floating command capsule.
* **Spatial Anchoring**:
  - Positions `8pt` directly below the selection bounding rect, horizontally centered.
  - If selection is near the bottom window edge, it flips intelligently to `8pt` above the selection.
  - Material: `.ultraThinMaterial` with continuous rounded corners (`cornerRadius: 10pt`) and `0.5pt` border stroke.
* **Quick Action Pills**:
  - `Make Concise`: Tightens prose without losing empirical detail.
  - `Academic Tone`: Upgrades colloquial phrasing to formal academic standards.
  - `Fix Grammar`: Corrects punctuation and syntactic structure.
  - `Add Citation`: Scans highlighted claim and queries the source library.
* **Live Inline Diff Preview**:
  - Deletions: Red strikethrough with soft coral background (`Color.red.opacity(0.12)`, strike color `Color.red.opacity(0.8)`).
  - Additions: Clean text with soft emerald background (`Color.green.opacity(0.14)`).
  - Key Accelerators: `Cmd+Enter` to accept replacement; `Esc` to revert to original text.

### 5.3 Margin Editorial Notes (Google Docs Clarity + Pages Polish)
* **Placement**: Floats in the outer right margin gutter (`16pt` outside the paper edge), vertically pinned to the baseline of the flagged paragraph.
* **Visual Geometry**:
  - Width: Fixed `220pt`.
  - Material: Secondary background card (`NSColor.controlBackgroundColor`) with `8pt` rounded corners and subtle drop shadow (`radius: 8, y: 4, opacity: 0.08`).
  - Category Badges:
    - Amber badge (`exclamationmark.triangle`): Style or tone warning.
    - Blue badge (`quote.opening`): Missing or invalid source citation.
    - Purple badge (`sparkles`): AI structural suggestion.
* **Connecting Hairline**: When a margin note is hovered or active, a subtle `0.5pt` curved bezier line connects the card to the highlighted sentence span on the paper sheet.
* **One-Click Resolution**: Cards feature an `[Apply Fix]` button that atomically performs the edit, records the undo step, and collapses the card with an exit fade animation.

---

## 6. Implementation Reference Architecture (SwiftUI & TextKit 2)

### 6.1 Master View Topology

```swift
// Master Three-Pane Architecture for Rebooted Letters
public struct LettersMasterCanvasView: View {
    @StateObject private var documentController = LettersDocumentController()
    
    // UI Layout State
    @State private var showOutline: Bool = true
    @State private var showInspector: Bool = true
    @State private var inspectorTab: InspectorTab = .textAndStyle
    @State private var zoomLevel: Double = 1.0

    // Ambient AI State
    @State private var isCmdKPresented: Bool = false
    @State private var ghostwritingProposal: String? = nil

    public var body: some View {
        NavigationSplitView {
            // 1. Left Outline Navigation Pane (Word Rigor)
            DocumentOutlinePane(
                document: documentController.document,
                currentScrollOffset: $documentController.scrollOffset,
                onSelectHeading: { heading in
                    documentController.jumpToHeading(heading)
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            // 2. Central Sanctuary Canvas (Pages Aesthetics)
            ZStack {
                StudioTheme.canvasBackdrop
                    .ignoresSafeArea()

                ScrollView([.vertical, .horizontal]) {
                    CanvasPaperContainerView(
                        documentController: documentController,
                        zoomLevel: zoomLevel,
                        ghostwritingProposal: $ghostwritingProposal
                    )
                    .padding(.vertical, 40)
                    .padding(.horizontal, 60)
                }

                // Inline Cmd+K Bar Overlay
                if isCmdKPresented {
                    InlineCmdKOverlay(
                        selectionRange: documentController.selectedRange,
                        onDismiss: { isCmdKPresented = false }
                    )
                }
            }
            // 3. Single Contextual Right Inspector (Consolidated HUDs)
            .inspector(isPresented: $showInspector) {
                ContextualInspectorView(
                    activeTab: $inspectorTab,
                    selectionState: documentController.currentSelectionContext,
                    document: $documentController.document
                )
                .inspectorColumnWidth(min: 260, ideal: 280, max: 340)
            }
        }
        .toolbar {
            LettersUnifiedToolbar(
                showOutline: $showOutline,
                showInspector: $showInspector,
                zoomLevel: $zoomLevel,
                onTriggerAI: { isCmdKPresented = true }
            )
        }
    }
}
```

### 6.2 Visual Verification Matrix

| UI Component | Verification Metric | Pass Criteria |
| :--- | :--- | :--- |
| **Canvas Contrast** | WCAG 2.2 AA Contrast | Light mode canvas/sheet contrast $\ge 1.15:1$; Dark mode $\ge 1.25:1$ with 0.5pt keyline. |
| **Typographic Leading** | Ratio check | Body leading is strictly $1.25\times \pm 0.01$ (e.g., 12pt size / 15pt line height). |
| **Scroll-Spy Latency** | Scroll tracking response | Indicator pill updates active heading within 1 frame (16ms) during fast scroll. |
| **Inspector Density** | Vertical screen budget | All essential typography controls visible without scrolling on standard 900pt display height. |
| **Ghostwriting Jitter** | Layout invalidation check | Ghost text rendering produces 0pt layout displacement of preceding text. |
| **Diff Rendering** | Visual clarity | Strikethrough and insertions are unambiguously color-coded with high legibility. |

---

## 7. Migration Roadmap for Phase 2 & 3

1. **Excision**: Deprecate and delete `StudioFloatingSidebar.swift`, `StudioFloatingBottomBar.swift`, and `FloatingActionMenu.swift` in favor of `ContextualInspectorView.swift`.
2. **Backdrop Refinement**: Update `StudioTheme.swift` with the triple-layer paper elevation modifier and dynamic stone canvas color.
3. **Typography Standard**: Wire `NSTextLayoutManager` default paragraph styles to use the exact 1.25x leading constants.
4. **Outline Integration**: Connect the live block AST heading tree directly into `DocumentOutlinePane` with smooth scroll-spy.
5. **Inline AI Polish**: Refactor `InlineAICanvasEditorView.swift` into the lightweight anchored `Cmd+K` capsule.
