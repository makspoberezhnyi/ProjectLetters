---
name: macos-hig-design
description: >-
  Expert guide and best practices for native macOS desktop UI/UX, Apple Human Interface Guidelines (HIG),
  SwiftUI materials/vibrancy, keyboard navigation, pointer tracking, and windowing chrome.
---

# macOS HIG Design & SwiftUI Desktop Engineering Guide

This skill provides design standards, metrics, and implementation patterns for native macOS desktop applications built with SwiftUI and AppKit.

---

## 1. Core macOS Desktop Principles vs. iOS

| Principle | macOS Desktop | iOS / iPadOS |
| :--- | :--- | :--- |
| **Input Fidelity** | High precision cursor, hover states (`onHover`), right-click menus, drag handles | Touch targets (min 44pt), swipe gestures |
| **Window Materials** | Dynamic vibrancy (`.ultraThinMaterial`, `NSVisualEffectView`), wallpaper tinting | Solid opaque or blurred backdrops |
| **Navigation Chrome** | Unified titlebars, 3-pane `NavigationSplitView`, collapsible inspector sidebars | `NavigationStack`, bottom tab bar |
| **Keyboard Integration** | Full menubar routing (`CommandMenu`), single-key & modifier shortcuts, `⌘K` palette | Soft keyboard, limited accelerators |
| **Typography Scale** | Desktop density: Body 13pt, Captions 10–11pt, Title 18–24pt | Mobile density: Body 17pt, Title 28–34pt |

---

## 2. Dynamic Vibrancy & Frosted Glass Materials

Use native system materials instead of hardcoded RGBA values:

```swift
// Modern macOS Floating Glass Card
VStack {
    // Content
}
.padding(12)
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
)
.shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
```

---

## 3. Hover Effects & Micro-Interactions

Desktop UI requires instant visual feedback on cursor hover:

```swift
struct DesktopIconButton: View {
    let icon: String
    let isActive: Bool
    let shortcutHint: String
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .accentColor : (isHovered ? .primary : .secondary))
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .help(shortcutHint)
    }
}
```

---

## 4. Typography & Visual Grid

* **San Francisco & New York**: Always pair SF Pro for UI chrome and New York for editorial paper canvas.
* **Pixel Snapping**: Ensure all borders and line dividers use exact integer alignments or 0.5pt hairpins.
* **Spring Dynamics**: Standardize spring curves for panels: `.spring(response: 0.28, dampingFraction: 0.82)`.
