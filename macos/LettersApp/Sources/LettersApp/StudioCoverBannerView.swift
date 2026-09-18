import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct StudioCoverBannerView: View {
    @Binding var config: CoverBannerConfig
    @Binding var documentTitle: String
    let sheetWidth: CGFloat
    var onBannerToggled: (() -> Void)? = nil

    @State private var isHovered: Bool = false
    @State private var showingCoverPicker: Bool = false
    @State private var showingIconPicker: Bool = false
    @State private var showingTagEditor: Bool = false

    public init(
        config: Binding<CoverBannerConfig>,
        documentTitle: Binding<String>,
        sheetWidth: CGFloat,
        onBannerToggled: (() -> Void)? = nil
    ) {
        self._config = config
        self._documentTitle = documentTitle
        self.sheetWidth = sheetWidth
        self.onBannerToggled = onBannerToggled
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 1. Cover Art / Gradient Backdrop
            coverBackdrop
                .frame(width: sheetWidth, height: CGFloat(config.height))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)

            // 2. Ambient Bottom Gradient Vignette for Text Contrast
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: sheetWidth, height: CGFloat(config.height))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            // 3. Foreground Metadata (Emoji / Icon + Category Tag + Document Title)
            HStack(alignment: .bottom, spacing: 14) {
                // Icon / Emoji Badge Button
                Button {
                    showingIconPicker.toggle()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)

                        if config.iconSymbol.count <= 2 && config.iconSymbol.containsEmoji {
                            Text(config.iconSymbol)
                                .font(.system(size: 26))
                        } else {
                            Image(systemName: config.iconSymbol.isEmpty ? "doc.richtext" : config.iconSymbol)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingIconPicker) {
                    iconPickerPopover
                }
                .help("Change Icon Badge")

                VStack(alignment: .leading, spacing: 4) {
                    // Category Tag Pill
                    Button {
                        showingTagEditor.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(StudioTheme.luminousAmber)
                                .frame(width: 6, height: 6)
                            Text(config.categoryTag.isEmpty ? "DOCUMENT" : config.categoryTag.uppercased())
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.4), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingTagEditor) {
                        tagEditorPopover
                    }
                    .help("Edit Category Tag")

                    // Hero Document Title
                    TextField("Document Title...", text: $documentTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 4)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // 4. Floating Hover Controls ("Change Cover" & "Remove Cover")
            if isHovered {
                HStack(spacing: 8) {
                    Button {
                        showingCoverPicker.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Change Cover")
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingCoverPicker) {
                        coverPickerPopover
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            config.isEnabled = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(6)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Hide Cover Banner")
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.opacity)
            }
        }
        .frame(width: sheetWidth, height: CGFloat(config.height))
        .onHover { isHovered = $0 }
    }

    // MARK: - Cover Backdrop Renderers
    @ViewBuilder
    private var coverBackdrop: some View {
        switch config.preset {
        case .desertDunes:
            // Warm Terracotta / Desert Dune Aesthetic (Inspired by Reference)
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.60, blue: 0.95), // Deep sky cyan
                        Color(red: 0.45, green: 0.75, blue: 0.98), // Bright sky
                        Color(red: 0.98, green: 0.65, blue: 0.25), // Horizon gold
                        Color(red: 0.92, green: 0.32, blue: 0.12), // Terracotta dune
                        Color(red: 0.65, green: 0.12, blue: 0.05)  // Deep shadow dune
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                // Soft dune curve simulation
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height * 0.45))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.70),
                        control1: CGPoint(x: size.width * 0.4, y: size.height * 0.30),
                        control2: CGPoint(x: size.width * 0.7, y: size.height * 0.85)
                    )
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()

                    context.fill(path, with: .color(Color(red: 0.88, green: 0.28, blue: 0.08).opacity(0.85)))
                }
            }

        case .appleAurora:
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.85, blue: 0.65),
                    Color(red: 0.25, green: 0.45, blue: 0.95),
                    Color(red: 0.75, green: 0.25, blue: 0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .midnightIndigo:
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.15, green: 0.20, blue: 0.45),
                    Color(red: 0.28, green: 0.15, blue: 0.50)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

        case .solarFlare:
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.15, blue: 0.35),
                    Color(red: 0.95, green: 0.55, blue: 0.15),
                    Color(red: 0.98, green: 0.85, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .emeraldForest:
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.25, blue: 0.18),
                    Color(red: 0.12, green: 0.55, blue: 0.38),
                    Color(red: 0.35, green: 0.80, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .minimalMonochrome, .none:
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.18),
                    Color(red: 0.08, green: 0.08, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Popovers
    private var coverPickerPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cover Style Presets")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(CoverBannerPreset.allCases.filter { $0 != .none }, id: \.self) { preset in
                    Button {
                        config.preset = preset
                        showingCoverPicker = false
                    } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(presetGradientPreview(for: preset))
                                .frame(height: 48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(config.preset == preset ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: config.preset == preset ? 2 : 1)
                                )

                            Text(preset.rawValue)
                                .font(.system(size: 9.5, weight: config.preset == preset ? .bold : .medium))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 240)
    }

    private var iconPickerPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose Icon / Emoji")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            let emojiList = ["📄", "✨", "🚀", "💡", "🎨", "📊", "🎯", "⚡️", "🔥", "🌿", "🤖", "🖋️", "📚", "🏛️", "💼"]
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 32))], spacing: 8) {
                ForEach(emojiList, id: \.self) { emoji in
                    Button {
                        config.iconSymbol = emoji
                        showingIconPicker = false
                    } label: {
                        Text(emoji)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            let sfList = ["sparkles", "doc.richtext", "book.closed", "chart.bar.doc.horizontal", "lightbulb.fill", "bolt.fill"]
            HStack(spacing: 8) {
                ForEach(sfList, id: \.self) { icon in
                    Button {
                        config.iconSymbol = icon
                        showingIconPicker = false
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 220)
    }

    private var tagEditorPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category Tag")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            TextField("e.g. SPECIFICATION, DRAFT...", text: $config.categoryTag)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, weight: .semibold))

            let tagPresets = ["STUDIO SPEC", "DRAFT", "RESEARCH", "PROPOSAL", "ARTICLE", "TO-DOS"]
            HStack(spacing: 4) {
                ForEach(tagPresets, id: \.self) { tag in
                    Button {
                        config.categoryTag = tag
                    } label: {
                        Text(tag)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private func presetGradientPreview(for preset: CoverBannerPreset) -> LinearGradient {
        switch preset {
        case .desertDunes:
            return LinearGradient(colors: [.orange, .red, .brown], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .appleAurora:
            return LinearGradient(colors: [.green, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .midnightIndigo:
            return LinearGradient(colors: [.black, .indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .solarFlare:
            return LinearGradient(colors: [.pink, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .emeraldForest:
            return LinearGradient(colors: [.black, .green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minimalMonochrome, .none:
            return LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private extension String {
    var containsEmoji: Bool {
        for scalar in unicodeScalars {
            if scalar.properties.isEmoji {
                return true
            }
        }
        return false
    }
}
