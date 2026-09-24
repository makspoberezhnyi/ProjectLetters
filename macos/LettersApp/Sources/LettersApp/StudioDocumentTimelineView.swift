import SwiftUI

public struct StudioDocumentHistoryView: View {
    @Binding var isPresented: Bool
    @ObservedObject var store: LettersDocumentController
    
    @State private var hoveredSnapshot: UUID? = nil
    
    public init(isPresented: Binding<Bool>, store: LettersDocumentController) {
        self._isPresented = isPresented
        self.store = store
    }
    
    // Calculate the active thread from root to current HEAD
    private var mainThread: [HistoryNode] {
        var path = [HistoryNode]()
        var current = store.mainBranchHeadId ?? store.currentSnapshotId
        while let currId = current, let node = store.historyNodes[currId] {
            path.append(node)
            current = node.parentId
        }
        return path.reversed().filter { $0.isMilestone || $0.isPinned }
    }
    
    // Find leaf nodes of alternate branches
    private var alternateBranches: [HistoryNode] {
        let activeSet = Set(mainThread.map { $0.id })
        // All nodes that are not in the main thread
        let inactive = store.historyNodes.values.filter { !activeSet.contains($0.id) && ($0.isMilestone || $0.isPinned) }
        
        // Find leaves: nodes that are NOT a parentId to any other inactive node
        let parentIds = Set(inactive.compactMap { $0.parentId })
        let leaves = inactive.filter { !parentIds.contains($0.id) }
        
        return leaves.sorted { $0.timestamp > $1.timestamp }
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
                    withAnimation(.spring()) {
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
            
            if store.historyNodes.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // 1. ACTIVE TIMELINE
                            VStack(alignment: .leading, spacing: 0) {
                                Text("CURRENT TIMELINE")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)
                                
                                let thread = mainThread
                                ForEach(Array(thread.enumerated()), id: \.element.id) { index, node in
                                    let isCurrent = (node.id == store.currentSnapshotId)
                                    NodeRow(
                                        node: node,
                                        isCurrent: isCurrent,
                                        isLast: index == thread.count - 1,
                                        store: store,
                                        hoveredSnapshot: $hoveredSnapshot
                                    )
                                    .id(node.id)
                                }
                            }
                            
                            // 2. ALTERNATE BRANCHES
                            let alts = alternateBranches
                            if !alts.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        Image(systemName: "arrow.triangle.branch")
                                            .font(.system(size: 10))
                                        Text("ALTERNATE BRANCHES")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                                    
                                    ForEach(alts, id: \.id) { node in
                                        NodeRow(
                                            node: node,
                                            isCurrent: (node.id == store.currentSnapshotId),
                                            isLast: true,
                                            store: store,
                                            hoveredSnapshot: $hoveredSnapshot,
                                            isAlternate: true
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .onChange(of: store.currentSnapshotId) { _, newValue in
                        if let nv = newValue {
                            withAnimation { proxy.scrollTo(nv, anchor: .center) }
                        }
                    }
                }
            }
        }
        .frame(width: 260)
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
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No milestones recorded.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

fileprivate struct NodeRow: View {
    let node: HistoryNode
    let isCurrent: Bool
    let isLast: Bool
    @ObservedObject var store: LettersDocumentController
    @Binding var hoveredSnapshot: UUID?
    var isAlternate: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Subway Line
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isAlternate ? Color.clear : StudioTheme.luminousCyan.opacity(0.4))
                    .frame(width: 2, height: 16)
                
                ZStack {
                    Circle()
                        .fill(isCurrent ? StudioTheme.luminousCyan : (isAlternate ? Color.orange : StudioTheme.luminousCyan.opacity(0.5)))
                        .frame(width: isCurrent ? 12 : 8, height: isCurrent ? 12 : 8)
                        .shadow(color: isCurrent ? StudioTheme.luminousCyan.opacity(0.5) : Color.clear, radius: 4, x: 0, y: 0)
                    
                    if node.actor == .ai {
                        Image(systemName: "sparkles")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Rectangle()
                    .fill(isLast ? Color.clear : StudioTheme.luminousCyan.opacity(0.4))
                    .frame(width: 2)
            }
            
            .frame(width: 16, alignment: .center)
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.customName ?? node.actionName)
                        .font(.system(size: 13, weight: isCurrent ? .bold : .medium, design: .rounded))
                        .foregroundColor(isCurrent ? .primary : .secondary)
                    
                    Spacer()
                    
                    if node.isPinned {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.top, 12)
                
                HStack {
                    Text(timeFormatter.string(from: node.timestamp))
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    if let diff = node.diffSummary {
                        Text("• " + diff)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(diff.contains("+") ? .green.opacity(0.8) : .secondary)
                    }
                }
                
                if isAlternate {
                    Button(action: {
                        withAnimation {
                            store.setAsMainBranch(nodeId: node.id)
                        }
                    }) {
                        Text("Set as Main")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 2)
                }
                
                Spacer().frame(height: 16)
            }
        }
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            store.endPeek()
            withAnimation {
                store.revertTo(id: node.id)
            }
        }
        .onHover { hovering in
            if hovering {
                hoveredSnapshot = node.id
                store.startPeek(id: node.id)
            } else if hoveredSnapshot == node.id {
                hoveredSnapshot = nil
                store.endPeek()
            }
        }
        .contextMenu {
            Button(node.isPinned ? "Unpin" : "Pin Milestone") {
                store.togglePin(id: node.id)
            }
        }
        .background(hoveredSnapshot == node.id ? Color.primary.opacity(0.04) : Color.clear)
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .medium
        return df
    }
}
