import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Comment cards, track-changes strip & revisions popover

extension MainEditorView {
    func marginCommentCard(sn: StudioSideNote) -> some View {
        let binding = Binding(
            get: { sn.text },
            set: { newText in
                if let idx = documentController.sideNotes.firstIndex(where: { $0.id == sn.id }) {
                    documentController.sideNotes[idx].text = newText
                }
            }
        )

        return VStack(alignment: .leading, spacing: 4) {
            // Header: Author & Action Buttons
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(sn.isResolved ? Color.gray.opacity(0.3) : Color.accentColor.opacity(0.2))
                        .frame(width: 15, height: 15)
                    Text(String(sn.author.prefix(1)).uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(sn.isResolved ? .secondary : .accentColor)
                }

                Text(sn.author)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(sn.isResolved ? .secondary : .primary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                // Resolve toggle button
                Button(action: {
                    if let idx = documentController.sideNotes.firstIndex(where: { $0.id == sn.id }) {
                        documentController.sideNotes[idx].isResolved.toggle()
                        showToast(documentController.sideNotes[idx].isResolved ? "✓ Resolved comment" : "✓ Reopened comment")
                    }
                }) {
                    Image(systemName: sn.isResolved ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(sn.isResolved ? .green : .secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(sn.isResolved ? "Reopen comment" : "Mark as resolved")

                // Delete button
                Button(action: {
                    documentController.sideNotes.removeAll(where: { $0.id == sn.id })
                    showToast("✓ Deleted comment")
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete comment")
            }

            // Quoted Anchor Text Excerpt
            if let anchor = sn.anchorText, !anchor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Capsule()
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: 2.5, height: 14)
                    Text("\"\(anchor)\"")
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .italic()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.06))
                .cornerRadius(3)
            }

            // Comment text editor
            NativeFootnoteField(
                text: binding,
                placeholder: "Add a comment...",
                font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                textColor: sn.isResolved ? .secondaryLabelColor : .labelColor
            )
            .frame(minHeight: 20)
            .opacity(sn.isResolved ? 0.6 : 1.0)

            if sn.isResolved {
                Text("RESOLVED")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(2)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    hoveredCommentId == sn.id
                        ? Color.orange
                        : (sn.isResolved ? Color.secondary.opacity(0.2) : Color.accentColor.opacity(0.3)),
                    lineWidth: hoveredCommentId == sn.id ? 1.6 : 0.8
                )
        )
        .shadow(
            color: hoveredCommentId == sn.id ? Color.orange.opacity(0.25) : Color.black.opacity(0.06),
            radius: hoveredCommentId == sn.id ? 5 : 3,
            x: 0,
            y: 1.5
        )
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredCommentId = isHovered ? sn.id : nil
            }
        }
    }

    func onPaperRevisionCard(rev: StudioTrackedRevision) -> some View {
        let isInsertion = rev.kind == .insertion
        let accentColor = isInsertion ? Color.green : Color.red

        return VStack(alignment: .leading, spacing: 4) {
            // Header: Author + Action icon + 1-Click Accept / Reject
            HStack(spacing: 4) {
                Image(systemName: isInsertion ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(accentColor)

                Text(rev.author)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                // 1-Click Accept Button on Paper
                Button(action: {
                    documentController.acceptRevision(id: rev.id)
                    showToast("✓ Accepted change on paper")
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .buttonStyle(.plain)
                .help("Accept change (Keep this edit)")

                // 1-Click Reject Button on Paper
                Button(action: {
                    documentController.rejectRevision(id: rev.id)
                    showToast("✓ Rejected change on paper")
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 18, height: 18)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(.plain)
                .help("Reject change (Revert this edit)")
            }

            // Body text
            if !isInsertion, let orig = rev.originalText ?? (rev.text.isEmpty ? nil : rev.text) {
                Text(orig)
                    .font(.system(size: 9))
                    .strikethrough()
                    .foregroundColor(.red.opacity(0.85))
                    .lineLimit(3)
            } else {
                Text(rev.text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.green.opacity(0.9))
                    .lineLimit(3)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(accentColor.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1.5)
    }

    var reviewToolbarStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(documentController.isTrackChangesEnabled ? Color.orange : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(documentController.isTrackChangesEnabled ? "Track Changes ON" : "Review Mode")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(documentController.isTrackChangesEnabled ? .orange : .secondary)

                if !documentController.revisions.isEmpty {
                    Text("(\(documentController.revisions.count) changes)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !documentController.revisions.isEmpty {
                Button(action: { showRevisionsPopover.toggle() }) {
                    Label("Review Changes", systemImage: "list.bullet.rectangle")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showRevisionsPopover, arrowEdge: .bottom) {
                    revisionsPopoverContent
                }

                Button(action: {
                    documentController.acceptAllRevisions()
                    showToast("✓ Accepted all changes")
                }) {
                    Label("Accept All", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    documentController.rejectAllRevisions()
                    showToast("✓ Rejected all changes")
                }) {
                    Label("Reject All", systemImage: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button(action: { insertSideNote() }) {
                Label("Add Comment", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    documentController.isTrackChangesEnabled.toggle()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close Review Bar")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.2)),
            alignment: .bottom
        )
    }

    var revisionsPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "pencil.and.outline")
                    .foregroundColor(.orange)
                Text("Tracked Changes (\(documentController.revisions.count))")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
            }
            Divider()

            if documentController.revisions.isEmpty {
                Text("No pending revisions.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(documentController.revisions) { rev in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: rev.kind == .insertion ? "plus.circle.fill" : "minus.circle.fill")
                                        .foregroundColor(rev.kind == .insertion ? .green : .red)
                                        .font(.system(size: 11))
                                    Text("\(rev.author) • \(rev.kind.rawValue.capitalized)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(action: {
                                        documentController.acceptRevision(id: rev.id)
                                        showToast("✓ Accepted change")
                                    }) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.green)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Accept Change")

                                    Button(action: {
                                        documentController.rejectRevision(id: rev.id)
                                        showToast("✓ Rejected change")
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Reject Change")
                                }

                                if let orig = rev.originalText, !orig.isEmpty {
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("Was:")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text(orig)
                                            .font(.system(size: 10))
                                            .strikethrough()
                                            .foregroundColor(.red.opacity(0.8))
                                            .lineLimit(2)
                                    }
                                }

                                HStack(alignment: .top, spacing: 4) {
                                    Text("Now:")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(rev.text)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(rev.kind == .insertion ? .green : .primary)
                                        .lineLimit(3)
                                }
                            }
                            .padding(8)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.trailing, 16)
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}
