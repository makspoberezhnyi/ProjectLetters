import SwiftUI
import AppKit

@MainActor
public class SmartTableViewModel: ObservableObject {
    @Published public var data: StudioTableData
    
    public init(data: StudioTableData) {
        self.data = data
    }
    
    private var activeUndoManager: UndoManager? {
        NSApp.keyWindow?.undoManager ?? NSApp.mainWindow?.undoManager
    }
    
    // Core mutation engine with Undo support
    public func performMutation(actionName: String, mutation: (inout StudioTableData) -> Void) {
        let oldData = self.data
        let um = activeUndoManager
        
        mutation(&self.data)
        
        um?.registerUndo(withTarget: self) { target in
            target.performMutation(actionName: actionName) { dataToMutate in
                dataToMutate = oldData
            }
        }
        um?.setActionName(actionName)
    }
    
    public func addRow() {
        performMutation(actionName: "Add Row") { d in
            d.rows.append(Array(repeating: "", count: d.headers.count))
        }
    }
    
    public func addColumn() {
        performMutation(actionName: "Add Column") { d in
            let colLetter = TableFormulaEvaluator.columnLetter(for: d.headers.count)
            d.headers.append("Column \(colLetter)")
            for r in 0..<d.rows.count {
                d.rows[r].append("")
            }
        }
    }
    
    public func insertRow(at index: Int) {
        performMutation(actionName: "Insert Row") { d in
            let newRow = Array(repeating: "", count: d.headers.count)
            if index == 0 {
                d.rows.insert(d.headers, at: 0)
                d.headers = newRow
            } else {
                d.rows.insert(newRow, at: max(0, min(index - 1, d.rows.count)))
            }
        }
    }
    
    public func insertColumn(at index: Int) {
        performMutation(actionName: "Insert Column") { d in
            let safeIndex = max(0, min(index, d.headers.count))
            d.headers.insert("", at: safeIndex)
            for r in 0..<d.rows.count {
                d.rows[r].insert("", at: safeIndex)
            }
        }
    }
    
    public func deleteRow(at index: Int) {
        guard data.rows.count + 1 > 1 else { return }
        performMutation(actionName: "Delete Row") { d in
            if index == 0 {
                d.headers = d.rows.removeFirst()
            } else {
                let dataRow = index - 1
                if d.rows.indices.contains(dataRow) {
                    d.rows.remove(at: dataRow)
                }
            }
        }
    }
    
    public func deleteColumn(at index: Int) {
        guard data.headers.count > 1 else { return }
        performMutation(actionName: "Delete Column") { d in
            if d.headers.indices.contains(index) {
                d.headers.remove(at: index)
                for r in 0..<d.rows.count {
                    if d.rows[r].indices.contains(index) {
                        d.rows[r].remove(at: index)
                    }
                }
            }
        }
    }
    
    public func injectReference(rowIdx: Int, colIdx: Int, activeEditingCell: String) {
        let parts = activeEditingCell.split(separator: ",")
        if parts.count == 2, let r = Int(parts[0]), let c = Int(parts[1]) {
            let activeText = getRawValue(rowIdx: r, colIdx: c)
            if activeText.hasPrefix("=") {
                let lastChar = activeText.last ?? " "
                if "+-*/(,= ".contains(lastChar) {
                    let refStr = "\(TableFormulaEvaluator.columnLetter(for: colIdx))\(rowIdx + 1)"
                    performMutation(actionName: "Insert Reference") { d in
                        if r == 0 {
                            if d.headers.indices.contains(c) {
                                d.headers[c] = activeText + refStr
                            }
                        } else {
                            let dRow = r - 1
                            if d.rows.indices.contains(dRow), d.rows[dRow].indices.contains(c) {
                                d.rows[dRow][c] = activeText + refStr
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func getRawValue(rowIdx: Int, colIdx: Int) -> String {
        if rowIdx == 0 {
            return data.headers.indices.contains(colIdx) ? data.headers[colIdx] : ""
        } else {
            let dataRow = rowIdx - 1
            if data.rows.indices.contains(dataRow), data.rows[dataRow].indices.contains(colIdx) {
                return data.rows[dataRow][colIdx]
            }
            return ""
        }
    }
    
    public func setRawValue(rowIdx: Int, colIdx: Int, val: String) {
        if rowIdx == 0 {
            if data.headers.indices.contains(colIdx) {
                data.headers[colIdx] = val
            }
        } else {
            let dataRow = rowIdx - 1
            if data.rows.indices.contains(dataRow) {
                while data.rows[dataRow].count <= colIdx {
                    data.rows[dataRow].append("")
                }
                data.rows[dataRow][colIdx] = val
            }
        }
    }
}
