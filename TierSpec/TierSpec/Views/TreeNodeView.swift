//
//  TreeNodeView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI

/// A single node in the hierarchy tree with lazy-loaded children
struct TreeNodeView: View {
    // MARK: - Properties
    
    /// The item to display
    let item: TierItem
    
    /// Closure to fetch children lazily
    let loadChildren: (TierItem) -> [TierItem]
    
    /// Currently selected item
    @Binding var selectedItem: TierItem?
    
    /// Local expansion state
    @State private var isExpanded: Bool = false
    
    /// Cached children (loaded lazily)
    @State private var children: [TierItem] = []
    
    /// Whether children have been loaded
    @State private var childrenLoaded: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        if item.canHaveChildren {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    if childrenLoaded {
                        ForEach(children) { child in
                            TreeNodeView(
                                item: child,
                                loadChildren: loadChildren,
                                selectedItem: $selectedItem
                            )
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(0.5)
                            .padding(.leading, 20)
                    }
                },
                label: {
                    nodeLabel
                }
            )
            .onChange(of: isExpanded) { _, newValue in
                if newValue && !childrenLoaded {
                    loadChildrenLazy()
                }
            }
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
    
    // MARK: - Lazy Loading
    
    private func loadChildrenLazy() {
        print("[TreeNodeView] Lazy loading children for: \(item.title)")
        children = loadChildren(item)
        childrenLoaded = true
        print("[TreeNodeView] Loaded \(children.count) children")
    }
}

// MARK: - Preview Data Helper

extension TreeNodeView {
    /// Create a sample item for previews
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
