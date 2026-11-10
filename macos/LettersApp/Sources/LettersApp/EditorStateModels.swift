import SwiftUI
import AppKit
import Combine
#if canImport(LettersKit)
import LettersKit
#endif

// MARK: - Granular observation toolkit
//
// `MainEditorView` used to subscribe to the document controller, so every keystroke
// invalidated the whole editor (toolbar, sheets, notification modifiers, panes).
// The root now owns an `EditorContext` that never publishes. Each region of the UI
// opts in to exactly the state it renders:
//
//   * `Observing(_:content:)`   – subscribes one subtree to one ObservableObject.
//   * `DocumentSlice`           – republishes a small Equatable projection of the document,
//                                 so a view only refreshes when *its* fields change.
//   * `EditorCaretStore`        – selection range / text (changes on every caret move).
//   * `EditorFormatStore`       – formatting under the caret (changes only on format edits).

/// Which single pane is docked on the right-hand side of the canvas.
enum EditorRightPane: Equatable {
    case none, inspector, assistant, history, comments

    /// Toggling a pane that is already open closes it; otherwise it replaces whatever is open.
    func toggled(_ pane: EditorRightPane) -> EditorRightPane {
        self == pane ? .none : pane
    }
}

/// Selection geometry and text. Observed by the outline (cursor highlight) and the transient HUD.
@MainActor
final class EditorCaretStore: ObservableObject {
    @Published var range: NSRange = NSRange(location: 0, length: 0)
    @Published var text: String = ""
}

/// Formatting state under the caret. Observed by the top toolbar only.
@MainActor
final class EditorFormatStore: ObservableObject {
    static let defaultTextColor = Color(red: 0.10, green: 0.10, blue: 0.12)

    @Published var attributes: EditorSelectionAttributes? = nil
    @Published var textColor: Color = EditorFormatStore.defaultTextColor
    @Published var highlightColor: Color = .yellow
    /// Fallbacks used while there is no live selection snapshot.
    @Published var isBold: Bool = false
    @Published var isItalic: Bool = false
    @Published var isUnderline: Bool = false
}

/// Reference-type bag of everything the editor shell owns. It has **no** `@Published`
/// properties, so holding it in a `@StateObject` never invalidates the root view.
@MainActor
final class EditorContext: ObservableObject {
    let document = LettersDocumentController()
    let editor = EditorActionController()
    let toasts = ToastManager()
    let caret = EditorCaretStore()
    let format = EditorFormatStore()
    /// Latest linter output. Read on demand (CLI, AI context, toasts); never rendered directly.
    var lintIssues: [StyleLintMatch] = []
}

/// Subscribes a subtree to one `ObservableObject`, so the parent doesn't have to.
struct Observing<Object: ObservableObject, Content: View>: View {
    @ObservedObject private var object: Object
    private let content: (Object) -> Content

    init(_ object: Object, @ViewBuilder content: @escaping (Object) -> Content) {
        self.object = object
        self.content = content
    }

    var body: some View { content(object) }
}

/// Republishes a small projection of the document and only fires when that projection changes.
/// `objectWillChange` fires *before* the mutation lands, so the read hops to the next main-queue turn.
@MainActor
final class DocumentSlice<Value: Equatable>: ObservableObject {
    @Published private(set) var value: Value
    private var cancellable: AnyCancellable?

    init(_ document: LettersDocumentController, read: @escaping @MainActor (LettersDocumentController) -> Value) {
        value = read(document)
        cancellable = document.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak document] _ in
                MainActor.assumeIsolated {
                    guard let self, let document else { return }
                    let next = read(document)
                    if next != self.value { self.value = next }
                }
            }
    }
}

extension LettersDocumentController {
    /// A two-way binding that does not register an observation dependency by itself.
    /// Pair it with `Observing` (or an `@ObservedObject`) in the view that renders it.
    func binding<Value>(_ keyPath: ReferenceWritableKeyPath<LettersDocumentController, Value>) -> Binding<Value> {
        Binding(get: { self[keyPath: keyPath] }, set: { self[keyPath: keyPath] = $0 })
    }
}
