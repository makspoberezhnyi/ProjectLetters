import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public enum CommandCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case format = "Formatting"
    case insert = "Insert"
    case layout = "Page Layout"
    case ai = "AI & Copilot"
    case file = "File & Export"
    case view = "View & Canvas"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "command"
        case .format: return "textformat"
        case .insert: return "plus.rectangle.on.rectangle"
        case .layout: return "doc.viewfinder"
        case .ai: return "sparkles"
        case .file: return "folder"
        case .view: return "eye"
        }
    }
}

public struct CommandItem: Identifiable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let icon: String
    public let category: CommandCategory
    public let shortcut: String?
    public let keywords: [String]
    public let action: () -> Void

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        icon: String,
        category: CommandCategory = .all,
        shortcut: String? = nil,
        keywords: [String] = [],
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.shortcut = shortcut
        self.keywords = keywords
        self.action = action
    }
}

public struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    let commands: [CommandItem]
    var onExecuteDirectCLI: ((String) -> Bool)? = nil

    @State private var query: String = ""
    @State private var selectedCategory: CommandCategory = .all
    @State private var selectedIndex: Int = 0

    public init(
        isPresented: Binding<Bool>,
        commands: [CommandItem],
        onExecuteDirectCLI: ((String) -> Bool)? = nil
    ) {
        self._isPresented = isPresented
        self.commands = commands
        self.onExecuteDirectCLI = onExecuteDirectCLI
    }

    private var directCLIItem: CommandItem? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()

        // 1. Font Size (e.g. "size 24", "font 18", "pt 16")
        if (lower.hasPrefix("size ") || lower.hasPrefix("font ") || lower.hasPrefix("pt ")) {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let pt = Double(parts[1]), pt >= 6 && pt <= 144 {
                return CommandItem(
                    title: "Set Font Size to \(Int(pt)) pt",
                    subtitle: "Direct CLI Command",
                    icon: "textformat.size",
                    category: .format,
                    shortcut: "↵"
                ) {
                    _ = onExecuteDirectCLI?(trimmed)
                }
            }
        }

        // 2. Zoom (e.g. "zoom 150", "zoom 100", "zoom 75")
        if lower.hasPrefix("zoom ") {
            let parts = lower.components(separatedBy: " ")
            if parts.count >= 2, let z = Double(parts[1]), z >= 25 && z <= 500 {
                return CommandItem(
                    title: "Set Canvas Zoom to \(Int(z))%",
                    subtitle: "Direct CLI Command",
                    icon: "magnifyingglass",
                    category: .view,
                    shortcut: "↵"
                ) {
                    _ = onExecuteDirectCLI?(trimmed)
                }
            }
        }

        // 3. Headings (e.g. "h1 Title", "h2 Heading", "h3 Section")
        if lower.hasPrefix("h1 ") || lower.hasPrefix("h2 ") || lower.hasPrefix("h3 ") || lower.hasPrefix("title ") {
            return CommandItem(
                title: "Insert Heading: \"\(trimmed.dropFirst(lower.hasPrefix("title ") ? 6 : 3))\"",
                subtitle: "Direct CLI Command",
                icon: "character.textbox",
                category: .insert,
                shortcut: "↵"
            ) {
                _ = onExecuteDirectCLI?(trimmed)
            }
        }

        // 4. AI Prompt ("ai ...", "ask ...", "write ...")
        if lower.hasPrefix("ai ") || lower.hasPrefix("ask ") || lower.hasPrefix("write ") || lower.hasPrefix("explain ") {
            return CommandItem(
                title: "Ask AI: \"\(trimmed)\"",
                subtitle: "Run prompt with AI Copilot",
                icon: "sparkles",
                category: .ai,
                shortcut: "↵"
            ) {
                _ = onExecuteDirectCLI?(trimmed)
            }
        }

        // 5. Default Fallback Dynamic Prompt if no exact match found
        if filteredBaseCommands.isEmpty {
            return CommandItem(
                title: "Execute / Ask Copilot: \"\(trimmed)\"",
                subtitle: "Natural language instruction or search",
                icon: "arrow.right.circle.fill",
                category: .ai,
                shortcut: "↵"
            ) {
                _ = onExecuteDirectCLI?(trimmed)
            }
        }

        return nil
    }

    private var filteredBaseCommands: [CommandItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var list = commands

        if selectedCategory != .all {
            list = list.filter { $0.category == selectedCategory }
        }

        if trimmed.isEmpty {
            return list
        }

        return list.filter { cmd in
            cmd.title.localizedCaseInsensitiveContains(trimmed) ||
            cmd.subtitle.localizedCaseInsensitiveContains(trimmed) ||
            cmd.keywords.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    private var allDisplayCommands: [CommandItem] {
        if let direct = directCLIItem {
            return [direct] + filteredBaseCommands.filter { $0.title != direct.title }
        }
        return filteredBaseCommands
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header / Omnibar Input
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 17, weight: .semibold))

                TextField("Type a command, format, element, or prompt...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .regular))
                    .onSubmit {
                        executeCurrentSelection()
                    }
                    .onKeyPress(.downArrow) {
                        moveSelection(delta: 1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        moveSelection(delta: -1)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        isPresented = false
                        return .handled
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isPresented = false
                } label: {
                    Text("esc")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CommandCategory.allCases) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCategory = cat
                                selectedIndex = 0
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10))
                                Text(cat.rawValue)
                                    .font(.system(size: 11, weight: selectedCategory == cat ? .semibold : .regular))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                selectedCategory == cat
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.primary.opacity(0.04),
                                in: Capsule()
                            )
                            .foregroundColor(selectedCategory == cat ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            Divider()

            // Results List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        if allDisplayCommands.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                Text("No commands found for \"\(query)\"")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 32)
                        } else {
                            ForEach(Array(allDisplayCommands.enumerated()), id: \.element.id) { index, command in
                                HStack(spacing: 12) {
                                    Image(systemName: command.icon)
                                        .frame(width: 22)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(index == selectedIndex ? .accentColor : .secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(command.title)
                                            .font(.system(size: 13, weight: index == selectedIndex ? .semibold : .medium))
                                            .foregroundColor(.primary)
                                        Text(command.subtitle)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if command.category != .all {
                                        Text(command.category.rawValue)
                                            .font(.system(size: 9, weight: .medium))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 3))
                                            .foregroundColor(.secondary.opacity(0.8))
                                    }

                                    if let shortcut = command.shortcut {
                                        Text(shortcut)
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    index == selectedIndex
                                        ? Color.accentColor.opacity(0.14)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )
                                .contentShape(Rectangle())
                                .id(index)
                                .onTapGesture {
                                    command.action()
                                    isPresented = false
                                }
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 340)
            }

            Divider()

            // Footer Bar with Keyboard Shortcuts
            HStack {
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Text("↑↓")
                            .font(.system(size: 10, weight: .bold))
                        Text("Navigate")
                            .font(.system(size: 10))
                    }
                    HStack(spacing: 3) {
                        Text("↵")
                            .font(.system(size: 10, weight: .bold))
                        Text("Execute")
                            .font(.system(size: 10))
                    }
                    HStack(spacing: 3) {
                        Text("esc")
                            .font(.system(size: 10, weight: .bold))
                        Text("Close")
                            .font(.system(size: 10))
                    }
                }
                .foregroundColor(.secondary)

                Spacer()

                Text("\(allDisplayCommands.count) available commands")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 580)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 28, x: 0, y: 12)
    }

    private func moveSelection(delta: Int) {
        let count = allDisplayCommands.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
    }

    private func executeCurrentSelection() {
        let list = allDisplayCommands
        if !list.isEmpty {
            let clamped = min(max(0, selectedIndex), list.count - 1)
            list[clamped].action()
            isPresented = false
        }
    }
}
