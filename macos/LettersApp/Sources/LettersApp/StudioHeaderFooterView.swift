import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public enum HeaderFooterTarget: String, CaseIterable, Identifiable {
    case header = "Header"
    case footer = "Footer"

    public var id: String { rawValue }
}

public struct StudioHeaderView: View {
    @Binding var config: HeaderFooterConfig
    let pageIndex: Int
    let totalPages: Int
    let documentTitle: String
    let margins: PageMargins
    let sheetWidth: CGFloat
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
                // Interactive In-Place Editor for Header
                HStack(spacing: 8) {
                    TextField("Left header ({title}, {date})...", text: Binding(
                        get: { config.headerLeftText.isEmpty ? (isHovered ? "" : documentTitle) : config.headerLeftText },
                        set: { config.headerLeftText = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Center header...", text: $config.headerCenterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, alignment: .center)

                    TextField("Right header ({page}, {pages})...", text: $config.headerRightText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
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
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundColor(.white)
                            .offset(y: -14)
                        Spacer()
                    }
                    .padding(.leading, 4),
                    alignment: .topLeading
                )
            } else {
                // Normal Display with Hover & Double-Click Detection
                HStack {
                    let leftStr = config.evaluateHeader(slot: .left, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)
                    let centerStr = config.evaluateHeader(slot: .center, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)
                    let rightStr = config.evaluateHeader(slot: .right, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)

                    if isSuppressed {
                        Text("First Page Header (Suppressed)")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.secondary.opacity(0.4))
                            .italic()
                        Spacer()
                    } else {
                        Text(leftStr)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                            .lineLimit(1)

                        Spacer()

                        if !centerStr.isEmpty {
                            Text(centerStr)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                                .lineLimit(1)
                            Spacer()
                        }

                        Text(rightStr)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                            .lineLimit(1)
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
                                        .font(.system(size: 7.5, weight: .semibold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.accentColor.opacity(0.85), in: Capsule())
                                        .foregroundColor(.white)
                                        .offset(y: -11),
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
                // Interactive In-Place Editor for Footer
                HStack(spacing: 8) {
                    TextField("Left footer ({date}, Confidential)...", text: $config.footerLeftText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Center footer...", text: $config.footerCenterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, alignment: .center)

                    TextField("Right footer ({page}, {pages})...", text: $config.footerRightText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
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
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundColor(.white)
                            .offset(y: 14)
                        Spacer()
                    }
                    .padding(.leading, 4),
                    alignment: .bottomLeading
                )
            } else {
                // Normal Display with Hover & Double-Click Detection
                HStack {
                    let leftStr = config.evaluateFooter(slot: .left, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)
                    let centerStr = config.evaluateFooter(slot: .center, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)
                    let rightStr = config.evaluateFooter(slot: .right, pageIndex: pageIndex, totalPages: totalPages, documentTitle: documentTitle)

                    if isSuppressed {
                        Text("First Page Footer (Suppressed)")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(.secondary.opacity(0.4))
                            .italic()
                        Spacer()
                    } else {
                        Text(leftStr)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                            .lineLimit(1)

                        Spacer()

                        if !centerStr.isEmpty {
                            Text(centerStr)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                                .lineLimit(1)
                            Spacer()
                        }

                        Text(rightStr)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                            .lineLimit(1)
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
                                        .font(.system(size: 7.5, weight: .semibold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.accentColor.opacity(0.85), in: Capsule())
                                        .foregroundColor(.white)
                                        .offset(y: 11),
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
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
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
