import SwiftUI

public enum StudioTool: String, CaseIterable, Identifiable {
    case select = "Select"
    case text = "Text Frame"
    case table = "Smart Table"
    case image = "Image Figure"
    case citation = "Linked Source"
    case style = "Style Rules"
    case copilot = "AI Copilot"
    case pan = "Hand Pan"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .text: return "textformat"
        case .table: return "tablecells"
        case .image: return "photo"
        case .citation: return "quote.bubble"
        case .style: return "checkmark.shield"
        case .copilot: return "sparkles"
        case .pan: return "hand.raised"
        }
    }

    public var shortcut: String {
        switch self {
        case .select: return "V"
        case .text: return "T"
        case .table: return "S"
        case .image: return "I"
        case .citation: return "C"
        case .style: return "L"
        case .copilot: return "A"
        case .pan: return "H"
        }
    }
}

public struct StudioToolRail: View {
    @Binding var activeTool: StudioTool
    var onToolClicked: ((StudioTool) -> Void)?

    public init(activeTool: Binding<StudioTool>, onToolClicked: ((StudioTool) -> Void)? = nil) {
        self._activeTool = activeTool
        self.onToolClicked = onToolClicked
    }

    public var body: some View {
        VStack(spacing: 4) {
            ForEach(StudioTool.allCases) { tool in
                Button {
                    activeTool = tool
                    onToolClicked?(tool)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(activeTool == tool ? StudioTheme.surfaceHighlight : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(activeTool == tool ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                            )

                        Image(systemName: tool.icon)
                            .font(.system(size: 14, weight: activeTool == tool ? .semibold : .regular))
                            .foregroundColor(activeTool == tool ? .accentColor : .secondary)
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help("\(tool.rawValue) (\(tool.shortcut))")
                .keyboardShortcut(KeyEquivalent(Character(tool.shortcut.lowercased())), modifiers: [])
            }

            Spacer()

            Divider()
                .padding(.horizontal, 4)

            Button {
                onToolClicked?(.copilot)
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("Studio Help & Shortcuts")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(width: 42)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .trailing
        )
    }
}
