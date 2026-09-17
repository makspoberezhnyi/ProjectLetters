---
name: document-architecture
description: >-
  Standards for lossless document packaging (.letters bundle and .docx OpenXML),
  reactive formula evaluation engine, and dynamic bibliography standards.
---

# Document Studio Architecture & Data Pipeline Guide

This skill specifies file container architecture, reactive formula execution, and citation standards for Project Letters.

---

## 1. Bundle Container Architecture (`.letters`)

A `.letters` document is stored as a compressed or directory-based JSON document bundle containing:
* `manifest.json`: Document title, version, creation/modification timestamps.
* `document.json`: Full serialized `LettersDocumentBundle` state (text, typography, margins, canvas zoom).
* `assets/`: Embedded images, figures, and video metadata cards.

---

## 2. Dynamic Smart Table & Formula Evaluation

* **Grid Coordinates**: 1-based indexing (`A1`, `B2`, `C3`).
* **Formula Syntax**: `=SUM(A1:A5)`, `=AVERAGE(B1:B10)`, `=A1+B1`, `=A1*1.15`, `=A1-B1`.
* **Reactive Graph**: When cell content changes, dependent formula cells evaluate automatically via recursive token parsing.
