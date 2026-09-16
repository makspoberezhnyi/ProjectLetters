import SwiftUI
import AppKit
#if canImport(LettersKit)
import LettersKit
#endif

public struct TextKit2EditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedText: String
    @Binding var selectionRange: NSRange
    var onSelectionChanged: ((NSRange, String) -> Void)?

    public init(
        text: Binding<String>,
        selectedText: Binding<String>,
        selectionRange: Binding<NSRange>,
        onSelectionChanged: ((NSRange, String) -> Void)? = nil
    ) {
        self._text = text
        self._selectedText = selectedText
        self._selectionRange = selectionRange
        self.onSelectionChanged = onSelectionChanged
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false

        // Margin insets for a page-like canvas
        textView.textContainerInset = NSSize(width: 48, height: 48)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        context.coordinator.isInitializing = true
        textView.string = text
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        scrollView.documentView = textView

        DispatchQueue.main.async {
            context.coordinator.isInitializing = false
        }

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text && !context.coordinator.isInitializing {
            context.coordinator.isInitializing = true
            textView.string = text
            DispatchQueue.main.async {
                context.coordinator.isInitializing = false
            }
        }
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextKit2EditorView
        weak var textView: NSTextView?
        var isInitializing = false

        init(_ parent: TextKit2EditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isInitializing else { return }
            let string = textView.string
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.parent.text != string {
                    self.parent.text = string
                }
            }
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !isInitializing else { return }
            let range = textView.selectedRange()
            let nsString = textView.string as NSString
            let sub = range.length > 0 && range.location + range.length <= nsString.length ? nsString.substring(with: range) : ""

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.parent.selectionRange != range {
                    self.parent.selectionRange = range
                }
                if self.parent.selectedText != sub {
                    self.parent.selectedText = sub
                }
                self.parent.onSelectionChanged?(range, sub)
            }
        }
    }
}
