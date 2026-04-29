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
    @Binding var expandedItems: Set<UUID>
    
    let onAddChild: (TierItem, ItemType) -> Void
    let onDelete: (TierItem) -> Void
    let onUpdateTitle: (TierItem, String) -> Void
    
    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editedTitle: String = ""
    @FocusState private var editFocus: Bool
    
    private var isExpanded: Bool {
        expandedItems.contains(item.id)
    }
    
    private var children: [TierItem] {
        isExpanded ? loadChildren(item) : []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nodeRow
            
            if isExpanded && !children.isEmpty {
                ForEach(children) { child in
                    TreeNodeView(
                        item: child,
                        loadChildren: loadChildren,
                        selectedItem: $selectedItem,
                        expandedItems: $expandedItems,
                        onAddChild: onAddChild,
                        onDelete: onDelete,
                        onUpdateTitle: onUpdateTitle
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var nodeRow: some View {
        HStack(spacing: 6) {
            expandButton
            
            Image(systemName: item.type.icon)
                .font(.system(size: 12))
                .foregroundStyle(typeColor)
                .frame(width: 16)
            
            if isEditing {
                TextField("", text: $editedTitle)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .onSubmit {
                        saveEdit()
                    }
                    .onExitCommand {
                        cancelEdit()
                    }
                    .focused($editFocus)
            } else {
                Text(item.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture(count: 2) {
                        startEditing()
                    }
            }
            
            Spacer()
            
            if item.canHaveChildren {
                addButton
            }
            
            deleteButton
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .padding(.leading, CGFloat(item.depth) * 16)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.secondary.opacity(0.08) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = item
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            if item.canHaveChildren {
                ForEach(item.type.allowedChildTypes, id: \.self) { childType in
                    Button {
                        onAddChild(item, childType)
                    } label: {
                        Label("Add \(childType.displayName)", systemImage: childType.icon)
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
    
    @ViewBuilder
    private var expandButton: some View {
        if item.canHaveChildren {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isExpanded {
                        expandedItems.remove(item.id)
                    } else {
                        expandedItems.insert(item.id)
                    }
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
        } else {
            Spacer().frame(width: 16)
        }
    }
    
    @ViewBuilder
    private var addButton: some View {
        Menu {
            ForEach(item.type.allowedChildTypes, id: \.self) { childType in
                Button {
                    onAddChild(item, childType)
                } label: {
                    Label(childType.displayName, systemImage: childType.icon)
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        Button {
            onDelete(item)
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 10))
                .foregroundStyle(.red.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
    
    private var isSelected: Bool {
        selectedItem?.id == item.id
    }
    
    private var typeColor: Color {
        switch item.type {
        case .capability:
            return .blue
        case .feature:
            return .green
        case .user_story:
            return .orange
        case .test_case:
            return .purple
        }
    }
    
    private func startEditing() {
        editedTitle = item.title
        isEditing = true
        editFocus = true
    }
    
    private func saveEdit() {
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty && trimmedTitle != item.title {
            onUpdateTitle(item, trimmedTitle)
        }
        isEditing = false
        editFocus = false
    }
    
    private func cancelEdit() {
        isEditing = false
        editFocus = false
    }
}

extension TreeNodeView {
    static func makeSampleItem(
        type: ItemType,
        title: String,
        status: ItemStatus = .todo,
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