import SwiftUI
import AppKit

public struct StudioVideoView: View {
    @Binding var videoBlock: StudioVideoBlock
    var onDelete: (() -> Void)? = nil
    var onChange: (() -> Void)? = nil
    var onToast: ((String) -> Void)? = nil

    public init(
        videoBlock: Binding<StudioVideoBlock>,
        onDelete: (() -> Void)? = nil,
        onChange: (() -> Void)? = nil,
        onToast: ((String) -> Void)? = nil
    ) {
        self._videoBlock = videoBlock
        self.onDelete = onDelete
        self.onChange = onChange
        self.onToast = onToast
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Pro Action Strip
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                    Text(videoBlock.platform.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.15))
                }

                Spacer()

                Button {
                    if let url = URL(string: videoBlock.url) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "safari")
                        Text("Open Video")
                    }
                    .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                if let onDelete = onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Video Card")
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 4)

            // Video Preview Card
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.12))
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )

                // Thumbnail & Play Overlay
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 48, height: 48)
                            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)

                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }

                    VStack(spacing: 4) {
                        Text(videoBlock.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(videoBlock.url)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            .onTapGesture {
                if let url = URL(string: videoBlock.url) {
                    NSWorkspace.shared.open(url)
                }
            }

            // Editable Caption / Title
            HStack {
                TextField("Video description...", text: $videoBlock.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .onChange(of: videoBlock.title) { _, _ in
                        onChange?()
                    }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 8)
    }
}
