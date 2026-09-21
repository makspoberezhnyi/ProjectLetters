import SwiftUI
import AppKit

@MainActor
public class StudioBlockStore: ObservableObject {
    @Published public var tables: [StudioTableData]
    @Published public var images: [StudioImageBlock]
    @Published public var videos: [StudioVideoBlock]
    
    public init(
        tables: [StudioTableData] = [],
        images: [StudioImageBlock] = [],
        videos: [StudioVideoBlock] = []
    ) {
        self.tables = tables
        self.images = images
        self.videos = videos
    }
    
    private var activeUndoManager: UndoManager? {
        NSApp.keyWindow?.undoManager ?? NSApp.mainWindow?.undoManager
    }
    
    // MARK: - Tables
    
    public func mutateTable(at index: Int, actionName: String? = nil, mutation: (inout StudioTableData) -> Void) {
        guard tables.indices.contains(index) else { return }
        let oldData = tables[index]
        let um = activeUndoManager
        
        mutation(&tables[index])
        
        if let actionName = actionName {
            um?.registerUndo(withTarget: self) { target in
                target.mutateTable(at: index, actionName: actionName) { data in
                    data = oldData
                }
            }
            um?.setActionName(actionName)
        }
    }
    
    public func addTable(_ table: StudioTableData) {
        let um = activeUndoManager
        um?.registerUndo(withTarget: self) { target in
            target.removeTable(id: table.id)
        }
        um?.setActionName("Insert Table")
        tables.append(table)
    }
    
    public func removeTable(id: UUID) {
        guard let index = tables.firstIndex(where: { $0.id == id }) else { return }
        let table = tables[index]
        let um = activeUndoManager
        
        um?.registerUndo(withTarget: self) { target in
            target.insertTable(table, at: index)
        }
        um?.setActionName("Delete Table")
        tables.remove(at: index)
    }
    
    public func insertTable(_ table: StudioTableData, at index: Int) {
        let um = activeUndoManager
        um?.registerUndo(withTarget: self) { target in
            target.removeTable(id: table.id)
        }
        um?.setActionName("Insert Table")
        tables.insert(table, at: index)
    }
}

    public func mutateTable(id: UUID, actionName: String? = nil, mutation: (inout StudioTableData) -> Void) {
        guard let index = tables.firstIndex(where: { $0.id == id }) else { return }
        mutateTable(at: index, actionName: actionName, mutation: mutation)
    }
