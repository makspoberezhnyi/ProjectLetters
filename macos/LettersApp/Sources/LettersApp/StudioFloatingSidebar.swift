import SwiftUI

public struct StudioFloatingSidebar: View {
    @Binding var isPresented: Bool
    @Binding var rawText: String
    let documentPages: [String]
    @Binding var selectedPage: Int
    @Binding var sources: [String: Source]
    @Binding var tables: [StudioTableData]
    @Binding var images: [StudioImageBlock]
    @Binding var videos: [StudioVideoBlock]
    @Binding var showAIDrawer: Bool
    @Binding var showCommandPalette: Bool

    var onInsertSection: () -> Void
    var onInsertTable: () -> Void
    var onInsertImage: () -> Void
    var onAddSource: () -> Void
    var onInsertPageBreak: () -> Void
    var onToast: ((String) -> Void)?

    @State private var hoveredTool: String? = nil

    public init(
        isPresented: Binding<Bool>,
        rawText: Binding<String>,
        documentPages: [String] = [],
        selectedPage: Binding<Int>,
        sources: Binding<[String: Source]>,
        tables: Binding<[StudioTableData]>,
        images: Binding<[StudioImageBlock]>,
        videos: Binding<[StudioVideoBlock]>,
        showAIDrawer: Binding<Bool>,
        showCommandPalette: Binding<Bool>,
        onInsertSection: @escaping () -> Void,
        onInsertTable: @escaping () -> Void,
        onInsertImage: @escaping () -> Void,
        onAddSource: @escaping () -> Void,
        onInsertPageBreak: @escaping () -> Void,
        onToast: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._rawText = rawText
        self.documentPages = documentPages
        self._selectedPage = selectedPage
        self._sources = sources
        self._tables = tables
        self._images = images
        self._videos = videos
        self._showAIDrawer = showAIDrawer
        self._showCommandPalette = showCommandPalette
        self.onInsertSection = onInsertSection
        self.onInsertTable = onInsertTable
        self.onInsertImage = onInsertImage
        self.onAddSource = onAddSource
        self.onInsertPageBreak = onInsertPageBreak
        self.onToast = onToast
    }

    public var body: some View {
        VStack(spacing: 16) {
            // App Logo
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [Color.accentColor, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "feather")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 12)
            
            Divider()
                .frame(width: 24)
            
            // Instruments
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    instrumentButton(icon: "cursorarrow", name: "Select", shortcut: "v") { }
                    instrumentButton(icon: "text.quote", name: "Text Box", shortcut: "t") { onInsertSection() }
                    instrumentButton(icon: "photo", name: "Image", shortcut: "i") { onInsertImage() }
                    instrumentButton(icon: "tablecells", name: "Table", shortcut: "s") { onInsertTable() }
                    instrumentButton(icon: "arrow.up.and.down.text.horizontal", name: "Page Break") { onInsertPageBreak() }
                    
                    Divider()
                        .frame(width: 24)
                        .padding(.vertical, 4)
                        
                    instrumentButton(icon: "book.closed", name: "Sources", shortcut: "c") { onAddSource() }
                    instrumentButton(icon: "magnifyingglass", name: "Find", shortcut: "f", shortcutModifiers: [.command]) { showCommandPalette = true }
                    instrumentButton(icon: "sparkles", name: "AI Copilot", shortcut: "a") { showAIDrawer.toggle() }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 56)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func instrumentButton(
        icon: String, 
        name: String, 
        shortcut: Character? = nil,
        shortcutModifiers: EventModifiers = [],
        color: Color = .primary, 
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(hoveredTool == name ? Color.primary.opacity(0.08) : Color.clear)
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(hoveredTool == name ? color : color.opacity(0.7))
                    .symbolEffect(.bounce, value: hoveredTool == name)
            }
        }
        .buttonStyle(.plain)
        .help(shortcut != nil ? "\(name) (\(shortcutModifiers.contains(.command) ? "⌘" : "")\(shortcutModifiers.contains(.option) ? "⌥" : "")\(shortcutModifiers.contains(.shift) ? "⇧" : "")\(String(shortcut!).uppercased()))" : name)
        .onHover { isHovered in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                hoveredTool = isHovered ? name : nil
            }
        }
        .background(
            Group {
                if let key = shortcut {
                    Button("") { action() }
                        .keyboardShortcut(KeyEquivalent(key), modifiers: shortcutModifiers)
                        .hidden()
                }
            }
        )
    }
}
