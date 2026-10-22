import SwiftUI
import AppKit

public struct WordStyleColorPaletteView: View {
    let title: String
    @Binding var selectedColor: Color
    var isHighlight: Bool = false
    var allowNoColor: Bool = false
    var clearTitle: String = "No Color"
    var onSelectColor: (Color) -> Void
    var onClearColor: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @ObservedObject private var recentStore = RecentColorsManager.shared
    @State private var workingColor: Color
    @State private var colorObserver: NSObjectProtocol? = nil

    // 10 Theme Base Colors (Microsoft Office / Word Theme)
    private static let themeBaseColors: [Color] = [
        Color(red: 1.0, green: 1.0, blue: 1.0),       // White
        Color(red: 0.0, green: 0.0, blue: 0.0),       // Black
        Color(red: 0.91, green: 0.90, blue: 0.90),   // Light Gray
        Color(red: 0.27, green: 0.33, blue: 0.42),   // Blue Gray
        Color(red: 0.27, green: 0.45, blue: 0.77),   // Blue
        Color(red: 0.93, green: 0.49, blue: 0.19),   // Orange
        Color(red: 0.65, green: 0.65, blue: 0.65),   // Gray
        Color(red: 1.0, green: 0.75, blue: 0.0),     // Gold
        Color(red: 0.36, green: 0.61, blue: 0.84),   // Sky Blue
        Color(red: 0.44, green: 0.68, blue: 0.28)    // Green
    ]

    // 5 Shade factors for the theme matrix (tints to shades)
    private static let themeMatrix: [[Color]] = {
        var matrix: [[Color]] = []
        matrix.append(themeBaseColors)

        // Row 1: 80% tint / lighter
        matrix.append([
            Color(red: 0.95, green: 0.95, blue: 0.95),
            Color(red: 0.50, green: 0.50, blue: 0.50),
            Color(red: 0.82, green: 0.82, blue: 0.82),
            Color(red: 0.84, green: 0.86, blue: 0.89),
            Color(red: 0.85, green: 0.89, blue: 0.95),
            Color(red: 0.98, green: 0.90, blue: 0.84),
            Color(red: 0.93, green: 0.93, blue: 0.93),
            Color(red: 1.00, green: 0.95, blue: 0.80),
            Color(red: 0.87, green: 0.92, blue: 0.97),
            Color(red: 0.89, green: 0.94, blue: 0.86)
        ])

        // Row 2: 60% tint
        matrix.append([
            Color(red: 0.88, green: 0.88, blue: 0.88),
            Color(red: 0.38, green: 0.38, blue: 0.38),
            Color(red: 0.68, green: 0.68, blue: 0.68),
            Color(red: 0.69, green: 0.73, blue: 0.78),
            Color(red: 0.71, green: 0.78, blue: 0.91),
            Color(red: 0.97, green: 0.79, blue: 0.68),
            Color(red: 0.86, green: 0.86, blue: 0.86),
            Color(red: 1.00, green: 0.90, blue: 0.60),
            Color(red: 0.75, green: 0.84, blue: 0.94),
            Color(red: 0.77, green: 0.87, blue: 0.71)
        ])

        // Row 3: 40% tint
        matrix.append([
            Color(red: 0.75, green: 0.75, blue: 0.75),
            Color(red: 0.25, green: 0.25, blue: 0.25),
            Color(red: 0.55, green: 0.55, blue: 0.55),
            Color(red: 0.53, green: 0.59, blue: 0.67),
            Color(red: 0.56, green: 0.68, blue: 0.86),
            Color(red: 0.96, green: 0.69, blue: 0.51),
            Color(red: 0.72, green: 0.72, blue: 0.72),
            Color(red: 1.00, green: 0.85, blue: 0.40),
            Color(red: 0.62, green: 0.77, blue: 0.90),
            Color(red: 0.66, green: 0.81, blue: 0.57)
        ])

        // Row 4: 25% deeper / darker shade
        matrix.append([
            Color(red: 0.60, green: 0.60, blue: 0.60),
            Color(red: 0.15, green: 0.15, blue: 0.15),
            Color(red: 0.38, green: 0.38, blue: 0.38),
            Color(red: 0.20, green: 0.25, blue: 0.32),
            Color(red: 0.18, green: 0.33, blue: 0.60),
            Color(red: 0.78, green: 0.35, blue: 0.08),
            Color(red: 0.52, green: 0.52, blue: 0.52),
            Color(red: 0.80, green: 0.60, blue: 0.00),
            Color(red: 0.24, green: 0.48, blue: 0.71),
            Color(red: 0.32, green: 0.53, blue: 0.18)
        ])

        // Row 5: 50% deep shade
        matrix.append([
            Color(red: 0.45, green: 0.45, blue: 0.45),
            Color(red: 0.08, green: 0.08, blue: 0.08),
            Color(red: 0.24, green: 0.24, blue: 0.24),
            Color(red: 0.14, green: 0.17, blue: 0.21),
            Color(red: 0.12, green: 0.22, blue: 0.40),
            Color(red: 0.52, green: 0.23, blue: 0.05),
            Color(red: 0.35, green: 0.35, blue: 0.35),
            Color(red: 0.53, green: 0.40, blue: 0.00),
            Color(red: 0.16, green: 0.32, blue: 0.47),
            Color(red: 0.21, green: 0.35, blue: 0.12)
        ])

        return matrix
    }()

    // 10 Standard Colors (Standard Word Palette)
    private static let standardColors: [Color] = [
        Color(red: 0.75, green: 0.00, blue: 0.00),   // Dark Red (#C00000)
        Color(red: 1.00, green: 0.00, blue: 0.00),   // Red (#FF0000)
        Color(red: 1.00, green: 0.75, blue: 0.00),   // Orange / Gold (#FFC000)
        Color(red: 1.00, green: 1.00, blue: 0.00),   // Yellow (#FFFF00)
        Color(red: 0.57, green: 0.82, blue: 0.31),   // Light Green (#92D050)
        Color(red: 0.00, green: 0.69, blue: 0.31),   // Green (#00B050)
        Color(red: 0.00, green: 0.69, blue: 0.94),   // Light Blue (#00B0F0)
        Color(red: 0.00, green: 0.44, blue: 0.75),   // Blue (#0070C0)
        Color(red: 0.00, green: 0.13, blue: 0.38),   // Dark Blue (#002060)
        Color(red: 0.44, green: 0.19, blue: 0.63)    // Purple (#7030A0)
    ]

    public init(
        title: String,
        selectedColor: Binding<Color>,
        isHighlight: Bool = false,
        allowNoColor: Bool = false,
        clearTitle: String = "No Color",
        onSelectColor: @escaping (Color) -> Void,
        onClearColor: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self._selectedColor = selectedColor
        self.isHighlight = isHighlight
        self.allowNoColor = allowNoColor
        self.clearTitle = clearTitle
        self.onSelectColor = onSelectColor
        self.onClearColor = onClearColor
        self.onDismiss = onDismiss
        self._workingColor = State(initialValue: selectedColor.wrappedValue)
    }

    private var activeRecentColors: [Color] {
        isHighlight ? recentStore.recentHighlightColors : recentStore.recentTextColors
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Top Section: Native ColorPicker + Live Preview + Explicit "Apply" Button
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Native ColorPicker Control
                    ColorPicker("", selection: $workingColor)
                        .labelsHidden()

                    // Live Swatch Preview & Hex label
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(workingColor)
                            .frame(width: 20, height: 20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )

                        Text(hexString(for: workingColor))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Explicit Apply Button
                    Button(action: {
                        applyWorkingColor()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Apply")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                HStack(spacing: 6) {
                    Button(action: {
                        openNativeColorPanel()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 11))
                            Text("Custom (RGB / Wheel)...")
                                .font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if allowNoColor {
                        Button(action: {
                            onClearColor?()
                            onDismiss?()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isHighlight ? "slash.circle" : "arrow.counterclockwise")
                                    .font(.system(size: 10))
                                Text(clearTitle)
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(clearTitle)
                    }
                }
            }

            Divider()

            // 2. Theme Colors Matrix (10 columns x 6 rows)
            VStack(alignment: .leading, spacing: 4) {
                Text("Theme Colors")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                VStack(spacing: 2) {
                    // Row 0: Main Theme Colors
                    HStack(spacing: 2) {
                        ForEach(0..<Self.themeMatrix[0].count, id: \.self) { c in
                            colorSwatch(Self.themeMatrix[0][c], height: 16)
                        }
                    }

                    // Rows 1..5: Tint / Shade variations
                    ForEach(1..<Self.themeMatrix.count, id: \.self) { r in
                        HStack(spacing: 2) {
                            ForEach(0..<Self.themeMatrix[r].count, id: \.self) { c in
                                colorSwatch(Self.themeMatrix[r][c], height: 12)
                            }
                        }
                    }
                }
            }

            // 3. Standard Colors Row
            VStack(alignment: .leading, spacing: 4) {
                Text("Standard Colors")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 2) {
                    ForEach(0..<Self.standardColors.count, id: \.self) { c in
                        colorSwatch(Self.standardColors[c], height: 16)
                    }
                }
            }

            // 4. Recent Colors Row (Shared & Persistent)
            if !activeRecentColors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Colors")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 2) {
                        ForEach(0..<min(10, activeRecentColors.count), id: \.self) { idx in
                            colorSwatch(activeRecentColors[idx], height: 16)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 250)
        .onAppear {
            workingColor = selectedColor
            setupColorPanelObserver()
        }
        .onDisappear {
            removeColorPanelObserver()
        }
        .onChange(of: workingColor) { _, newColor in
            selectedColor = newColor
            recordColor(newColor)
            onSelectColor(newColor)
        }
    }

    private func colorSwatch(_ color: Color, height: CGFloat) -> some View {
        Button(action: {
            workingColor = color
            selectedColor = color
            recordColor(color)
            onSelectColor(color)
            onDismiss?()
        }) {
            Rectangle()
                .fill(color)
                .frame(width: 20, height: height)
                .overlay(
                    Rectangle()
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func applyWorkingColor() {
        selectedColor = workingColor
        recordColor(workingColor)
        onSelectColor(workingColor)
        onDismiss?()
    }

    private func recordColor(_ color: Color) {
        if isHighlight {
            recentStore.addHighlightColor(color)
        } else {
            recentStore.addTextColor(color)
        }
    }

    private func openNativeColorPanel() {
        let panel = NSColorPanel.shared
        panel.color = NSColor(workingColor)
        panel.isContinuous = true
        panel.makeKeyAndOrderFront(nil)
    }

    private func setupColorPanelObserver() {
        colorObserver = NotificationCenter.default.addObserver(
            forName: NSColorPanel.colorDidChangeNotification,
            object: nil,
            queue: .main
        ) { @Sendable _ in
            Task { @MainActor in
                let newNsColor = NSColorPanel.shared.color
                let newColor = Color(newNsColor)
                self.workingColor = newColor
                self.selectedColor = newColor
                self.recordColor(newColor)
                self.onSelectColor(newColor)
            }
        }
    }

    private func removeColorPanelObserver() {
        if let obs = colorObserver {
            NotificationCenter.default.removeObserver(obs)
            colorObserver = nil
        }
    }

    private func hexString(for color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = Int(round(max(0, min(1, ns.redComponent)) * 255))
        let g = Int(round(max(0, min(1, ns.greenComponent)) * 255))
        let b = Int(round(max(0, min(1, ns.blueComponent)) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
