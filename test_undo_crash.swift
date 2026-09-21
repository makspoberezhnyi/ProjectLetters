import SwiftUI
import AppKit

class DocumentUndoToken: NSObject {}

public class DocumentUndoHelper {
    public static func registerUndo<T>(
        for binding: Binding<T>,
        undoManager: UndoManager?,
        oldData: T,
        actionName: String? = nil,
        onChange: (() -> Void)? = nil
    ) {
        let token = DocumentUndoToken()
        
        undoManager?.registerUndo(withTarget: token) { _ in
            let current = binding.wrappedValue
            DocumentUndoHelper.registerUndo(for: binding, undoManager: undoManager, oldData: current, actionName: actionName, onChange: onChange)
            binding.wrappedValue = oldData
            onChange?()
        }
    }
}

func runTest() {
    var state = "A"
    let binding = Binding(get: { state }, set: { state = $0 })
    let um = UndoManager()
    
    let token = DocumentUndoToken()
    um.registerUndo(withTarget: token) { _ in
        print("Undo called")
        let current = binding.wrappedValue
        print("current: \(current)")
        binding.wrappedValue = "B"
    }
    
    um.undo()
    print("State is now: \(state)")
}

runTest()
