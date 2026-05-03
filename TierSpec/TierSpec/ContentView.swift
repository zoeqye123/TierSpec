//
//  ContentView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI

struct ContentView: View {
    var projectName: String
    let mcpToolClient: MCPToolClient
    
    var body: some View {
        ContentViewWithStore(mcpToolClient: mcpToolClient, projectName: projectName)
    }
}

private struct ContentViewWithStore: View {
    @StateObject private var treeStore: TreeStore
    @State private var selectedSprint: SprintDTO?
    @State private var searchText: String = ""
    @State private var sidebarTab: SidebarTab = .hierarchy
    @State private var showingCreateSprint = false
    let projectName: String
    
    init(mcpToolClient: MCPToolClient, projectName: String) {
        _treeStore = StateObject(wrappedValue: TreeStore(mcpClient: mcpToolClient))
        self.projectName = projectName
    }
    
    private enum SidebarTab: String, CaseIterable {
        case hierarchy = "Hierarchy"
        case sprints = "Sprints"
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                tabPicker
                Divider()
                switch sidebarTab {
                case .hierarchy:
                    VStack(spacing: 0) {
                        searchField
                        Divider()
                        HierarchyTreeView(
                            treeStore: treeStore,
                            selectedItem: selectedItemBinding,
                            onAddChild: addChild,
                            onDelete: deleteItem,
                            onUpdateTitle: updateTitle
                        )
                    }
                case .sprints:
                    KanbanView(treeStore: treeStore)
                }
            }
            .frame(minWidth: 250)
            .navigationTitle(projectName)
            .toolbar {
                ToolbarItem {
                    switch sidebarTab {
                    case .hierarchy:
                        Button(action: addCapability) {
                            Label("Add Capability", systemImage: "plus")
                        }
                    case .sprints:
                        Button(action: createNewSprint) {
                            Label("New Sprint", systemImage: "plus")
                        }
                    }
                }
            }
        } detail: {
            if let selectedItem = treeStore.selectedItem {
                ItemDetailView(item: selectedItem, treeStore: treeStore)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a capability, feature, user story, or test case to inspect and edit it.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingCreateSprint) {
            SprintFormView(treeStore: treeStore)
        }
        .task {
            await treeStore.loadTree()
        }
    }
    
    @ViewBuilder
    private var tabPicker: some View {
        Picker("", selection: $sidebarTab) {
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var selectedItemBinding: Binding<TierItemDTO?> {
        Binding(
            get: { treeStore.selectedItem },
            set: { treeStore.selectedItem = $0 }
        )
    }
    
    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func addCapability() {
        let nextPosition = Double(Date().timeIntervalSince1970)
        let capability = TierItemDTO(
            id: UUID(),
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "New Capability",
            description: "Describe the business or technical capability.",
            status: .todo,
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
    
    private func createNewSprint() {
        showingCreateSprint = true
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
            status: .todo,
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
    ContentView(projectName: "My Project", mcpToolClient: MCPToolClient(clientManager: MCPClientManager()))
}