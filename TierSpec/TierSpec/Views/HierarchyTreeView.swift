//
//  HierarchyTreeView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

struct HierarchyTreeView: View {
    @Query(sort: \TierItem.position) private var allItems: [TierItem]
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selectedItem: TierItem?
    let onAddChild: (TierItem, ItemType) -> Void
    let onDelete: (TierItem) -> Void
    let onUpdateTitle: (TierItem, String) -> Void
    
    @State private var expandedItems: Set<UUID> = []
    
    private var rootItems: [TierItem] {
        allItems.filter { item in
            item.parent == nil && item.type == .capability && item.deletedAt == nil
        }.sorted { $0.position < $1.position }
    }
    
    var body: some View {
        List {
            if rootItems.isEmpty {
                emptyStateView
                    .listRowSeparator(.hidden)
            } else {
                ForEach(rootItems) { item in
                    TreeNodeView(
                        item: item,
                        loadChildren: loadChildren,
                        selectedItem: $selectedItem,
                        expandedItems: $expandedItems,
                        onAddChild: onAddChild,
                        onDelete: onDelete,
                        onUpdateTitle: onUpdateTitle
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: moveRootItems)
            }
        }
        .listStyle(.plain)
        .frame(maxHeight: .infinity)
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
        (item.children ?? [])
            .filter { $0.deletedAt == nil }
            .sorted { $0.position < $1.position }
    }

    private func moveRootItems(from source: IndexSet, to destination: Int) {
        guard source.count == 1, let sourceIndex = source.first else { return }
        guard sourceIndex < rootItems.count else { return }

        // TreeStore.moveNode root reorder path has a strict destination usage;
        // normalize move offset to a stable target index in current array bounds.
        let normalizedDestination = sourceIndex < destination ? destination - 1 : destination
        guard normalizedDestination >= 0, normalizedDestination < rootItems.count else { return }
        guard normalizedDestination != sourceIndex else { return }

        let movedItem = rootItems[sourceIndex]

        Task { @MainActor in
            let treeStore = TreeStore(modelContext: modelContext)
            await treeStore.loadTree()
            await treeStore.moveNode(movedItem, from: sourceIndex, to: normalizedDestination)
        }
    }
}

#Preview {
    HierarchyTreeView(
        selectedItem: .constant(nil),
        onAddChild: { _, _ in },
        onDelete: { _ in },
        onUpdateTitle: { _, _ in }
    )
    .modelContainer(for: TierItem.self, inMemory: true)
}
