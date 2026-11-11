import SwiftUI
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Review hub
//
// Comments, tracked changes and version history used to be three separate docked panes plus an orange
// strip across the page. They are one collaborative hub now: [ Comments | Revisions | History ].

struct InspectorReviewTab: View {
    @ObservedObject var document: LettersDocumentController
    @Binding var segment: ReviewSegment
    @Binding var hoveredCommentId: UUID?
    var onAddComment: () -> Void
    var onJumpToOffset: (Int) -> Void

    private var openCommentCount: Int { document.sideNotes.reduce(0) { $0 + ($1.isResolved ? 0 : 1) } }

    var body: some View {
        VStack(spacing: 0) {
            StudioSegmentedControl(
                segments: [
                    StudioSegment(tag: ReviewSegment.comments, title: "Comments", badge: openCommentCount,
                                  help: "Comments on the text"),
                    StudioSegment(tag: .revisions, title: "Revisions", badge: document.revisions.count,
                                  help: "Tracked changes waiting for a decision"),
                    StudioSegment(tag: .history, title: "History", help: "Saved versions of this document")
                ],
                selected: segment,
                showsIcons: false,
                onSelect: { segment = $0 }
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.6)

            switch segment {
            case .comments:
                CommentsSegment(
                    document: document,
                    hoveredCommentId: $hoveredCommentId,
                    onAddComment: onAddComment,
                    onJumpToOffset: onJumpToOffset
                )
            case .revisions:
                RevisionsSegment(document: document)
            case .history:
                HistorySegment(store: document)
            }
        }
    }
}

// MARK: - Comments

private struct CommentsSegment: View {
    @ObservedObject var document: LettersDocumentController
    @Binding var hoveredCommentId: UUID?
    var onAddComment: () -> Void
    var onJumpToOffset: (Int) -> Void

    @State private var showResolved = false

    private var openNotes: [StudioSideNote] { document.sideNotes.filter { !$0.isResolved } }
    private var resolvedNotes: [StudioSideNote] { document.sideNotes.filter { $0.isResolved } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(summary)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: onAddComment) {
                        Label("Add comment", systemImage: "plus")
                    }
                    .buttonStyle(StudioPillButtonStyle(prominent: true))
                    .help("Comment on the selected text")
                }

                if document.sideNotes.isEmpty {
                    StudioEmptyState(
                        icon: "text.bubble",
                        title: "No comments yet",
                        message: "Select a passage, then choose Add comment to start a conversation about it."
                    )
                } else {
                    ForEach(openNotes) { note in
                        CommentCard(document: document, noteId: note.id, hoveredCommentId: $hoveredCommentId, onJumpToOffset: onJumpToOffset)
                    }

                    if !resolvedNotes.isEmpty {
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) { showResolved.toggle() }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .rotationEffect(.degrees(showResolved ? 90 : 0))
                                Text("Resolved (\(resolvedNotes.count))")
                                    .font(.system(size: 11.5, weight: .semibold))
                                Spacer()
                            }
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if showResolved {
                            ForEach(resolvedNotes) { note in
                                CommentCard(document: document, noteId: note.id, hoveredCommentId: $hoveredCommentId, onJumpToOffset: onJumpToOffset)
                            }
                        }
                    }
                }

                if !document.footnotes.isEmpty {
                    footnotes
                }
            }
            .padding(14)
        }
    }

    private var summary: String {
        if document.sideNotes.isEmpty { return "No comments" }
        let open = openNotes.count
        return open == 0 ? "All resolved" : (open == 1 ? "1 open" : "\(open) open")
    }

    private var footnotes: some View {
        StudioFormSection(title: "Footnotes (\(document.footnotes.count))", icon: "text.append") {
            ForEach(Array(document.footnotes.enumerated()), id: \.element.id) { index, note in
                if index > 0 { StudioRowDivider() }
                HStack(alignment: .top, spacing: 8) {
                    Text(note.referenceMarker)
                        .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(minWidth: 14)
                        .padding(.top, 2)
                    TextField("Footnote text", text: footnoteBinding(note.id), axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .lineLimit(1...6)
                    Button {
                        removeFootnote(note)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Delete footnote")
                }
                .padding(10)
            }
        }
    }

    private func footnoteBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { document.footnotes.first(where: { $0.id == id })?.text ?? "" },
            set: { newText in
                if let idx = document.footnotes.firstIndex(where: { $0.id == id }) {
                    document.footnotes[idx].text = newText
                }
            }
        )
    }

    private func removeFootnote(_ note: StudioFootnote) {
        document.footnotes.removeAll { $0.id == note.id }
        document.rawText = document.rawText.replacingOccurrences(of: "[\(note.referenceMarker)]", with: "")
    }
}

private struct CommentCard: View {
    @ObservedObject var document: LettersDocumentController
    let noteId: UUID
    @Binding var hoveredCommentId: UUID?
    var onJumpToOffset: (Int) -> Void

    @State private var isReplying = false
    @State private var draft = ""
    @FocusState private var replyFocused: Bool

    private var note: StudioSideNote? { document.sideNotes.first(where: { $0.id == noteId }) }

    var body: some View {
        if let note {
            card(note)
        }
    }

    private func card(_ note: StudioSideNote) -> some View {
        let isHovered = hoveredCommentId == note.id

        return VStack(alignment: .leading, spacing: 8) {
            // Author, date and the two card-level actions
            HStack(spacing: 7) {
                avatar(note.author, resolved: note.isResolved)
                VStack(alignment: .leading, spacing: 0) {
                    Text(note.author)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    Text(StudioTimeFormat.ago(note.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .help(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                Spacer(minLength: 4)

                iconButton(note.isResolved ? "checkmark.circle.fill" : "checkmark.circle",
                           tint: note.isResolved ? .green : .secondary,
                           help: note.isResolved ? "Reopen comment" : "Resolve comment") {
                    mutate { $0.isResolved.toggle() }
                }
                iconButton("trash", tint: .red.opacity(0.8), help: "Delete comment") {
                    document.sideNotes.removeAll { $0.id == noteId }
                }
            }

            // Quoted passage
            if let anchor = note.anchorText?.trimmingCharacters(in: .whitespacesAndNewlines), !anchor.isEmpty {
                Button {
                    if let location = note.rangeLocation { onJumpToOffset(location) }
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Capsule().fill(Color.orange.opacity(0.85)).frame(width: 2.5)
                        Text(anchor)
                            .font(.system(size: 11).italic())
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .disabled(note.rangeLocation == nil)
                .help(note.rangeLocation == nil ? "Quoted text" : "Jump to this passage")
            }

            // The comment itself, editable in place
            TextField("Write a comment", text: textBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(1...8)
                .foregroundColor(note.isResolved ? .secondary : .primary)

            // Thread
            if !note.replies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(note.replies) { reply in
                        HStack(alignment: .top, spacing: 7) {
                            avatar(reply.author, resolved: true, size: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 5) {
                                    Text(reply.author).font(.system(size: 11, weight: .semibold))
                                    Text(StudioTimeFormat.ago(reply.createdAt))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Text(reply.text)
                                    .font(.system(size: 11.5))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.leading, 6)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1)
                }
            }

            // Reply composer or the Reply button
            if isReplying {
                HStack(spacing: 6) {
                    TextField("Reply", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .focused($replyFocused)
                        .onSubmit(sendReply)
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Button("Send", action: sendReply)
                        .buttonStyle(StudioPillButtonStyle(prominent: true))
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button {
                        isReplying = false
                        draft = ""
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel reply")
                }
            } else if !note.isResolved {
                Button {
                    isReplying = true
                    replyFocused = true
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(note.isResolved ? 0.5 : 0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHovered ? Color.orange.opacity(0.8) : Color.primary.opacity(0.09), lineWidth: isHovered ? 1.4 : 0.5)
        )
        .opacity(note.isResolved ? 0.8 : 1)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) {
                if inside { hoveredCommentId = noteId } else if hoveredCommentId == noteId { hoveredCommentId = nil }
            }
        }
        .onDisappear {
            if hoveredCommentId == noteId { hoveredCommentId = nil }
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { note?.text ?? "" },
            set: { newText in mutate { $0.text = newText } }
        )
    }

    private func mutate(_ change: (inout StudioSideNote) -> Void) {
        guard let idx = document.sideNotes.firstIndex(where: { $0.id == noteId }) else { return }
        change(&document.sideNotes[idx])
    }

    private func sendReply() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let author = NSFullUserName().isEmpty ? "You" : NSFullUserName()
        mutate { $0.replies.append(StudioNoteReply(author: author, text: text)) }
        draft = ""
        isReplying = false
    }

    private func avatar(_ name: String, resolved: Bool, size: CGFloat = 22) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundColor(resolved ? .secondary : .accentColor)
            .frame(width: size, height: size)
            .background(Circle().fill(resolved ? Color.primary.opacity(0.10) : Color.accentColor.opacity(0.16)))
    }

    private func iconButton(_ icon: String, tint: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(StudioHoverButtonStyle(cornerRadius: 6))
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Revisions

private struct RevisionsSegment: View {
    @ObservedObject var document: LettersDocumentController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                StudioFormSection(title: "Track changes", icon: "pencil.and.outline") {
                    StudioFormRow(
                        label: "Track changes",
                        detail: document.isTrackChangesEnabled
                            ? "Edits are recorded for review"
                            : "Edits apply straight away"
                    ) {
                        Toggle("", isOn: $document.isTrackChangesEnabled.animation(.spring(response: 0.3, dampingFraction: 0.8)))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                }

                HStack(spacing: 8) {
                    Text(document.revisions.isEmpty ? "No pending changes" : "\(document.revisions.count) pending")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { document.rejectAllRevisions() }
                    } label: {
                        Label("Reject all", systemImage: "xmark")
                    }
                    .buttonStyle(StudioPillButtonStyle(tint: .red))
                    .disabled(document.revisions.isEmpty)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { document.acceptAllRevisions() }
                    } label: {
                        Label("Accept all", systemImage: "checkmark")
                    }
                    .buttonStyle(StudioPillButtonStyle(tint: .green))
                    .disabled(document.revisions.isEmpty)
                }

                if document.revisions.isEmpty {
                    StudioEmptyState(
                        icon: "checkmark.seal",
                        title: "Nothing to review",
                        message: document.isTrackChangesEnabled
                            ? "Edits you and the assistant make will be listed here to accept or reject."
                            : "Turn on Track changes to record edits instead of applying them silently."
                    )
                } else {
                    ForEach(document.revisions) { revision in
                        RevisionCard(document: document, revision: revision)
                    }
                }
            }
            .padding(14)
        }
    }
}

private struct RevisionCard: View {
    @ObservedObject var document: LettersDocumentController
    let revision: StudioTrackedRevision

    private var isInsertion: Bool { revision.kind == .insertion }
    private var tint: Color { isInsertion ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: isInsertion ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(isInsertion ? "Insertion" : "Deletion") · \(revision.author)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    Text(StudioTimeFormat.ago(revision.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 4)
                decisionButton("xmark", tint: .red, help: "Reject change") {
                    withAnimation(.easeOut(duration: 0.2)) { document.rejectRevision(id: revision.id) }
                }
                decisionButton("checkmark", tint: .green, help: "Accept change") {
                    withAnimation(.easeOut(duration: 0.2)) { document.acceptRevision(id: revision.id) }
                }
            }

            if let original = revision.originalText, !original.isEmpty {
                diffLine(prefix: "Was", text: original, color: .red.opacity(0.85), struck: true)
            }
            if !revision.text.isEmpty || revision.originalText == nil {
                diffLine(prefix: isInsertion ? "Now" : "Text", text: revision.text, color: isInsertion ? .green : .primary, struck: !isInsertion && revision.originalText == nil)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor).opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(tint.opacity(0.35), lineWidth: 0.75))
    }

    private func diffLine(prefix: String, text: String, color: Color, struck: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(prefix)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)
            Text(text)
                .font(.system(size: 11.5))
                .strikethrough(struck)
                .foregroundColor(color)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func decisionButton(_ icon: String, tint: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - History

private struct HistorySegment: View {
    @ObservedObject var store: LettersDocumentController
    @State private var hoveredId: UUID? = nil

    /// Milestones on the active thread, newest first.
    private var versions: [HistoryNode] {
        var path = [HistoryNode]()
        var current = store.mainBranchHeadId ?? store.currentSnapshotId
        while let id = current, let node = store.historyNodes[id] {
            path.append(node)
            current = node.parentId
        }
        return path.filter { $0.isMilestone || $0.isPinned }
    }

    private var alternates: [HistoryNode] {
        let active = Set(versions.map(\.id))
        let inactive = store.historyNodes.values.filter { !active.contains($0.id) && ($0.isMilestone || $0.isPinned) }
        let parents = Set(inactive.compactMap(\.parentId))
        return inactive.filter { !parents.contains($0.id) }.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(versions.isEmpty ? "No saved versions" : "\(versions.count) saved \(versions.count == 1 ? "version" : "versions")")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        store.saveMilestone()
                    } label: {
                        Label("Save version", systemImage: "bookmark")
                    }
                    .buttonStyle(StudioPillButtonStyle(prominent: true))
                    .help("Keep a snapshot of the document as it is now")
                }

                if versions.isEmpty {
                    StudioEmptyState(
                        icon: "clock.arrow.circlepath",
                        title: "No versions yet",
                        message: "Milestones such as inserted tables and images appear here. Use Save version to keep one yourself."
                    )
                } else {
                    VStack(spacing: 4) {
                        ForEach(versions) { node in
                            versionRow(node, isAlternate: false)
                        }
                    }
                }

                if !alternates.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.branch").font(.system(size: 10, weight: .semibold))
                        Text("Other branches").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .padding(.top, 6)

                    VStack(spacing: 4) {
                        ForEach(alternates) { node in
                            versionRow(node, isAlternate: true)
                        }
                    }
                }
            }
            .padding(14)
        }
        .onDisappear { store.endPeek() }
    }

    private func versionRow(_ node: HistoryNode, isAlternate: Bool) -> some View {
        let isCurrent = node.id == store.currentSnapshotId
        let isHovered = hoveredId == node.id

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if node.actor == .ai {
                    Image(systemName: "sparkles").font(.system(size: 10)).foregroundColor(.purple)
                }
                Text(node.customName ?? node.actionName)
                    .font(.system(size: 12, weight: isCurrent ? .semibold : .medium))
                    .lineLimit(1)
                if isCurrent {
                    Text("Current")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                }
                Spacer(minLength: 4)
                Button {
                    store.togglePin(id: node.id)
                } label: {
                    Image(systemName: node.isPinned ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundColor(node.isPinned ? .yellow : .secondary.opacity(0.7))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(StudioHoverButtonStyle(cornerRadius: 5))
                .help(node.isPinned ? "Unpin version" : "Pin version so it is never discarded")
            }

            HStack(spacing: 6) {
                Text(StudioTimeFormat.ago(node.timestamp))
                    .help(node.timestamp.formatted(date: .abbreviated, time: .standard))
                if let diff = node.diffSummary {
                    Text("·")
                    Text(diff)
                        .foregroundColor(diff.contains("+") ? .green : .secondary)
                }
                Spacer(minLength: 4)
                if isHovered && !isCurrent {
                    Text("Previewing")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .font(.system(size: 10.5).monospacedDigit())
            .foregroundColor(.secondary)

            if !isCurrent {
                HStack(spacing: 6) {
                    Button {
                        store.endPeek()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isAlternate { store.setAsMainBranch(nodeId: node.id) } else { store.revertTo(id: node.id) }
                        }
                    } label: {
                        Text(isAlternate ? "Make main & restore" : "Restore")
                    }
                    .buttonStyle(StudioPillButtonStyle(tint: isAlternate ? .orange : .accentColor))
                    .help("Replace the document with this version")
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isCurrent ? Color.accentColor.opacity(0.10) : (isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isCurrent ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                hoveredId = node.id
                if !isCurrent { store.startPeek(id: node.id) }
            } else if hoveredId == node.id {
                hoveredId = nil
                store.endPeek()
            }
        }
        .contextMenu {
            Button(node.isPinned ? "Unpin" : "Pin version") { store.togglePin(id: node.id) }
        }
    }
}
