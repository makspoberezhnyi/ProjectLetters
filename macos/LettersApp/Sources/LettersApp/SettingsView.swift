import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

public struct SettingsView: View {
    @Binding var isPresented: Bool
    @Binding var fontFamily: String
    @Binding var fontSize: CGFloat
    @Binding var citationStyle: CitationStyle
    @Binding var pageSize: PageSizePreset
    @Binding var marginPreset: MarginPreset
    @Binding var showMarginGuides: Bool
    @Binding var showCropMarks: Bool
    var onToast: ((String) -> Void)?

    @State private var selectedTab: SettingsTab = .ai
    @State private var anthropicKey: String = ""
    @State private var openAIKey: String = ""
    @State private var geminiKey: String = ""
    @State private var ollamaEndpoint: String = "http://127.0.0.1:11434"

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case ai = "AI Copilot"
        case typography = "Typography"
        case citations = "Citations"
        case page = "Page & Guides"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .ai: return "sparkles"
            case .typography: return "textformat"
            case .citations: return "quote.opening"
            case .page: return "doc.viewfinder"
            }
        }
    }

    public init(
        isPresented: Binding<Bool>,
        fontFamily: Binding<String>,
        fontSize: Binding<CGFloat>,
        citationStyle: Binding<CitationStyle>,
        pageSize: Binding<PageSizePreset>,
        marginPreset: Binding<MarginPreset>,
        showMarginGuides: Binding<Bool>,
        showCropMarks: Binding<Bool>,
        onToast: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._fontFamily = fontFamily
        self._fontSize = fontSize
        self._citationStyle = citationStyle
        self._pageSize = pageSize
        self._marginPreset = marginPreset
        self._showMarginGuides = showMarginGuides
        self._showCropMarks = showCropMarks
        self.onToast = onToast
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Tabs
            HStack(spacing: 12) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.system(size: 12, weight: selectedTab == tab ? .bold : .medium))
                        .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(StudioTheme.surfaceHighlight)

            Divider()

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .ai:
                        aiSettingsSection
                    case .typography:
                        typographySettingsSection
                    case .citations:
                        citationsSettingsSection
                    case .page:
                        pageSettingsSection
                    }
                }
                .padding(20)
            }
            .frame(height: 340)

            Divider()

            // Footer
            HStack {
                Text("Letters Settings • Changes persist across documents")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(StudioTheme.surfaceHighlight)
        }
        .frame(width: 520)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .onAppear {
            loadStoredKeys()
        }
    }

    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Universal BYOK & Local AI Copilot")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                // Anthropic
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Anthropic Claude (3.5 / 3.7 Sonnet)", systemImage: "sparkles")
                            .font(.caption.bold())
                        Spacer()
                        Button("Save") {
                            saveKey(provider: .anthropic, key: anthropicKey)
                        }
                        .controlSize(.mini)
                    }
                    SecureField("sk-ant-...", text: $anthropicKey)
                        .textFieldStyle(.roundedBorder)
                }

                // OpenAI
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("OpenAI (GPT-4o / o3-mini)", systemImage: "sparkles")
                            .font(.caption.bold())
                        Spacer()
                        Button("Save") {
                            saveKey(provider: .openAI, key: openAIKey)
                        }
                        .controlSize(.mini)
                    }
                    SecureField("sk-...", text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                }

                // Google Gemini
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Google Gemini (Gemini 2.0 Flash)", systemImage: "sparkles")
                            .font(.caption.bold())
                        Spacer()
                        Button("Save") {
                            saveKey(provider: .google, key: geminiKey)
                        }
                        .controlSize(.mini)
                    }
                    SecureField("AIzaSy...", text: $geminiKey)
                        .textFieldStyle(.roundedBorder)
                }

                // Local Ollama
                VStack(alignment: .leading, spacing: 4) {
                    Label("Ollama (Local / Offline LLM)", systemImage: "desktopcomputer")
                        .font(.caption.bold())
                    TextField("http://127.0.0.1:11434", text: $ollamaEndpoint)
                        .textFieldStyle(.roundedBorder)
                    Text("No API key required. Runs completely offline.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var typographySettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Default Typography Engine")
                .font(.headline)

            HStack {
                Text("Default Font")
                Spacer()
                Picker("Font", selection: $fontFamily) {
                    Text("Default Serif (Georgia)").tag("Default Serif (Georgia)")
                    Text("Helvetica").tag("Helvetica")
                    Text("Times New Roman").tag("Times New Roman")
                    Text("SF Pro").tag("SF Pro")
                    Text("Menlo (Monospace)").tag("Menlo (Monospace)")
                }
                .labelsHidden()
                .frame(width: 200)
            }

            HStack {
                Text("Default Body Font Size")
                Spacer()
                HStack(spacing: 8) {
                    Button("-") {
                        fontSize = max(9, fontSize - 1)
                    }
                    Text("\(Int(fontSize)) pt")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 44)
                    Button("+") {
                        fontSize = min(36, fontSize + 1)
                    }
                }
            }
        }
    }

    private var citationsSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bibliographic Standard & Citation Style")
                .font(.headline)

            Picker("Active Citation Style", selection: $citationStyle) {
                ForEach(CitationStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.radioGroup)

            Text("Select 'Plain Attribution' if you wish to disable formal academic styling.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var pageSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Default Page Setup & Guides")
                .font(.headline)

            HStack {
                Text("Page Format Preset")
                Spacer()
                Picker("Format", selection: $pageSize) {
                    ForEach(PageSizePreset.allCases, id: \.self) { p in
                        Text("\(p.rawValue) (\(p.subtitle))").tag(p)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
            }

            HStack {
                Text("Margins Preset")
                Spacer()
                Picker("Margins", selection: $marginPreset) {
                    ForEach(MarginPreset.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
            }

            Divider()

            Toggle("Show Margin Guidelines on Sheet", isOn: $showMarginGuides)
            Toggle("Show Publisher Corner Crop Marks", isOn: $showCropMarks)
        }
    }

    private func loadStoredKeys() {
        if let a = AIGateway.shared.getKey(provider: .anthropic) {
            anthropicKey = a
        }
        if let o = AIGateway.shared.getKey(provider: .openAI) {
            openAIKey = o
        }
        if let g = AIGateway.shared.getKey(provider: .google) {
            geminiKey = g
        }
    }

    private func saveKey(provider: AIProvider, key: String) {
        try? AIGateway.shared.storeKey(provider: provider, key: key)
        onToast?("✓ Saved \(provider.rawValue) key to Keychain")
    }
}
