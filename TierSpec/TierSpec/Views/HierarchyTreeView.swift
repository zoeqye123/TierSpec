//
//  HierarchyTreeView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI

struct HierarchyTreeView: View {
    @ObservedObject var treeStore: TreeStore
    
    @Binding var selectedItem: TierItemDTO?
    let onAddChild: (TierItemDTO, ItemTypeDTO) -> Void
    let onDelete: (TierItemDTO) -> Void
    let onUpdateTitle: (TierItemDTO, String) -> Void
    
    var body: some View {
        List {
            if treeStore.rootItems.isEmpty {
                emptyStateView
                    .listRowSeparator(.hidden)
            } else {
                ForEach(treeStore.rootItems) { item in
                    TreeNodeView(
                        item: item,
                        loadChildren: loadChildren,
                        selectedItem: $selectedItem,
                        expandedItems: $treeStore.expandedItems,
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
    
    private func loadChildren(_ item: TierItemDTO) -> [TierItemDTO] {
        item.children
            .filter { $0.deletedAt == nil }
            .sorted { $0.position < $1.position }
    }

    private func moveRootItems(from source: IndexSet, to destination: Int) {
        guard source.count == 1, let sourceIndex = source.first else { return }
        guard sourceIndex < treeStore.rootItems.count else { return }

        let normalizedDestination = sourceIndex < destination ? destination - 1 : destination
        guard normalizedDestination >= 0, normalizedDestination < treeStore.rootItems.count else { return }
        guard normalizedDestination != sourceIndex else { return }

        let movedItem = treeStore.rootItems[sourceIndex]

        Task { @MainActor in
            await treeStore.moveNode(movedItem, from: sourceIndex, to: normalizedDestination)
        }
    }
}