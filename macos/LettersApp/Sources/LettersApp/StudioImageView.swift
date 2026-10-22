import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct StudioImageView: View {
    @Binding var imageBlock: StudioImageBlock
    var onDelete: (() -> Void)? = nil
    var onChange: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var onToast: ((String) -> Void)? = nil

    @State private var showingSettings: Bool = false
    @State private var dragStartWidth: CGFloat? = nil
    @State private var liveScaleWidthPercent: Double? = nil
    @State private var cachedNSImage: NSImage? = nil
    @State private var isHovered: Bool = false
    @State private var isSelected: Bool = false
    @State private var dragMoveOffset: CGSize = .zero
    @State private var isDraggingMove: Bool = false
    @State private var isDraggingRotation: Bool = false
    @State private var liveRotationAngle: Double? = nil

    private var containerCoordSpace: String {
        "ImageCanvas_\(imageBlock.id.uuidString)"
    }

    public init(
        imageBlock: Binding<StudioImageBlock>,
        onDelete: (() -> Void)? = nil,
        onChange: (() -> Void)? = nil,
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil,
        onToast: ((String) -> Void)? = nil
    ) {
        self._imageBlock = imageBlock
        self.onDelete = onDelete
        self.onChange = onChange
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onToast = onToast
    }

    private var displayImage: NSImage? {
        if let cached = cachedNSImage { return cached }
        guard let data = Data(base64Encoded: imageBlock.base64Data),
              let img = NSImage(data: data) else { return nil }
        return img
    }

    private func reloadImageCache() {
        guard let data = Data(base64Encoded: imageBlock.base64Data) else {
            cachedNSImage = nil
            return
        }
        cachedNSImage = NSImage(data: data)
    }

    private func calculateImageHeight(img: NSImage, scaledWidth: CGFloat) -> CGFloat {
        if let ratio = imageBlock.aspectRatioPreset.ratio, ratio > 0 {
            return scaledWidth / ratio
        }
        let size = img.size
        if size.width > 0 && size.height > 0 {
            return max(30, scaledWidth * (size.height / size.width))
        }
        return scaledWidth * 0.75
    }

    private var isBlockMode: Bool {
        imageBlock.wrapMode == .topAndBottom || imageBlock.wrapMode == .inline
    }

    private func applyDragMove(translation: CGSize) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            dragMoveOffset = .zero
            isDraggingMove = false
        }
        isSelected = true

        if isBlockMode {
            // Word-style Paragraph Re-anchoring for Top-and-Bottom and In-line:
            // Only re-anchor if vertical movement is deliberate (> 80pt) and primarily vertical
            let isPrimarilyVertical = abs(translation.height) > abs(translation.width) * 1.5
            if abs(translation.height) > 80 && isPrimarilyVertical {
                if translation.height < 0 {
                    onMoveUp?()
                } else {
                    onMoveDown?()
                }
            }

            // Smooth horizontal position adjustment (follows cursor direction 1:1, never flips alignment)
            let newX = imageBlock.offsetX + translation.width
            let maxOffsetX: CGFloat = 280.0
            imageBlock.offsetX = min(maxOffsetX, max(-maxOffsetX, newX))
            imageBlock.offsetY = 0

            onChange?()
            return
        }

        // Free-floating positioning for Square, Behind Text, and In Front of Text
        let maxOffsetX: CGFloat = 400.0
        let maxOffsetY: CGFloat = 600.0
        imageBlock.offsetX = min(maxOffsetX, max(-maxOffsetX, imageBlock.offsetX + translation.width))
        imageBlock.offsetY = min(maxOffsetY, max(-maxOffsetY, imageBlock.offsetY + translation.height))
        onChange?()
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Image Frame with Interactive Free Move & Resize Handle & Context Menu
            if let img = displayImage {
                let currentPct = liveScaleWidthPercent ?? imageBlock.scaleWidthPercent
                let scaledWidth = max(120, min(560, 520 * (currentPct / 100.0)))
                let imageHeight = calculateImageHeight(img: img, scaledWidth: scaledWidth)
                let frameAlign: Alignment = imageBlock.alignment == .leading ? .leading : (imageBlock.alignment == .trailing ? .trailing : .center)
                let effectiveAngle = liveRotationAngle ?? imageBlock.rotationAngle

                HStack(alignment: .center, spacing: 0) {
                    if imageBlock.alignment == .trailing || imageBlock.alignment == .center { Spacer(minLength: 0) }

                    VStack(spacing: 4) {
                        // Main Image Box with Corner Overlays (bounded strictly to image size)
                        Group {
                            if imageBlock.aspectRatioPreset.ratio != nil {
                                Image(nsImage: img)
                                    .interpolation(.high)
                                    .antialiased(true)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: scaledWidth, height: imageHeight)
                                    .clipped()
                            } else {
                                Image(nsImage: img)
                                    .interpolation(.high)
                                    .antialiased(true)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: scaledWidth, height: imageHeight)
                            }
                        }
                        .rotationEffect(.degrees(effectiveAngle))
                        .frame(width: scaledWidth, height: imageHeight)
                        .coordinateSpace(name: "ImageBoxCoord_\(imageBlock.id.uuidString)")
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isSelected ? Color.accentColor : (isHovered ? Color.accentColor.opacity(0.4) : Color.black.opacity(0.12)), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: isSelected ? Color.accentColor.opacity(0.2) : Color.black.opacity(0.08), radius: isSelected ? 8 : 6, x: 0, y: isSelected ? 4 : 3)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isSelected = true
                        }
                        .onHover { hovering in
                            if hovering {
                                NSCursor.openHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        // Word-style Smooth 1:1 Drag Gesture (Global coordinate tracking)
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .onChanged { val in
                                    isDraggingMove = true
                                    dragMoveOffset = val.translation
                                }
                                .onEnded { val in
                                    applyDragMove(translation: val.translation)
                                }
                        )
                        .contextMenu {
                            imageContextMenuContent
                        }
                        // Floating Word-style Paragraph Anchor Icon (Floats outside in Left Gutter Margin, Never moves layout)
                        .overlay(alignment: .leading) {
                            if isSelected {
                                Image(systemName: "anchor")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color.accentColor.opacity(0.85))
                                    .padding(4)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(Color.accentColor.opacity(0.25), lineWidth: 0.5))
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
                                    .offset(x: -28)
                                    .allowsHitTesting(false)
                                    .help("Anchored to paragraph (Word-style)")
                                    .transition(.opacity)
                            }
                        }
                        // Floating Top-Center Rotation Handle Stem & Knob (Floats outside top edge, Never shifts image down)
                        .overlay(alignment: .top) {
                            if isHovered || isSelected || isDraggingRotation {
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 8.5, weight: .bold))
                                                .foregroundColor(Color.accentColor)
                                        )
                                        .overlay(Circle().stroke(Color.accentColor.opacity(0.6), lineWidth: 1))
                                        .shadow(color: Color.black.opacity(0.15), radius: 2, y: 1)
                                        .contentShape(Circle())
                                        .help("Drag to rotate figure (\(Int(effectiveAngle))°)")
                                        .onHover { hovering in
                                            if hovering { NSCursor.crosshair.push() } else { NSCursor.pop() }
                                        }
                                        .gesture(
                                            DragGesture(minimumDistance: 1, coordinateSpace: .named("ImageBoxCoord_\(imageBlock.id.uuidString)"))
                                                .onChanged { val in
                                                    isDraggingRotation = true
                                                    let center = CGPoint(x: scaledWidth / 2, y: imageHeight / 2)
                                                    let dx = val.location.x - center.x
                                                    let dy = val.location.y - center.y
                                                    let rad = atan2(dy, dx)
                                                    var deg = rad * 180.0 / .pi + 90.0
                                                    if deg < 0 { deg += 360.0 }
                                                    let snapped = round(deg / 15.0) * 15.0
                                                    if abs(deg - snapped) < 4.0 {
                                                        deg = snapped
                                                    }
                                                    liveRotationAngle = deg
                                                }
                                                .onEnded { _ in
                                                    if let finalAngle = liveRotationAngle {
                                                        imageBlock.rotationAngle = finalAngle
                                                    }
                                                    liveRotationAngle = nil
                                                    isDraggingRotation = false
                                                    onChange?()
                                                }
                                        )

                                    Rectangle()
                                        .fill(Color.accentColor.opacity(0.6))
                                        .frame(width: 1.5, height: 12)
                                }
                                .offset(y: -28)
                                .transition(.opacity)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            // Word-style "Layout Options" Button (Floating outside Top-Right)
                            if isHovered || isSelected {
                                layoutOptionsButton
                                    .offset(x: 26, y: -2)
                                    .transition(.opacity)
                            }
                        }
                        // Word-style 8 Transform Handles
                        .overlay(alignment: .topLeading) {
                            cornerHandle(isLeft: true, scaledWidth: scaledWidth, offset: CGSize(width: -4, height: -4))
                        }
                        .overlay(alignment: .topTrailing) {
                            cornerHandle(isLeft: false, scaledWidth: scaledWidth, offset: CGSize(width: 4, height: -4))
                        }
                        .overlay(alignment: .bottomLeading) {
                            cornerHandle(isLeft: true, scaledWidth: scaledWidth, offset: CGSize(width: -4, height: 4))
                        }
                        .overlay(alignment: .bottomTrailing) {
                            cornerHandle(isLeft: false, scaledWidth: scaledWidth, offset: CGSize(width: 4, height: 4))
                        }
                        .overlay(alignment: .leading) {
                            edgeHandle(isHorizontal: true, isNegative: true, scaledWidth: scaledWidth, offset: CGSize(width: -3, height: 0))
                        }
                        .overlay(alignment: .trailing) {
                            edgeHandle(isHorizontal: true, isNegative: false, scaledWidth: scaledWidth, offset: CGSize(width: 3, height: 0))
                        }

                        // Editable Caption (aligned and moved with figure)
                        TextField("Figure caption...", text: $imageBlock.caption)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(width: scaledWidth)
                            .contextMenu {
                                imageContextMenuContent
                            }
                            .onChange(of: imageBlock.caption) { _, _ in
                                onChange?()
                            }
                            .padding(.top, 2)
                    }
                    .offset(
                        x: imageBlock.offsetX + dragMoveOffset.width,
                        y: (isBlockMode && !isDraggingMove) ? 0 : (imageBlock.offsetY + dragMoveOffset.height)
                    )

                    if imageBlock.alignment == .leading || imageBlock.alignment == .center { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity, alignment: frameAlign)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 160)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No Image Loaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
        .padding(.vertical, 8)
        .coordinateSpace(name: containerCoordSpace)
        .onExitCommand {
            isSelected = false
        }
        .onAppear {
            reloadImageCache()
        }
        .onChange(of: imageBlock.base64Data) { _, _ in
            reloadImageCache()
        }
    }

    // MARK: - Word-style Corner & Edge Sizing Handles
    @ViewBuilder
    private func cornerHandle(isLeft: Bool, scaledWidth: CGFloat, offset: CGSize) -> some View {
        if isHovered || isSelected || liveScaleWidthPercent != nil {
            Circle()
                .fill(Color.white)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                .shadow(color: Color.black.opacity(0.15), radius: 1, y: 1)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
                .offset(offset)
                .onHover { hovering in
                    if hovering { NSCursor.crosshair.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { value in
                            let baseWidth = dragStartWidth ?? scaledWidth
                            if dragStartWidth == nil {
                                dragStartWidth = scaledWidth
                            }
                            let delta = isLeft ? -value.translation.width : value.translation.width
                            let newWidth = max(100, min(560, baseWidth + delta))
                            liveScaleWidthPercent = (newWidth / 520.0) * 100.0
                        }
                        .onEnded { _ in
                            if let finalPct = liveScaleWidthPercent {
                                imageBlock.scaleWidthPercent = max(20.0, min(100.0, finalPct))
                            }
                            dragStartWidth = nil
                            liveScaleWidthPercent = nil
                            onChange?()
                        }
                )
        }
    }

    @ViewBuilder
    private func edgeHandle(isHorizontal: Bool, isNegative: Bool, scaledWidth: CGFloat, offset: CGSize) -> some View {
        if isHovered || isSelected || liveScaleWidthPercent != nil {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white)
                .frame(width: isHorizontal ? 3.5 : 12, height: isHorizontal ? 12 : 3.5)
                .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.accentColor, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.12), radius: 1, y: 1)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
                .offset(offset)
                .onHover { hovering in
                    if hovering { (isHorizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { value in
                            let baseWidth = dragStartWidth ?? scaledWidth
                            if dragStartWidth == nil {
                                dragStartWidth = scaledWidth
                            }
                            let delta = isNegative ? -value.translation.width : value.translation.width
                            let newWidth = max(100, min(560, baseWidth + delta))
                            liveScaleWidthPercent = (newWidth / 520.0) * 100.0
                        }
                        .onEnded { _ in
                            if let finalPct = liveScaleWidthPercent {
                                imageBlock.scaleWidthPercent = max(20.0, min(100.0, finalPct))
                            }
                            dragStartWidth = nil
                            liveScaleWidthPercent = nil
                            onChange?()
                        }
                )
        }
    }

    // MARK: - Word-style Layout Options Button
    private var layoutOptionsButton: some View {
        Menu {
            Section("Text Wrapping (Word-Style)") {
                ForEach(StudioImageBlock.ImageWrapMode.allCases, id: \.self) { mode in
                    Button {
                        imageBlock.wrapMode = mode
                        if mode == .inline {
                            imageBlock.offsetX = 0
                            imageBlock.offsetY = 0
                        }
                        onChange?()
                        onToast?("✓ Wrap Mode: \(mode.rawValue)")
                    } label: {
                        if imageBlock.wrapMode == mode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Label(mode.rawValue, systemImage: mode.systemImage)
                        }
                    }
                }
            }

            Section("Alignment & Position") {
                if isBlockMode {
                    if let onMoveUp = onMoveUp {
                        Button {
                            onMoveUp()
                        } label: {
                            Label("Move Above Paragraph (Up)", systemImage: "arrow.up")
                        }
                    }
                    if let onMoveDown = onMoveDown {
                        Button {
                            onMoveDown()
                        } label: {
                            Label("Move Below Paragraph (Down)", systemImage: "arrow.down")
                        }
                    }
                }
                Button("Align Left") {
                    imageBlock.alignment = .leading
                    imageBlock.offsetX = 0
                    onChange?()
                }
                Button("Align Center") {
                    imageBlock.alignment = .center
                    imageBlock.offsetX = 0
                    onChange?()
                }
                Button("Align Right") {
                    imageBlock.alignment = .trailing
                    imageBlock.offsetX = 0
                    onChange?()
                }
                Button("Center / Reset Position") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        imageBlock.offsetX = 0
                        imageBlock.offsetY = 0
                        imageBlock.alignment = .center
                    }
                    onChange?()
                    onToast?("✓ Reset figure position to center")
                }
            }

            Section("Scale Presets") {
                ForEach([25.0, 50.0, 75.0, 100.0], id: \.self) { pct in
                    Button("\(Int(pct))%") {
                        imageBlock.scaleWidthPercent = pct
                        onChange?()
                    }
                }
            }

            Section("Rotation") {
                Button("Rotate 90° Clockwise") {
                    imageBlock.rotationAngle = (imageBlock.rotationAngle + 90.0).truncatingRemainder(dividingBy: 360.0)
                    onChange?()
                }
                Button("Rotate 90° Counter-Clockwise") {
                    imageBlock.rotationAngle = (imageBlock.rotationAngle - 90.0 + 360.0).truncatingRemainder(dividingBy: 360.0)
                    onChange?()
                }
                if imageBlock.rotationAngle != 0 {
                    Button("Reset Rotation (0°)") {
                        imageBlock.rotationAngle = 0
                        onChange?()
                    }
                }
            }
        } label: {
            HStack(spacing: 2.5) {
                Image(systemName: imageBlock.wrapMode.systemImage)
                    .font(.system(size: 9, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 6, weight: .bold))
            }
            .padding(.horizontal, 5.5)
            .padding(.vertical, 3.5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
            .foregroundColor(.primary.opacity(0.85))
            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
        }
        .menuStyle(.borderlessButton)
        .help("Layout Options: Text wrapping and positioning")
    }

    // MARK: - Native Context Menu Content
    @ViewBuilder
    private var imageContextMenuContent: some View {
        Menu("Text Wrapping") {
            ForEach(StudioImageBlock.ImageWrapMode.allCases, id: \.self) { mode in
                Button {
                    imageBlock.wrapMode = mode
                    if mode == .inline {
                        imageBlock.offsetX = 0
                        imageBlock.offsetY = 0
                    }
                    onChange?()
                    onToast?("✓ Wrap Mode: \(mode.rawValue)")
                } label: {
                    if imageBlock.wrapMode == mode {
                        Label(mode.rawValue, systemImage: "checkmark")
                    } else {
                        Label(mode.rawValue, systemImage: mode.systemImage)
                    }
                }
            }
        }

        Menu("Rotate & Flip") {
            Button("Rotate 90° Clockwise") {
                imageBlock.rotationAngle = (imageBlock.rotationAngle + 90.0).truncatingRemainder(dividingBy: 360.0)
                onChange?()
            }
            Button("Rotate 90° Counter-Clockwise") {
                imageBlock.rotationAngle = (imageBlock.rotationAngle - 90.0 + 360.0).truncatingRemainder(dividingBy: 360.0)
                onChange?()
            }
            Button("Rotate 180°") {
                imageBlock.rotationAngle = (imageBlock.rotationAngle + 180.0).truncatingRemainder(dividingBy: 360.0)
                onChange?()
            }
            if imageBlock.rotationAngle != 0 {
                Divider()
                Button("Reset Rotation (\(Int(imageBlock.rotationAngle))° -> 0°)") {
                    imageBlock.rotationAngle = 0
                    onChange?()
                }
            }
        }

        Menu("Position & Move") {
            Button("Center / Reset Position") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    imageBlock.offsetX = 0
                    imageBlock.offsetY = 0
                    imageBlock.alignment = .center
                }
                onChange?()
                onToast?("✓ Reset figure position to center")
            }

            Divider()

            Button {
                imageBlock.alignment = .leading
                imageBlock.offsetX = 0
                onChange?()
            } label: {
                if imageBlock.alignment == .leading && imageBlock.offsetX == 0 {
                    Label("Align Left", systemImage: "checkmark")
                } else {
                    Text("Align Left")
                }
            }

            Button {
                imageBlock.alignment = .center
                imageBlock.offsetX = 0
                onChange?()
            } label: {
                if imageBlock.alignment == .center && imageBlock.offsetX == 0 {
                    Label("Align Center", systemImage: "checkmark")
                } else {
                    Text("Align Center")
                }
            }

            Button {
                imageBlock.alignment = .trailing
                imageBlock.offsetX = 0
                onChange?()
            } label: {
                if imageBlock.alignment == .trailing && imageBlock.offsetX == 0 {
                    Label("Align Right", systemImage: "checkmark")
                } else {
                    Text("Align Right")
                }
            }

            Divider()

            if isBlockMode {
                if let onMoveUp = onMoveUp {
                    Button {
                        onMoveUp()
                    } label: {
                        Label("Move Above Paragraph (Up)", systemImage: "arrow.up")
                    }
                }
                if let onMoveDown = onMoveDown {
                    Button {
                        onMoveDown()
                    } label: {
                        Label("Move Below Paragraph (Down)", systemImage: "arrow.down")
                    }
                }
            } else {
                Button("Nudge Up (10 pt)") {
                    imageBlock.offsetY -= 10
                    onChange?()
                }
                Button("Nudge Down (10 pt)") {
                    imageBlock.offsetY += 10
                    onChange?()
                }
                Button("Nudge Left (10 pt)") {
                    imageBlock.offsetX -= 10
                    onChange?()
                }
                Button("Nudge Right (10 pt)") {
                    imageBlock.offsetX += 10
                    onChange?()
                }
            }
        }

        Menu("Size") {
            ForEach([25.0, 50.0, 75.0, 100.0], id: \.self) { pct in
                let isSelected = abs(imageBlock.scaleWidthPercent - pct) < 3.0
                Button {
                    imageBlock.scaleWidthPercent = pct
                    onChange?()
                } label: {
                    if isSelected {
                        Label("\(Int(pct))%", systemImage: "checkmark")
                    } else {
                        Text("\(Int(pct))%")
                    }
                }
            }
        }

        Menu("Aspect Ratio") {
            ForEach(StudioImageBlock.ImageAspectRatio.allCases, id: \.self) { ratio in
                let isSelected = (imageBlock.aspectRatioPreset == ratio)
                Button {
                    imageBlock.aspectRatioPreset = ratio
                    onChange?()
                } label: {
                    if isSelected {
                        Label(ratio.rawValue, systemImage: "checkmark")
                    } else {
                        Text(ratio.rawValue)
                    }
                }
            }
        }

        Menu("Compress Quality") {
            Button("Maximum Quality (Original)") { compressImage(factor: 1.0) }
            Button("Optimized Print / Web (85%)") { compressImage(factor: 0.85) }
            Button("Compact / Email (60%)") { compressImage(factor: 0.60) }
        }

        if imageBlock.compressedByteSize > 0 {
            let kb = formatByteSize(imageBlock.compressedByteSize)
            if imageBlock.originalByteSize > imageBlock.compressedByteSize {
                let percent = Int((1.0 - Double(imageBlock.compressedByteSize) / Double(imageBlock.originalByteSize)) * 100.0)
                Text("Size: \(kb) (-\(percent)%)")
            } else {
                Text("Size: \(kb)")
            }
        }

        Divider()

        if let onDelete = onDelete {
            Button(role: .destructive, action: onDelete) {
                Label("Delete Figure", systemImage: "trash")
            }
        }
    }

    private func compressImage(factor: Double) {
        guard let data = Data(base64Encoded: imageBlock.base64Data),
              let nsImg = NSImage(data: data),
              let tiff = nsImg.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return
        }

        if factor >= 1.0 {
            onToast?("✓ Using full original image quality")
            return
        }

        guard let compressedData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: factor]) else {
            return
        }

        if imageBlock.originalByteSize == 0 {
            imageBlock.originalByteSize = data.count
        }
        imageBlock.compressedByteSize = compressedData.count
        imageBlock.base64Data = compressedData.base64EncodedString()
        onChange?()

        let savedPct = Int((1.0 - Double(compressedData.count) / Double(max(1, imageBlock.originalByteSize))) * 100.0)
        onToast?("✓ Compressed image: Saved \(savedPct)% (\(formatByteSize(compressedData.count)))")
    }

    private func formatByteSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb > 1024.0 {
            return String(format: "%.1f MB", kb / 1024.0)
        }
        return "\(Int(kb)) KB"
    }

    public static func pickImageFromDisk(completion: @escaping (StudioImageBlock?) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Insert Image"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let typePng = UTType(filenameExtension: "png"),
           let typeJpg = UTType(filenameExtension: "jpg"),
           let typeJpeg = UTType(filenameExtension: "jpeg"),
           let typeWebp = UTType(filenameExtension: "webp") {
            panel.allowedContentTypes = [typePng, typeJpg, typeJpeg, typeWebp]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let base64 = data.base64EncodedString()
                let filename = url.deletingPathExtension().lastPathComponent
                let block = StudioImageBlock(
                    base64Data: base64,
                    originalByteSize: data.count,
                    compressedByteSize: data.count,
                    caption: "Figure: \(filename)"
                )
                completion(block)
            } catch {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
}
