//
//  MainView.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/1.
//

import SwiftUI

/// Modern 3-column NavigationSplitView layout for TierSpec
/// Column 1: Hierarchy Tree (280px) | Column 2: Main Content (adaptive) | Column 3: Details Panel (320px)
struct MainView: View {
    let mcpToolClient: MCPToolClient
    let projectName: String
    
    var body: some View {
        MainViewWithStore(mcpToolClient: mcpToolClient, projectName: projectName)
    }
}

private struct MainViewWithStore: View {
    @StateObject private var treeStore: TreeStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    let projectName: String
    
    init(mcpToolClient: MCPToolClient, projectName: String) {
        _treeStore = StateObject(wrappedValue: TreeStore(mcpClient: mcpToolClient))
        self.projectName = projectName
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Column 1: Hierarchy Tree (280px)
            HierarchyTreeView(
                selectedItem: selectedItemBinding,
                onAddChild: addChild,
                onDelete: deleteItem,
                onUpdateTitle: updateTitle,
                treeStore: treeStore
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
            .navigationTitle(projectName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addCapability) {
                        Label("Add Capability", systemImage: "plus")
                    }
                }
            }
            
        } content: {
            // Column 2: Main Content (adaptive)
            if let item = treeStore.selectedItem {
                ItemDetailView(item: item, treeStore: treeStore)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a capability, feature, user story, or test case from the hierarchy")
                )
            }
            
        } detail: {
            // Column 3: Details Panel (320px)
            if let item = treeStore.selectedItem {
                ItemPropertiesPanel(item: item, treeStore: treeStore)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 500)
            } else {
                ContentUnavailableView(
                    "No Details",
                    systemImage: "info.circle",
                    description: Text("Select an item to view its properties and metadata")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { columnVisibility = .all }) {
                    Label("Show All Columns", systemImage: "sidebar.left")
                }
            }
        }
        .task {
            await treeStore.loadTree()
        }
    }
    
    // MARK: - Bindings
    
    private var selectedItemBinding: Binding<TierItemDTO?> {
        Binding(
            get: { treeStore.selectedItem },
            set: { treeStore.selectedItem = $0 }
        )
    }
    
    // MARK: - Actions
    
    private func addCapability() {
        let nextPosition = Double(Date().timeIntervalSince1970)
        let capability = TierItemDTO(
            id: UUID(),
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "New Capability",
            description: "Describe the business or technical capability.",
            status: .backlog,
            priority: 0,
            position: nextPosition,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
        
        Task {
            await treeStore.createItem(capability)
            withAnimation {
                treeStore.selectedItem = capability
            }
        }
    }
    
    private func addChild(to parent: TierItemDTO, type: ItemTypeDTO) {
        let nextPosition = Double(parent.children.count)
        let child = TierItemDTO(
            id: UUID(),
            type: type,
            parentId: parent.id,
            sprintId: nil,
            title: "New \(type.displayName)",
            description: nil,
            status: .backlog,
            priority: 0,
            position: nextPosition,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
        
        Task {
            await treeStore.createItem(child, parent: parent)
            withAnimation {
                treeStore.selectedItem = child
            }
        }
    }
    
    private func deleteItem(_ item: TierItemDTO) {
        Task {
            await treeStore.deleteItem(item)
            withAnimation {
                if treeStore.selectedItem?.id == item.id {
                    treeStore.selectedItem = nil
                }
            }
        }
    }
    
    private func updateTitle(_ item: TierItemDTO, _ newTitle: String) {
        var updatedItem = item
        updatedItem.title = newTitle
        updatedItem.updatedAt = Date()
        Task {
            await treeStore.updateItem(updatedItem)
        }
    }
}

#Preview {
    MainView(
        mcpToolClient: MCPToolClient(clientManager: MCPClientManager()),
        projectName: "TierSpec Project"
    )
}
