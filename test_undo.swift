import Foundation
import SwiftUI

class TableUndoTarget: NSObject {
    var onUndo: ((String) -> Void)?
    
    @objc func performUndo(_ val: NSString) {
        onUndo?(val as String)
    }
}
