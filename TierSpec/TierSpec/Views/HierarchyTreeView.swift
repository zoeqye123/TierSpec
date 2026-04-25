//
//  HierarchyTreeView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

/// A lazy-loading hierarchical tree view for TierSpec items
struct HierarchyTreeView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<TierItem> { $0.parent == nil && $0.type == .capability },
        sort: \TierItem.position
    )
    private var rootItems: [TierItem]
    
    @State private var selectedItem: TierItem?
    @State private var expandedItemIDs: Set<UUID> = []
    
    var body: some View {
        List {
            if rootItems.isEmpty {
                emptyStateView
            } else {
                ForEach(rootItems) { item in
                    TreeNodeView(
                        item: item,
                        loadChildren: loadChildren,
                        selectedItem: $selectedItem
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
        print("[HierarchyTreeView] Loading children for: \(item.title) (type: \(item.type.displayName))")
        let children = item.outlineChildren
        print("[HierarchyTreeView] Found \(children.count) children")
        return children
    }
}

// MARK: - Preview

#Preview {
    HierarchyTreeView()
        .modelContainer(for: TierItem.self, inMemory: true)
}