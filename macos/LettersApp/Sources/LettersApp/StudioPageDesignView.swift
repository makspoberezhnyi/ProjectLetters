import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public enum PageDesignTab: String, CaseIterable {
    case preset = "Preset"
    case custom = "Custom"
}

public enum BlockCornerRadius: String, CaseIterable, Identifiable {
    case none = "None"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    public var id: String { rawValue }

    public var points: CGFloat {
        switch self {
        case .none: return 0
        case .small: return 6
        case .medium: return 12
        case .large: return 18
        }
    }
}

public enum BlockShadowStyle: String, CaseIterable, Identifiable {
    case none = "None"
    case subtle = "Subtle"
    case medium = "Medium"
    case bold = "Bold"

    public var id: String { rawValue }

    public var radius: CGFloat {
        switch self {
        case .none: return 0
        case .subtle: return 6
        case .medium: return 14
        case .bold: return 24
        }
    }

    public var opacity: Double {
        switch self {
        case .none: return 0.0
        case .subtle: return 0.12
        case .medium: return 0.22
        case .bold: return 0.35
        }
    }
}

public struct StudioPageDesignView: View {
    @Binding var isPresented: Bool
    @Binding var coverBannerConfig: CoverBannerConfig
    @Binding var pageSize: PageSizePreset
    @Binding var marginPreset: MarginPreset
    @Binding var margins: PageMargins
    @Binding var fontFamily: String
    @Binding var fontSize: CGFloat
    @Binding var lineSpacing: CGFloat
    @Binding var paragraphSpacing: CGFloat
    @Binding var activeCitationStyle: CitationStyle
    @Binding var showMarginGuides: Bool
    @Binding var showCropMarks: Bool
    var onToast: ((String) -> Void)? = nil

    @State private var activeTab: PageDesignTab = .preset
    @State private var isPageSectionExpanded: Bool = true
    @State private var isBlockSectionExpanded: Bool = true
    @State private var selectedCornerRadius: BlockCornerRadius = .medium
    @State private var selectedShadowStyle: BlockShadowStyle = .medium
    @State private var showingCoverPicker: Bool = false

    public init(
        isPresented: Binding<Bool>,
        coverBannerConfig: Binding<CoverBannerConfig>,
        pageSize: Binding<PageSizePreset>,
        marginPreset: Binding<MarginPreset>,
        margins: Binding<PageMargins>,
        fontFamily: Binding<String>,
        fontSize: Binding<CGFloat>,
        lineSpacing: Binding<CGFloat>,
        paragraphSpacing: Binding<CGFloat>,
        activeCitationStyle: Binding<CitationStyle>,
        showMarginGuides: Binding<Bool>,
        showCropMarks: Binding<Bool>,
        onToast: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._coverBannerConfig = coverBannerConfig
        self._pageSize = pageSize
        self._marginPreset = marginPreset
        self._margins = margins
        self._fontFamily = fontFamily
        self._fontSize = fontSize
        self._lineSpacing = lineSpacing
        self._paragraphSpacing = paragraphSpacing
        self._activeCitationStyle = activeCitationStyle
        self._showMarginGuides = showMarginGuides
        self._showCropMarks = showCropMarks
        self.onToast = onToast
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Top Breadcrumb & Exit Navigation
            topNavBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // 2. Title & Preset / Custom Segmented Switcher
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Page Design")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)

                        // Segmented Control (Pill Switcher)
                        HStack(spacing: 0) {
                            ForEach(PageDesignTab.allCases, id: \.self) { tab in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        activeTab = tab
                                    }
                                } label: {
                                    Text(tab.rawValue)
                                        .font(.system(size: 12, weight: activeTab == tab ? .bold : .medium))
                                        .foregroundColor(activeTab == tab ? .white : .secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(
                                            activeTab == tab
                                                ? RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.16))
                                                : RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(3)
                        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }

                    // 3. Hero 3D Stacked Theme Preview Card
                    heroThemePreviewCard

                    // 4. Section: Page Level Settings
                    pageSectionGroup

                    // 5. Section: Block & Element Styling
                    blockSectionGroup
                }
                .padding(16)
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .background(StudioTheme.panelBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            StudioTheme.luminousPurple.opacity(0.35),
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 32, x: 0, y: 14)
    }

    // MARK: - Top Nav Bar
    private var topNavBar: some View {
        HStack {
            // Exit Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isPresented = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("Exit")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Page Selector Pill
            HStack(spacing: 6) {
                Text("PAGE")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary)

                Divider()
                    .frame(height: 10)

                Image(systemName: "house.fill")
                    .font(.system(size: 10))
                    .foregroundColor(StudioTheme.luminousCyan)

                Text("Document")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.25), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Hero 3D Theme Preview Card
    private var heroThemePreviewCard: some View {
        Button {
            showingCoverPicker.toggle()
        } label: {
            ZStack {
                // Background Card 2 (3D stacked rotation)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(themeGradient.opacity(0.4))
                    .frame(height: 140)
                    .rotationEffect(.degrees(4))
                    .offset(x: 8, y: 2)

                // Background Card 1 (3D stacked tilt)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(themeGradient.opacity(0.7))
                    .frame(height: 140)
                    .rotationEffect(.degrees(-3))
                    .offset(x: -6, y: 1)

                // Main Foreground Card
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(themeGradient)
                        .frame(height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 6)

                    // Hero Badge & Elements
                    VStack(spacing: 8) {
                        // Decorative Flower / Icon Badge
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 44, height: 44)

                            Text(coverBannerConfig.iconSymbol)
                                .font(.system(size: 22))
                        }

                        // Category Tag Capsule
                        Text(coverBannerConfig.categoryTag.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.35), in: Capsule())
                    }
                }
            }
            .frame(height: 154)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .overlay(
                // "Using Preset Name" Footnote
                HStack(spacing: 5) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 10))
                        .foregroundColor(StudioTheme.luminousPurple)

                    Text("Using")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(coverBannerConfig.preset.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 160),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 22)
        .popover(isPresented: $showingCoverPicker) {
            coverPresetPickerPopover
        }
    }

    private var themeGradient: LinearGradient {
        switch coverBannerConfig.preset {
        case .desertDunes:
            return LinearGradient(
                colors: [Color(red: 0.95, green: 0.55, blue: 0.35), Color(red: 0.85, green: 0.35, blue: 0.55), Color(red: 0.45, green: 0.25, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .appleAurora:
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.7, blue: 0.95), Color(red: 0.55, green: 0.3, blue: 0.95), Color(red: 0.95, green: 0.4, blue: 0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .midnightIndigo:
            return LinearGradient(
                colors: [Color(red: 0.1, green: 0.12, blue: 0.25), Color(red: 0.18, green: 0.22, blue: 0.45), Color(red: 0.3, green: 0.2, blue: 0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solarFlare:
            return LinearGradient(
                colors: [Color(red: 0.98, green: 0.3, blue: 0.2), Color(red: 0.98, green: 0.6, blue: 0.1), Color(red: 0.98, green: 0.85, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .emeraldForest:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.25, blue: 0.18), Color(red: 0.12, green: 0.48, blue: 0.35), Color(red: 0.25, green: 0.75, blue: 0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .minimalMonochrome:
            return LinearGradient(
                colors: [Color(white: 0.2), Color(white: 0.12), Color(white: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .none:
            return LinearGradient(
                colors: [Color(white: 0.3), Color(white: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Section: Page Level Settings
    private var pageSectionGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isPageSectionExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isPageSectionExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    Text("Page")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isPageSectionExpanded {
                VStack(spacing: 8) {
                    // 1. Linked Sources & Citation Style
                    designRowItem(icon: "link", color: StudioTheme.luminousPurple, title: "Citation Standard", value: activeCitationStyle.rawValue) {
                        Menu {
                            ForEach(CitationStyle.allCases, id: \.self) { style in
                                Button(style.rawValue) {
                                    activeCitationStyle = style
                                    onToast?("✓ Citation Style: \(style.rawValue)")
                                }
                            }
                        } label: {
                            Text(activeCitationStyle.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                    }

                    // 2. Header / Cover Banner Mode
                    designRowItem(icon: "rectangle.topthird.inset.filled", color: StudioTheme.luminousCyan, title: "Cover Hero", value: coverBannerConfig.isEnabled ? "Enabled" : "Off") {
                        Toggle("", isOn: $coverBannerConfig.isEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }

                    // 3. Typography Font Family
                    designRowItem(icon: "textformat", color: StudioTheme.luminousBlue, title: "Font Family", value: "Abc") {
                        Menu {
                            Button("Default Serif (Georgia)") { fontFamily = "Default Serif (Georgia)" }
                            Button("SF Pro (Modern Sans)") { fontFamily = "SF Pro (Modern Sans)" }
                            Button("New York (Editorial)") { fontFamily = "New York (Editorial)" }
                            Button("SF Mono (Code)") { fontFamily = "SF Mono (Code)" }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Abc")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .menuStyle(.borderlessButton)
                    }

                    // 4. Page Size & Layout Preset
                    designRowItem(icon: "doc.fill", color: StudioTheme.luminousEmerald, title: "Paper Format", value: pageSize.rawValue) {
                        Menu {
                            ForEach(PageSizePreset.allCases, id: \.self) { size in
                                Button(size.rawValue) { pageSize = size }
                            }
                        } label: {
                            Text(pageSize.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Section: Block & Element Styling
    private var blockSectionGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isBlockSectionExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isBlockSectionExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    Text("Block Elements")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isBlockSectionExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Corner Radius Selector
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 11))
                                .foregroundColor(StudioTheme.luminousCyan)
                            Text("Radius")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        HStack(spacing: 6) {
                            ForEach(BlockCornerRadius.allCases) { radius in
                                Button {
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                        selectedCornerRadius = radius
                                        onToast?("✓ Radius: \(radius.rawValue)")
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: radius.points, style: .continuous)
                                                .stroke(selectedCornerRadius == radius ? StudioTheme.luminousCyan : Color.white.opacity(0.2), lineWidth: 1.5)
                                                .frame(width: 32, height: 28)
                                                .background(
                                                    RoundedRectangle(cornerRadius: radius.points, style: .continuous)
                                                        .fill(selectedCornerRadius == radius ? StudioTheme.luminousCyan.opacity(0.15) : Color.clear)
                                                )

                                            if radius == .none {
                                                Image(systemName: "circle.slash")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Text(radius.rawValue)
                                            .font(.system(size: 9, weight: selectedCornerRadius == radius ? .bold : .regular))
                                            .foregroundColor(selectedCornerRadius == radius ? .primary : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selectedCornerRadius == radius ? Color.white.opacity(0.08) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(0.06))

                    // 2. Drop Shadow Style Selector
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.righthalf.filled")
                                .font(.system(size: 11))
                                .foregroundColor(StudioTheme.luminousPurple)
                            Text("Shadow")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        HStack(spacing: 6) {
                            ForEach(BlockShadowStyle.allCases) { shadow in
                                Button {
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                        selectedShadowStyle = shadow
                                        onToast?("✓ Shadow: \(shadow.rawValue)")
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(Color.white.opacity(0.12))
                                                .frame(width: 32, height: 28)
                                                .shadow(color: Color.black.opacity(shadow.opacity), radius: shadow.radius, x: 0, y: 3)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                        .stroke(selectedShadowStyle == shadow ? StudioTheme.luminousPurple : Color.clear, lineWidth: 1.5)
                                                )

                                            if shadow == .none {
                                                Image(systemName: "circle.slash")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Text(shadow.rawValue)
                                            .font(.system(size: 9, weight: selectedShadowStyle == shadow ? .bold : .regular))
                                            .foregroundColor(selectedShadowStyle == shadow ? .primary : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selectedShadowStyle == shadow ? Color.white.opacity(0.08) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(0.06))

                    // 3. Margin Guides & Corner Crop Marks
                    HStack {
                        Toggle("Show Margin Guides", isOn: $showMarginGuides)
                            .font(.system(size: 11))
                        Spacer()
                    }

                    HStack {
                        Toggle("Publisher Crop Marks", isOn: $showCropMarks)
                            .font(.system(size: 11))
                        Spacer()
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
    }

    private func designRowItem<Content: View>(
        icon: String,
        color: Color,
        title: String,
        value: String,
        @ViewBuilder trailingContent: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            trailingContent()
        }
        .padding(.vertical, 3)
    }

    // MARK: - Cover Preset Picker Popover
    private var coverPresetPickerPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Cover Art Preset")
                .font(.headline)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(CoverBannerPreset.allCases.filter { $0 != .none }, id: \.self) { preset in
                        Button {
                            coverBannerConfig.preset = preset
                            showingCoverPicker = false
                            onToast?("✓ Selected \(preset.rawValue) theme")
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(gradientForPreset(preset))
                                    .frame(height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(coverBannerConfig.preset == preset ? Color.white : Color.clear, lineWidth: 2)
                                    )

                                Text(preset.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            .padding(6)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 240)
        }
        .padding(14)
        .frame(width: 280)
    }

    private func gradientForPreset(_ preset: CoverBannerPreset) -> LinearGradient {
        switch preset {
        case .desertDunes:
            return LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .appleAurora:
            return LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .midnightIndigo:
            return LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.3), .indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .solarFlare:
            return LinearGradient(colors: [.red, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .emeraldForest:
            return LinearGradient(colors: [Color(red: 0.05, green: 0.2, blue: 0.1), .teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minimalMonochrome:
            return LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .none:
            return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
        }
    }
}
