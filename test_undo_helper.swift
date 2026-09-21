import SwiftUI

class TableUndoHelper {
    static func registerUndo(
        for binding: Binding<Int>,
        undoManager: UndoManager?,
        oldData: Int,
        onChange: (() -> Void)?
    ) {
        class UndoToken: NSObject {}
        let token = UndoToken()
        
        undoManager?.registerUndo(withTarget: token) { _ in
            let current = binding.wrappedValue
            TableUndoHelper.registerUndo(for: binding, undoManager: undoManager, oldData: current, onChange: onChange)
            binding.wrappedValue = oldData
            onChange?()
        }
    }
}
