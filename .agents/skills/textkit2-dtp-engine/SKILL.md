---
name: textkit2-dtp-engine
description: >-
  Advanced guide and engineering patterns for Apple TextKit 2, multi-page canvas layout,
  typography kerning, dynamic blocks, and DTP typesetting on macOS.
---

# TextKit 2 & Desktop Publishing (DTP) Engine Guide

This skill documents architectural patterns and layout mechanics for high-performance desktop publishing using Apple's TextKit 2 framework in SwiftUI and AppKit.

---

## 1. TextKit 2 Core Architecture

* **`NSTextContentStorage`**: Manages underlying `NSTextElement` segments and backing storage.
* **`NSTextLayoutManager`**: Performs asynchronous layout, text fragments computation, line fragments, and coordinate mapping.
* **`NSTextContainer`**: Defines viewport boundaries, margins, exclusion paths for floating images/cards, and page geometries.

---

## 2. Paginated Canvas Flow & Segment Slicing

For multi-page editorial rendering (e.g. Letter, A4, Executive):
* Parse structured inline markers (`[[table:id]]`, `[[image:id]]`, `[[toc]]`, `[[bibliography]]`, `---pagebreak---`).
* Slice continuous text streams into distinct per-page viewport containers while maintaining continuous cursor navigation.
* Compute live Table of Contents markers dynamically from AST headings.
