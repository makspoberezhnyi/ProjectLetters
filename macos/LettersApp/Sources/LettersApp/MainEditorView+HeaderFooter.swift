import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Docked header / footer editing strip

extension MainEditorView {
    var headerFooterToolbarStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: activeHeaderFooterTarget == .header ? "arrow.up.to.line" : "arrow.down.to.line")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("Editing \(activeHeaderFooterTarget.rawValue)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            // Custom Compact Switcher (Header vs Footer)
            HStack(spacing: 1) {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        activeHeaderFooterTarget = .header
                    }
                } label: {
                    Text("Header")
                        .font(.system(size: 10, weight: activeHeaderFooterTarget == .header ? .bold : .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            activeHeaderFooterTarget == .header ? Color.accentColor.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .foregroundColor(activeHeaderFooterTarget == .header ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        activeHeaderFooterTarget = .footer
                    }
                } label: {
                    Text("Footer")
                        .font(.system(size: 10, weight: activeHeaderFooterTarget == .footer ? .bold : .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            activeHeaderFooterTarget == .footer ? Color.accentColor.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .foregroundColor(activeHeaderFooterTarget == .footer ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))

            Divider().frame(height: 14)

            // Page Number Position Picker Menu
            Menu {
                ForEach(PageNumberPosition.allCases, id: \.self) { pos in
                    Button(pos.rawValue) {
                        documentController.headerFooter.pageNumberPosition = pos
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "number.square")
                        .font(.system(size: 9))
                    Text(documentController.headerFooter.pageNumberPosition.rawValue)
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Page Number Placement")

            // Page Number Format Picker Menu
            Menu {
                ForEach(PageNumberFormat.allCases, id: \.self) { fmt in
                    Button(fmt.rawValue) {
                        documentController.headerFooter.pageNumberFormat = fmt
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(documentController.headerFooter.pageNumberFormat.rawValue)
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Page Number Format Style")

            // Starting Page Stepper
            HStack(spacing: 2) {
                Text("Start:")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)

                Button {
                    if documentController.headerFooter.startingPageNumber > 0 {
                        documentController.headerFooter.startingPageNumber -= 1
                    }
                } label: {
                    Text("−")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 12, height: 14)
                }
                .buttonStyle(.plain)

                Text("\(documentController.headerFooter.startingPageNumber)")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 16)

                Button {
                    documentController.headerFooter.startingPageNumber += 1
                } label: {
                    Text("+")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 12, height: 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
            .help("Starting Page Number (Offset)")

            Divider().frame(height: 14)

            // Different First Page Checkbox
            Toggle(isOn: documentController.binding(\.headerFooter.differentFirstPage)) {
                Text("Different First Page")
                    .font(.system(size: 10, weight: .medium))
            }
            .toggleStyle(.checkbox)
            .help("Hide header and footer on the title / cover page")

            Divider().frame(height: 14)

            // Insert Token Field Menu
            Menu {
                Button("Insert {page} (Current Page)") { appendHeaderFooterToken("{page}") }
                Button("Insert {pages} (Total Pages)") { appendHeaderFooterToken("{pages}") }
                Button("Insert {title} (Document Title)") { appendHeaderFooterToken("{title}") }
                Button("Insert {date} (Current Date)") { appendHeaderFooterToken("{date}") }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus.circle")
                    Text("Insert Field")
                }
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Close / Done Button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isEditingHeaderFooter = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Done")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Close Header & Footer Editor (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(StudioTheme.panelBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(StudioTheme.border),
            alignment: .bottom
        )
    }

    func appendHeaderFooterToken(_ token: String) {
        if activeHeaderFooterTarget == .header {
            documentController.headerFooter.headerRightText += (documentController.headerFooter.headerRightText.isEmpty ? "" : " ") + token
        } else {
            documentController.headerFooter.footerRightText += (documentController.headerFooter.footerRightText.isEmpty ? "" : " ") + token
        }
    }
}
