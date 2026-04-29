//
//  ContentView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ContentViewWithStore(modelContext: modelContext)
    }
}

private struct ContentViewWithStore: View {
    @StateObject private var treeStore: TreeStore
    @State private var selectedSprint: Sprint?
    @State private var searchText: String = ""
    @State private var sidebarTab: SidebarTab = .hierarchy
    
    init(modelContext: ModelContext) {
        _treeStore = StateObject(wrappedValue: TreeStore(modelContext: modelContext))
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
                            selectedItem: selectedItemBinding,
                            onAddChild: addChild,
                            onDelete: deleteItem,
                            onUpdateTitle: updateTitle
                        )
                    }
                case .sprints:
                    SprintListView()
                }
            }
            .frame(minWidth: 250)
            .navigationTitle("TierSpec")
            .toolbar {
                ToolbarItem {
                    Button(action: addCapability) {
                        Label("Add Capability", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let selectedItem = treeStore.selectedItem {
                ItemDetailView(item: selectedItem)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a capability, feature, user story, or test case to inspect and edit it.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
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

    private var selectedItemBinding: Binding<TierItem?> {
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
        let capability = TierItem(
            type: .capability,
            title: "New Capability",
            description: "Describe the business or technical capability.",
            status: .todo,
            position: nextPosition
        )
        
        Task {
            await treeStore.createItem(capability)
            withAnimation {
                treeStore.selectedItem = capability
            }
        }
    }
    
    private func addChild(to parent: TierItem, type: ItemType) {
        let nextPosition = Double(parent.children?.count ?? 0)
        let child = TierItem(
            type: type,
            title: "New \(type.displayName)",
            description: nil,
            status: .todo,
            position: nextPosition
        )
        
        Task {
            await treeStore.createItem(child, parent: parent)
            withAnimation {
                treeStore.selectedItem = child
            }
        }
    }
    
    private func deleteItem(_ item: TierItem) {
        Task {
            await treeStore.deleteItem(item)
            withAnimation {
                if treeStore.selectedItem?.id == item.id {
                    treeStore.selectedItem = nil
                }
            }
        }
    }
    
    private func updateTitle(_ item: TierItem, _ newTitle: String) {
        item.title = newTitle
        Task {
            await treeStore.updateItem(item)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TierItem.self, inMemory: true)
}
