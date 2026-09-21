import Foundation

class DummyUndo {
    let um = UndoManager()
    
    func test() {
        let target = NSObject()
        um.registerUndo(withTarget: target) { t in
            print("Undo triggered")
        }
    }
}
