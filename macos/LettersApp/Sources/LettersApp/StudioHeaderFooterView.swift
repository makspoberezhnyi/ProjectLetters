import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public enum HeaderFooterTarget: String, CaseIterable, Identifiable {
    case header = "Header"
    case footer = "Footer"

    public var id: String { rawValue }
}

public func resolveHeaderFont(fontFamily: String, size: CGFloat = 10.5, weight: Font.Weight = .regular) -> Font {
    switch fontFamily {
    case "SF Pro (Modern Sans)":
        return .system(size: size, weight: weight)
    case "New York (Editorial)":
        return .custom("NewYork-Regular", size: size)
    case "SF Mono (Code)":
        return .system(size: size, weight: weight, design: .monospaced)
    case "Default Serif (Georgia)":
        return .custom("Georgia", size: size)
    default:
        return .custom(fontFamily, size: size)
    }
}

public func resolveNSHeaderFont(fontFamily: String, size: CGFloat = 11.0, weight: NSFont.Weight = .regular) -> NSFont {
    switch fontFamily {
    case "SF Pro (Modern Sans)":
        return NSFont.systemFont(ofSize: size, weight: weight)
    case "New York (Editorial)":
        if weight == .bold {
            if let custom = NSFont(name: "NewYork-Bold", size: size) { return custom }
        }
        if let custom = NSFont(name: "NewYork-Regular", size: size) { return custom }
        return NSFont.systemFont(ofSize: size, weight: weight)
    case "SF Mono (Code)":
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    case "Default Serif (Georgia)":
        if weight == .bold {
            if let custom = NSFont(name: "Georgia-Bold", size: size) { return custom }
        }
        if let custom = NSFont(name: "Georgia", size: size) { return custom }
        return NSFont.systemFont(ofSize: size, weight: weight)
    default:
        if weight == .bold {
            if let custom = NSFont(name: "\(fontFamily)-Bold", size: size) { return custom }
        }
        if let custom = NSFont(name: fontFamily, size: size) { return custom }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Native AppKit Header/Footer Text Slot (Razor-Sharp CoreText)
public struct NativeHeaderSlotField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var alignment: NSTextAlignment
    var font: NSFont
    var textColor: NSColor
    var isEditable: Bool
    var onCommit: (() -> Void)? = nil

    public init(
        text: Binding<String>,
        placeholder: String = "",
        alignment: NSTextAlignment = .left,
        font: NSFont,
        textColor: NSColor = .labelColor,
        isEditable: Bool = true,
        onCommit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.alignment = alignment
        self.font = font
        self.textColor = textColor
        self.isEditable = isEditable
        self.onCommit = onCommit
    }

    public func makeNSView(context: Context) -> NSTextField {
        let tf: NSTextField
        if isEditable {
            tf = NSTextField()
            tf.isEditable = true
            tf.isSelectable = true
        } else {
            tf = NSTextField(labelWithString: text)
            tf.isEditable = false
            tf.isSelectable = false
        }
        tf.isBezeled = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.backgroundColor = .clear
        tf.focusRingType = .none
        tf.alignment = alignment
        tf.font = font
        tf.textColor = textColor
        tf.delegate = context.coordinator
        tf.maximumNumberOfLines = 1
        tf.cell?.wraps = false
        tf.cell?.isScrollable = true
        tf.cell?.usesSingleLineMode = true
        tf.lineBreakMode = .byTruncatingTail
        tf.wantsLayer = true
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        tf.layer?.contentsScale = scale
        tf.layer?.rasterizationScale = scale
        tf.layer?.shouldRasterize = false
        if isEditable && !placeholder.isEmpty {
            tf.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.4),
                    .font: font
                ]
            )
        }
        return tf
    }

    public func updateNSView(_ nsView: NSTextField, context: Context) {
        let scale = nsView.window?.backingScaleFactor ?? (NSScreen.main?.backingScaleFactor ?? 2.0)
        nsView.layer?.contentsScale = scale
        nsView.layer?.rasterizationScale = scale
        nsView.layer?.shouldRasterize = false
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.alignment = alignment
        nsView.font = font
        nsView.textColor = textColor
        nsView.isEditable = isEditable
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeHeaderSlotField

        init(_ parent: NativeHeaderSlotField) {
            self.parent = parent
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        public func controlTextDidEndEditing(_ obj: Notification) {
            parent.onCommit?()
        }
    }
}

public struct NativeFootnoteField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: NSFont
    var textColor: NSColor
    var isEditable: Bool
    var onCommit: (() -> Void)? = nil

    public init(
        text: Binding<String>,
        placeholder: String = "Footnote text...",
        font: NSFont,
        textColor: NSColor = .labelColor,
        isEditable: Bool = true,
        onCommit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.textColor = textColor
        self.isEditable = isEditable
        self.onCommit = onCommit
    }

    public func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBezeled = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.backgroundColor = .clear
        tf.focusRingType = .none
        tf.alignment = .left
        tf.font = font
        tf.textColor = textColor
        tf.isEditable = isEditable
        tf.isSelectable = true
        tf.delegate = context.coordinator
        tf.maximumNumberOfLines = 0
        tf.cell?.wraps = true
        tf.cell?.isScrollable = false
        tf.cell?.usesSingleLineMode = false
        tf.wantsLayer = true
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        tf.layer?.contentsScale = scale
        tf.layer?.rasterizationScale = scale
        tf.layer?.shouldRasterize = false
        if !placeholder.isEmpty {
            tf.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: NSColor.placeholderTextColor,
                    .font: font
                ]
            )
        }
        return tf
    }

    public func updateNSView(_ nsView: NSTextField, context: Context) {
        let scale = nsView.window?.backingScaleFactor ?? (NSScreen.main?.backingScaleFactor ?? 2.0)
        nsView.layer?.contentsScale = scale
        nsView.layer?.rasterizationScale = scale
        nsView.layer?.shouldRasterize = false
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = font
        nsView.textColor = textColor
        nsView.isEditable = isEditable
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeFootnoteField

        init(_ parent: NativeFootnoteField) {
            self.parent = parent
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        public func controlTextDidEndEditing(_ obj: Notification) {
            parent.onCommit?()
        }
    }
}

public struct StudioHeaderView: View {
    @Binding var config: HeaderFooterConfig
    let pageIndex: Int
    let totalPages: Int
    let documentTitle: String
    let margins: PageMargins
    let sheetWidth: CGFloat
    var fontFamily: String = "Default Serif (Georgia)"
    @Binding var isEditing: Bool
    @Binding var activeTarget: HeaderFooterTarget

    @State private var isHovered: Bool = false

    private var isCurrentlyEditing: Bool {
        isEditing && activeTarget == .header
    }

    public var body: some View {
        let isFirstPage = (pageIndex == 0)
        let isSuppressed = config.differentFirstPage && isFirstPage

        ZStack {
            if isCurrentlyEditing {
                // Interactive In-Place Native Editor for Header
                HStack(spacing: 8) {
                    NativeHeaderSlotField(
                        text: Binding(
                            get: { config.headerLeftText.isEmpty ? (isHovered ? "" : documentTitle) : config.headerLeftText },
                            set: { config.headerLeftText = $0 }
                        ),
                        placeholder: "Left header ({title}, {date})...",
                        alignment: .left,
                        font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                        textColor: .labelColor,
                        isEditable: true
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    NativeHeaderSlotField(
                        text: $config.headerCenterText,
                        placeholder: "Center header...",
                        alignment: .center,
                        font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                        textColor: .labelColor,
                        isEditable: true
                    )
                    .frame(maxWidth: .infinity, alignment: .center)

                    NativeHeaderSlotField(
                        text: $config.headerRightText,
                        placeholder: "Right header ({page}, {pages})...",
                        alignment: .right,
                        font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                        textColor: .labelColor,
                        isEditable: true
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .environment(\.colorScheme, .light)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .overlay(
                    HStack {
                        Text("Header • Page \(pageIndex + 1)")
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundColor(.white)
                            .offset(y: -14)
                        Spacer()
                    }
                    .padding(.leading, 4),
                    alignment: .topLeading
                )
            } else {
                // Normal Display with Direct Native CoreText Rendering
                HStack {
                    let leftStr = config.evaluateHeader(slot: .left, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)
                    let centerStr = config.evaluateHeader(slot: .center, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)
                    let rightStr = config.evaluateHeader(slot: .right, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)

                    if isSuppressed {
                        Text("First Page Header (Suppressed)")
                            .font(resolveHeaderFont(fontFamily: fontFamily, size: 11, weight: .regular))
                            .foregroundColor(.secondary.opacity(0.4))
                            .italic()
                        Spacer()
                    } else {
                        NativeHeaderSlotField(
                            text: .constant(leftStr),
                            placeholder: "",
                            alignment: .left,
                            font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                            textColor: .labelColor,
                            isEditable: false
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if !centerStr.isEmpty {
                            NativeHeaderSlotField(
                                text: .constant(centerStr),
                                placeholder: "",
                                alignment: .center,
                                font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                                textColor: .labelColor,
                                isEditable: false
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                        }

                        NativeHeaderSlotField(
                            text: .constant(rightStr),
                            placeholder: "",
                            alignment: .right,
                            font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                            textColor: .labelColor,
                            isEditable: false
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    isHovered
                        ? Color.accentColor.opacity(0.06)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .overlay(
                    Group {
                        if isHovered {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .overlay(
                                    Text("Double-click to edit Header")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.85), in: Capsule())
                                        .foregroundColor(.white)
                                        .offset(y: -12),
                                    alignment: .topTrailing
                                )
                        }
                    }
                )
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        activeTarget = .header
                        isEditing = true
                    }
                }
                .help("Double-click to edit Header & Page Numbering")
            }
        }
        .padding(.horizontal, margins.left)
        .padding(.top, max(4, margins.top / 2 - 8))
        .frame(width: sheetWidth)
    }
}

public struct StudioFooterView: View {
    @Binding var config: HeaderFooterConfig
    let pageIndex: Int
    let totalPages: Int
    let documentTitle: String
    let margins: PageMargins
    let sheetWidth: CGFloat
    let sheetHeight: CGFloat
    var fontFamily: String = "Default Serif (Georgia)"
    @Binding var isEditing: Bool
    @Binding var activeTarget: HeaderFooterTarget

    @State private var isHovered: Bool = false

    private var isCurrentlyEditing: Bool {
        isEditing && activeTarget == .footer
    }

    public var body: some View {
        let isFirstPage = (pageIndex == 0)
        let isSuppressed = config.differentFirstPage && isFirstPage

        ZStack {
            if isCurrentlyEditing {
                // Interactive In-Place Native Editor for Footer
                HStack(spacing: 8) {
                    NativeHeaderSlotField(
                        text: $config.footerLeftText,
                        placeholder: "Left footer ({date}, Confidential)...",
                        alignment: .left,
                        font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                        textColor: .labelColor,
                        isEditable: true
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    NativeHeaderSlotField(
                        text: $config.footerCenterText,
                        placeholder: "Center footer...",
                        alignment: .center,
                        font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                        textColor: .labelColor,
                        isEditable: true
                    )
                    .frame(maxWidth: .infinity, alignment: .center)

                    NativeHeaderSlotField(
                        text: $config.footerRightText,
                        placeholder: "Right footer ({page}, {pages})...",
                        alignment: .right,
                        font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                        textColor: .labelColor,
                        isEditable: true
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .environment(\.colorScheme, .light)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .overlay(
                    HStack {
                        Text("Footer • Page \(pageIndex + 1)")
                            .font(.system(size: 9.5, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundColor(.white)
                            .offset(y: 14)
                        Spacer()
                    }
                    .padding(.leading, 4),
                    alignment: .bottomLeading
                )
            } else {
                // Normal Display with Native CoreText Rendering
                HStack {
                    let leftStr = config.evaluateFooter(slot: .left, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)
                    let centerStr = config.evaluateFooter(slot: .center, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)
                    let rightStr = config.evaluateFooter(slot: .right, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)

                    if isSuppressed {
                        Text("First Page Footer (Suppressed)")
                            .font(resolveHeaderFont(fontFamily: fontFamily, size: 11, weight: .regular))
                            .foregroundColor(.secondary.opacity(0.4))
                            .italic()
                        Spacer()
                    } else {
                        NativeHeaderSlotField(
                            text: .constant(leftStr),
                            placeholder: "",
                            alignment: .left,
                            font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                            textColor: .labelColor,
                            isEditable: false
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if !centerStr.isEmpty {
                            NativeHeaderSlotField(
                                text: .constant(centerStr),
                                placeholder: "",
                                alignment: .center,
                                font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                                textColor: .labelColor,
                                isEditable: false
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                        }

                        NativeHeaderSlotField(
                            text: .constant(rightStr),
                            placeholder: "",
                            alignment: .right,
                            font: resolveNSHeaderFont(fontFamily: fontFamily, size: 11.0, weight: .regular),
                            textColor: .labelColor,
                            isEditable: false
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    isHovered
                        ? Color.accentColor.opacity(0.06)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .overlay(
                    Group {
                        if isHovered {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .overlay(
                                    Text("Double-click to edit Footer")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.85), in: Capsule())
                                        .foregroundColor(.white)
                                        .offset(y: 12),
                                    alignment: .bottomTrailing
                                )
                        }
                    }
                )
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        activeTarget = .footer
                        isEditing = true
                    }
                }
                .help("Double-click to edit Footer & Page Numbering")
            }
        }
        .padding(.horizontal, margins.left)
        .padding(.bottom, max(4, margins.bottom / 2 - 8))
        .frame(width: sheetWidth, height: sheetHeight, alignment: .bottom)
    }
}

public enum HeaderFooterToolbarPosition: String, CaseIterable, Identifiable {
    case adaptive = "Adaptive"
    case top = "Top"
    case bottom = "Bottom"

    public var id: String { rawValue }
}

public struct StudioHeaderFooterToolbar: View {
    @Binding var config: HeaderFooterConfig
    @Binding var isEditing: Bool
    @Binding var activeTarget: HeaderFooterTarget

    @State private var dragOffset: CGSize = .zero
    @State private var currentPosition: CGSize = .zero

    public init(
        config: Binding<HeaderFooterConfig>,
        isEditing: Binding<Bool>,
        activeTarget: Binding<HeaderFooterTarget>
    ) {
        self._config = config
        self._isEditing = isEditing
        self._activeTarget = activeTarget
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Drag Handle Indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.8))
                .frame(width: 12, height: 20)
                .contentShape(Rectangle())
                .help("Drag to move toolbar anywhere")

            // Custom Compact Switcher (Header vs Footer)
            HStack(spacing: 1) {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        activeTarget = .header
                    }
                } label: {
                    Text("Header")
                        .font(.system(size: 10, weight: activeTarget == .header ? .bold : .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            activeTarget == .header
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .foregroundColor(activeTarget == .header ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        activeTarget = .footer
                    }
                } label: {
                    Text("Footer")
                        .font(.system(size: 10, weight: activeTarget == .footer ? .bold : .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            activeTarget == .footer
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .foregroundColor(activeTarget == .footer ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))

            Divider()
                .frame(height: 14)

            // Page Number Position Picker Menu
            Menu {
                ForEach(PageNumberPosition.allCases, id: \.self) { pos in
                    Button(pos.rawValue) {
                        config.pageNumberPosition = pos
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "number.square")
                        .font(.system(size: 9))
                    Text(config.pageNumberPosition.rawValue)
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Page Number Placement")

            // Page Number Format Picker Menu
            Menu {
                ForEach(PageNumberFormat.allCases, id: \.self) { fmt in
                    Button(fmt.rawValue) {
                        config.pageNumberFormat = fmt
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(config.pageNumberFormat.rawValue)
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Page Number Format Style")

            // Starting Page Stepper
            HStack(spacing: 1) {
                Text("Start:")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)

                Button {
                    if config.startingPageNumber > 0 { config.startingPageNumber -= 1 }
                } label: {
                    Text("−")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 12, height: 14)
                }
                .buttonStyle(.plain)

                Text("\(config.startingPageNumber)")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 14)

                Button {
                    config.startingPageNumber += 1
                } label: {
                    Text("+")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 12, height: 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
            .help("Starting Page Number (Offset)")

            Divider()
                .frame(height: 14)

            // Different First Page Checkbox
            Toggle(isOn: $config.differentFirstPage) {
                Text("Diff First")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.checkbox)
            .help("Hide header and footer on the title / cover page")

            Divider()
                .frame(height: 14)

            // Quick Token Menu
            Menu {
                Button("Insert {page} (Current Page)") { appendToken("{page}") }
                Button("Insert {pages} (Total Pages)") { appendToken("{pages}") }
                Button("Insert {title} (Document Title)") { appendToken("{title}") }
                Button("Insert {date} (Current Date)") { appendToken("{date}") }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus.circle")
                    Text("Field")
                }
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Close / Done Button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isEditing = false
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Done")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Close Header & Footer Editor (Esc)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThickMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        .fixedSize()
        .offset(x: currentPosition.width + dragOffset.width, y: currentPosition.height + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    currentPosition.width += value.translation.width
                    currentPosition.height += value.translation.height
                    dragOffset = .zero
                }
        )
    }

    private func appendToken(_ token: String) {
        if activeTarget == .header {
            config.headerRightText += (config.headerRightText.isEmpty ? "" : " ") + token
        } else {
            config.footerRightText += (config.footerRightText.isEmpty ? "" : " ") + token
        }
    }
}
