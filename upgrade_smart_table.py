import re
import sys

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "r") as f:
    code = f.read()

# 1. Add extrapolateFormula
evaluator_pattern = r'public static func parseRangeReference\(\_ rangeStr: String\) -> \[\(col: Int, row: Int\)\] \{'
extrapolate_code = '''public static func extrapolateFormula(_ formula: String, rowOffset: Int, colOffset: Int) -> String {
        let pattern = "([A-Za-z]+)([0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return formula }
        let nsString = formula as NSString
        let matches = regex.matches(in: formula, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var result = formula
        for match in matches.reversed() {
            let colStr = nsString.substring(with: match.range(at: 1))
            let rowStr = nsString.substring(with: match.range(at: 2))
            
            if let colIdx = columnIndex(for: colStr), let rowNum = Int(rowStr) {
                let newCol = max(0, colIdx + colOffset)
                let newRow = max(1, rowNum + rowOffset)
                let newRef = "\(columnLetter(for: newCol))\(newRow)"
                result = (result as NSString).replacingCharacters(in: match.range, with: newRef)
            }
        }
        return result
    }
    
    public static func parseRangeReference(_ rangeStr: String) -> [(col: Int, row: Int)] {'''
code = code.replace('public static func parseRangeReference(_ rangeStr: String) -> [(col: Int, row: Int)] {', extrapolate_code)

# 2. Add TableSelectionRect struct and state
state_code = '''    @FocusState private var activeEditingCell: String?
    
    public struct TableSelectionRect: Equatable {
        public var minRow: Int
        public var maxRow: Int
        public var minCol: Int
        public var maxCol: Int
        public func contains(row: Int, col: Int) -> Bool {
            return row >= minRow && row <= maxRow && col >= minCol && col <= maxCol
        }
    }
    
    @State private var selectionStart: (row: Int, col: Int)? = nil
    @State private var selectedRect: TableSelectionRect? = nil
    @State private var fillTargetRect: TableSelectionRect? = nil
'''
code = code.replace('    @FocusState private var activeEditingCell: String?', state_code)

# 3. Update handleCellTap
handle_tap_search = '''    private func handleCellTap(rowIdx: Int, colIdx: Int, cellKey: String) {
        if let active = activeEditingCell, active != cellKey {'''

handle_tap_replace = '''    private func handleCellTap(rowIdx: Int, colIdx: Int, cellKey: String) {
        if NSEvent.modifierFlags.contains(.shift), let start = selectionStart {
            selectedRect = TableSelectionRect(
                minRow: min(start.row, rowIdx), maxRow: max(start.row, rowIdx),
                minCol: min(start.col, colIdx), maxCol: max(start.col, colIdx)
            )
            activeEditingCell = nil
            return
        }
        
        selectionStart = (row: rowIdx, col: colIdx)
        selectedRect = TableSelectionRect(minRow: rowIdx, maxRow: rowIdx, minCol: colIdx, maxCol: colIdx)

        if let active = activeEditingCell, active != cellKey {'''
code = code.replace(handle_tap_search, handle_tap_replace)

# 4. Modify Grid Borders
# Header right border
code = code.replace('''                            ZStack(alignment: .trailing) {
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundColor(Color.primary.opacity(0.1))''', '''                            ZStack(alignment: .trailing) {
                                if colIdx < tableData.headers.count - 1 {
                                    Rectangle()
                                        .frame(width: 1)
                                        .foregroundColor(Color.primary.opacity(0.1))
                                }''')

# Data Row bottom border
bottom_border_search = '''.overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.primary.opacity(0.1)),
                alignment: .bottom
            )'''

bottom_border_replace = '''// Dynamic bottom overlay
                .overlay(
                    Group {
                        if rowIdx < gridCount - 1 {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color.primary.opacity(0.1))
                        }
                    },
                    alignment: .bottom
                )'''
# we only want to replace the SECOND occurrence (the one in the data rows), or we can replace both.
# Let's replace the one in Data Rows, which is inside `ForEach(0..<gridCount, id: \.self) { rowIdx in` block.
# Actually, the header one is exactly the same, let's just replace all of them. But `rowIdx` is not defined in the header!
# Wait, the header has:
# .overlay(
#     Rectangle()
#         .frame(height: 1)
#         .foregroundColor(Color.primary.opacity(0.1)),
#     alignment: .bottom
# )
# In the header, it's just drawn unconditionally. In the data rows, we want `if rowIdx < gridCount - 1`.
# Let's be precise.
parts = code.split(bottom_border_search)
if len(parts) >= 3:
    # 0 is before header, 1 is between header and rows, 2 is after rows
    code = parts[0] + bottom_border_search + parts[1] + bottom_border_replace + parts[2]

# Data cell right border
right_border_search = '''.overlay(
            Rectangle()
                .frame(width: 1)

                .foregroundColor(Color.primary.opacity(0.1)),
            alignment: .trailing
        )'''
right_border_replace = '''.overlay(
            Group {
                if colIdx < tableData.headers.count - 1 {
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(Color.primary.opacity(0.1))
                }
            },
            alignment: .trailing
        )'''
code = code.replace(right_border_search, right_border_replace)


# 5. Add UI logic to dataCellView
datacell_search = '''        let cellKey = "\\(rowIdx),\\(colIdx)"
        let isEditing = activeEditingCell == cellKey'''

datacell_replace = '''        let cellKey = "\(rowIdx),\(colIdx)"
        let isEditing = activeEditingCell == cellKey
        let isSelected = selectedRect?.contains(row: rowIdx, col: colIdx) ?? false
        let isFillTarget = fillTargetRect?.contains(row: rowIdx, col: colIdx) ?? false
        let isBottomRight = (selectedRect?.maxRow == rowIdx && selectedRect?.maxCol == colIdx) && activeEditingCell == nil
        
        let showTopBorder = isSelected && rowIdx == selectedRect!.minRow
        let showBottomBorder = isSelected && rowIdx == selectedRect!.maxRow
        let showLeftBorder = isSelected && colIdx == selectedRect!.minCol
        let showRightBorder = isSelected && colIdx == selectedRect!.maxCol'''

code = code.replace(datacell_search, datacell_replace)

# Now inject the background and overlay at the end of dataCellView.
# Find: .padding(.vertical, 6)
# It's at the end of dataCellView ZStack
datacell_end_search = '''        }
        .padding(.horizontal, 6)

        .padding(.vertical, 6)'''
        
datacell_end_replace = '''        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background((isSelected || isFillTarget) ? Color.accentColor.opacity(0.15) : Color.clear)
        .overlay(
            ZStack {
                if showTopBorder { Rectangle().frame(height: 2).foregroundColor(.accentColor).frame(maxHeight: .infinity, alignment: .top) }
                if showBottomBorder { Rectangle().frame(height: 2).foregroundColor(.accentColor).frame(maxHeight: .infinity, alignment: .bottom) }
                if showLeftBorder { Rectangle().frame(width: 2).foregroundColor(.accentColor).frame(maxWidth: .infinity, alignment: .leading) }
                if showRightBorder { Rectangle().frame(width: 2).foregroundColor(.accentColor).frame(maxWidth: .infinity, alignment: .trailing) }
                
                if isBottomRight {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: 3, y: 3)
                        .onHover { isHovered in
                            if isHovered { NSCursor.crosshair.push() } else { NSCursor.pop() }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let avgCellHeight: CGFloat = 24.0
                                    let avgCellWidth: CGFloat = 80.0
                                    let dRows = Int(round(val.translation.height / avgCellHeight))
                                    let dCols = Int(round(val.translation.width / avgCellWidth))
                                    
                                    if abs(dRows) > abs(dCols) {
                                        let newMaxRow = max(selectedRect!.maxRow, min(tableData.rows.count - 1, selectedRect!.maxRow + dRows))
                                        fillTargetRect = TableSelectionRect(minRow: selectedRect!.minRow, maxRow: newMaxRow, minCol: selectedRect!.minCol, maxCol: selectedRect!.maxCol)
                                    } else {
                                        let newMaxCol = max(selectedRect!.maxCol, min(tableData.headers.count - 1, selectedRect!.maxCol + dCols))
                                        fillTargetRect = TableSelectionRect(minRow: selectedRect!.minRow, maxRow: selectedRect!.maxRow, minCol: selectedRect!.minCol, maxCol: newMaxCol)
                                    }
                                }
                                .onEnded { _ in
                                    executeFillTarget()
                                }
                        )
                }
            }
        )'''
code = code.replace(datacell_end_search, datacell_end_replace)

# 6. Add executeFillTarget
fill_target_code = '''    private func executeFillTarget() {
        guard let sel = selectedRect, let target = fillTargetRect else { return }
        
        store.mutateTable(id: tableId, actionName: "Auto-Fill") { data in
            for r in target.minRow...target.maxRow {
                for c in target.minCol...target.maxCol {
                    if sel.contains(row: r, col: c) { continue }
                    
                    let sourceR = sel.minRow + ((r - sel.minRow) % (sel.maxRow - sel.minRow + 1))
                    let sourceC = sel.minCol + ((c - sel.minCol) % (sel.maxCol - sel.minCol + 1))
                    
                    let rowOffset = r - sourceR
                    let colOffset = c - sourceC
                    
                    let sourceVal = data.cells[sourceR][sourceC].rawValue
                    if sourceVal.hasPrefix("=") {
                        let newVal = TableFormulaEvaluator.extrapolateFormula(sourceVal, rowOffset: rowOffset, colOffset: colOffset)
                        data.cells[r][sourceC].rawValue = newVal
                    } else {
                        data.cells[r][sourceC].rawValue = sourceVal
                    }
                }
            }
        }
        
        selectedRect = target
        fillTargetRect = nil
    }
'''
code = code.replace('private func getTableFont', fill_target_code + '\n    private func getTableFont')

with open("macos/LettersApp/Sources/LettersApp/SmartTableView.swift", "w") as f:
    f.write(code)
print("SmartTableView successfully generated")
