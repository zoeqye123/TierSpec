//
//  HierarchyTreeView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

struct HierarchyTreeView: View {
    @Query(sort: \TierItem.position)
    private var allItems: [TierItem]
    
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedItem: TierItem?
    
    init(selectedItem: Binding<TierItem?>) {
        self._selectedItem = selectedItem
    }
    
    private var rootItems: [TierItem] {
        allItems.filter { item in
            item.parent == nil && item.type == .capability && item.deletedAt == nil
        }
    }
    
    var body: some View {
        List {
            if rootItems.isEmpty {
                emptyStateView
            } else {
                ForEach(rootItems) { item in
                    TreeNodeView(
                        item: item,
                        loadChildren: loadChildren,
                        selectedItem: $selectedItem,
                        onAddChild: addChild,
                        onDelete: deleteItem
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Capabilities")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Add a capability to start building your hierarchy")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func loadChildren(_ item: TierItem) -> [TierItem] {
        item.outlineChildren
    }
    
    private func addChild(to parent: TierItem, type: ItemType) {
        withAnimation {
            let nextPosition = Double(parent.children?.count ?? 0)
            let child = TierItem(
                type: type,
                title: "New \(type.displayName)",
                description: nil,
                status: .requirement_input,
                position: nextPosition
            )
            child.parent = parent
            if parent.children == nil {
                parent.children = []
            }
            parent.children?.append(child)
            modelContext.insert(child)
            selectedItem = child
        }
    }
    
    private func deleteItem(_ item: TierItem) {
        withAnimation {
            item.softDelete()
            if selectedItem?.id == item.id {
                selectedItem = nil
            }
        }
    }
}

#Preview {
    HierarchyTreeView(selectedItem: .constant(nil))
        .modelContainer(for: TierItem.self, inMemory: true)
}
