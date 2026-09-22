import SwiftUI

public struct StudioDocumentHistoryView: View {
    @Binding var isPresented: Bool
    @ObservedObject var store: LettersDocumentController
    
    // Smooth auto-scroll to bottom/current
    @State private var hoveredSnapshot: UUID? = nil
    
    public init(isPresented: Binding<Bool>, store: LettersDocumentController) {
        self._isPresented = isPresented
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Version History")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            if store.historyStack.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No history recorded yet.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(store.historyStack.enumerated()), id: \.element.id) { index, snapshot in
                                let isCurrent = (index == store.historyIndex)
                                let isUndone = (index > store.historyIndex)
                                
                                HStack(alignment: .top, spacing: 12) {
                                    // Track & Node
                                    VStack(spacing: 0) {
                                        Rectangle()
                                            .fill(index == 0 ? Color.clear : (isUndone ? Color.secondary.opacity(0.1) : StudioTheme.luminousCyan.opacity(0.4)))
                                            .frame(width: 2, height: 16)
                                        
                                        Circle()
                                            .fill(isCurrent ? StudioTheme.luminousCyan : (isUndone ? Color.secondary.opacity(0.2) : StudioTheme.luminousCyan.opacity(0.7)))
                                            .frame(width: isCurrent ? 10 : 8, height: isCurrent ? 10 : 8)
                                            .shadow(color: isCurrent ? StudioTheme.luminousCyan.opacity(0.5) : Color.clear, radius: 4, x: 0, y: 0)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: isCurrent ? 2 : 0)
                                            )
                                        
                                        Rectangle()
                                            .fill(index == store.historyStack.count - 1 ? Color.clear : ((isUndone || isCurrent) ? Color.secondary.opacity(0.1) : StudioTheme.luminousCyan.opacity(0.4)))
                                            .frame(width: 2)
                                    }
                                    
                                    // Action Details
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(snapshot.actionName)
                                            .font(.system(size: 13, weight: isCurrent ? .bold : .medium, design: .rounded))
                                            .foregroundColor(isUndone ? .secondary.opacity(0.6) : .primary)
                                            .padding(.top, 12)
                                        
                                        Text(timeFormatter.string(from: snapshot.timestamp))
                                            .font(.system(size: 10, weight: .regular, design: .rounded))
                                            .foregroundColor(.secondary.opacity(isUndone ? 0.4 : 0.8))
                                            .padding(.bottom, 16)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        store.revertTo(index: index)
                                    }
                                }
                                .onHover { hovering in
                                    if hovering {
                                        hoveredSnapshot = snapshot.id
                                    } else if hoveredSnapshot == snapshot.id {
                                        hoveredSnapshot = nil
                                    }
                                }
                                .background(hoveredSnapshot == snapshot.id ? Color.primary.opacity(0.04) : Color.clear)
                                .id(index)
                            }
                        }
                    }
                    .onChange(of: store.historyIndex) { newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                    .onAppear {
                        if store.historyStack.count > 0 {
                            proxy.scrollTo(store.historyIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        )
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .medium
        return df
    }
}
