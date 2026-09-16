import SwiftUI
import LettersKit

public struct CommandItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let icon: String
    public let shortcut: String?
    public let action: () -> Void

    public init(title: String, subtitle: String, icon: String, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortcut = shortcut
        self.action = action
    }
}

public struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    let commands: [CommandItem]
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0

    public init(isPresented: Binding<Bool>, commands: [CommandItem]) {
        self._isPresented = isPresented
        self.commands = commands
    }

    private var filteredCommands: [CommandItem] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return commands
        }
        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))

                TextField("Type a command or search actions...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit {
                        if !filteredCommands.isEmpty, selectedIndex < filteredCommands.count {
                            filteredCommands[selectedIndex].action()
                            isPresented = false
                        }
                    }

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                        HStack(spacing: 12) {
                            Image(systemName: command.icon)
                                .frame(width: 20)
                                .foregroundColor(index == selectedIndex ? .accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(command.title)
                                    .font(.system(size: 14, weight: .medium))
                                Text(command.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if let shortcut = command.shortcut {
                                Text(shortcut)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(index == selectedIndex ? Color.accentColor.opacity(0.12) : Color.clear)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            command.action()
                            isPresented = false
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 540)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
    }
}
