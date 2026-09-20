import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct StudioImageView: View {
    @Binding var imageBlock: StudioImageBlock
    var onDelete: (() -> Void)? = nil
    var onChange: (() -> Void)? = nil
    var onToast: ((String) -> Void)? = nil

    @State private var showingSettings: Bool = false

    public init(
        imageBlock: Binding<StudioImageBlock>,
        onDelete: (() -> Void)? = nil,
        onChange: (() -> Void)? = nil,
        onToast: ((String) -> Void)? = nil
    ) {
        self._imageBlock = imageBlock
        self.onDelete = onDelete
        self.onChange = onChange
        self.onToast = onToast
    }

    private var nsImage: NSImage? {
        guard let data = Data(base64Encoded: imageBlock.base64Data) else { return nil }
        return NSImage(data: data)
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Pro Action Strip
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 11))
                    Text("Figure Media Block")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
                }

                // File Size & Compression Savings Badge
                if imageBlock.compressedByteSize > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                        Text(formatByteSize(imageBlock.compressedByteSize))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)

                        if imageBlock.originalByteSize > imageBlock.compressedByteSize {
                            let percent = Int((1.0 - Double(imageBlock.compressedByteSize) / Double(imageBlock.originalByteSize)) * 100.0)
                            Text("(-\(percent)%)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.08), in: Capsule())
                }

                Spacer()

                // Width Scale Presets
                HStack(spacing: 2) {
                    ForEach([50.0, 75.0, 100.0], id: \.self) { pct in
                        Button("\(Int(pct))%") {
                            imageBlock.scaleWidthPercent = pct
                            onChange?()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(imageBlock.scaleWidthPercent == pct ? .accentColor : .secondary)
                    }
                }

                // Aspect Ratio Menu
                Menu {
                    ForEach(StudioImageBlock.ImageAspectRatio.allCases, id: \.self) { ratio in
                        Button(ratio.rawValue) {
                            imageBlock.aspectRatioPreset = ratio
                            onChange?()
                        }
                    }
                } label: {
                    Label(imageBlock.aspectRatioPreset.rawValue, systemImage: "crop")
                        .font(.system(size: 10, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .controlSize(.mini)

                // Compression Menu
                Menu {
                    Button("Maximum Quality (Original)") {
                        compressImage(factor: 1.0)
                    }
                    Button("Optimized Print / Web (85%)") {
                        compressImage(factor: 0.85)
                    }
                    Button("Compact / Email (60%)") {
                        compressImage(factor: 0.60)
                    }
                } label: {
                    Label("Compress", systemImage: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 10, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .controlSize(.mini)

                // Delete
                if let onDelete = onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Image")
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 4)

            // Image Frame
            if let img = nsImage {
                let scaledWidth = max(180, 520 * (imageBlock.scaleWidthPercent / 100.0))

                ZStack {
                    if let ratio = imageBlock.aspectRatioPreset.ratio {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: scaledWidth, height: scaledWidth / ratio)
                            .clipped()
                    } else {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: scaledWidth)
                    }
                }
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
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

            // Editable Caption
            HStack {
                TextField("Figure caption...", text: $imageBlock.caption)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .onChange(of: imageBlock.caption) { _, _ in
                        onChange?()
                    }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 8)
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
