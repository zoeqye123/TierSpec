//
//  TreeNodeView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI

struct TreeNodeView: View {
    let item: TierItem
    let loadChildren: (TierItem) -> [TierItem]
    @Binding var selectedItem: TierItem?
    
    let onAddChild: (TierItem, ItemType) -> Void
    let onDelete: (TierItem) -> Void
    
    @State private var isExpanded: Bool = false
    @State private var showAddMenu: Bool = false

    private var loadedChildren: [TierItem] {
        isExpanded ? loadChildren(item) : []
    }
    
    var body: some View {
        if item.canHaveChildren {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    if isExpanded {
                        ForEach(loadedChildren) { child in
                            TreeNodeView(
                                item: child,
                                loadChildren: loadChildren,
                                selectedItem: $selectedItem,
                                onAddChild: onAddChild,
                                onDelete: onDelete
                            )
                        }
                    }
                },
                label: {
                    nodeLabel
                }
            )
        } else {
            nodeLabel
        }
    }
    
    // MARK: - Node Label
    
    @ViewBuilder
    private var nodeLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: item.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(typeColor)
                .frame(width: 20)
            
            Text(item.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            statusBadge
            
            if item.aiGenerated {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = item
        }
        .contextMenu {
            if item.canHaveChildren {
                Menu("Add Child") {
                    ForEach(item.type.allowedChildTypes, id: \.self) { childType in
                        Button {
                            onAddChild(item, childType)
                        } label: {
                            Label(childType.displayName, systemImage: childType.icon)
                        }
                    }
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(item.status.color)
                .frame(width: 6, height: 6)
            
            Text(item.status.displayName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(item.status.color.opacity(0.15))
        )
    }
    
    // MARK: - Computed Properties
    
    private var isSelected: Bool {
        selectedItem?.id == item.id
    }
    
    private var typeColor: Color {
        switch item.type {
        case .capability:
            return .blue
        case .feature:
            return .purple
        case .epic:
            return .orange
        case .business_story:
            return .green
        case .technical_story:
            return .mint
        case .test_case:
            return .cyan
        }
    }
}

extension TreeNodeView {
    static func makeSampleItem(
        type: ItemType,
        title: String,
        status: ItemStatus = .backlog,
        children: [TierItem] = []
    ) -> TierItem {
        let item = TierItem(
            type: type,
            title: title,
            status: status
        )
        item.children = children
        return item
    }
}
