//
//  TreeStore.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import Foundation
import SwiftData
import Combine

/// Observable store for tree UI state management
@MainActor
final class TreeStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var rootItems: [TierItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    // MARK: - Private Properties
    
    private let repository: ItemRepository
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.repository = ItemRepository(modelContext: modelContext)
    }
    
    // MARK: - Tree Loading
    
    /// Load the entire tree from the repository
    func loadTree() async {
        isLoading = true
        error = nil
        
        do {
            rootItems = try await repository.fetchRoot()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Refresh a specific node and its children
    func refreshNode(_ item: TierItem) async {
        do {
            if item.isRoot {
                rootItems = try await repository.fetchRoot()
            } else if let parent = item.parent {
                _ = try await repository.fetchChildren(of: parent)
            }
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Node Operations
    
    /// Move a node to a new parent
    func moveNode(_ item: TierItem, to newParent: TierItem?) async {
        do {
            try await repository.move(item, to: newParent)
            await loadTree()
        } catch {
            self.error = error
        }
    }
    
    /// Move a node within the same parent (reorder)
    func moveNode(_ item: TierItem, from sourceIndex: Int, to destinationIndex: Int) async {
        guard let parent = item.parent else {
            await moveRootNode(item, from: sourceIndex, to: destinationIndex)
            return
        }
        
        do {
            try await repository.reorderChildren(of: parent, from: sourceIndex, to: destinationIndex)
            await loadTree()
        } catch {
            self.error = error
        }
    }
    
    private func moveRootNode(_ item: TierItem, from sourceIndex: Int, to destinationIndex: Int) async {
        guard sourceIndex < rootItems.count, destinationIndex <= rootItems.count else { return }
        
        var items = rootItems
        let movedItem = items.remove(at: sourceIndex)
        let clampedDestination = min(destinationIndex, items.count)
        items.insert(movedItem, at: clampedDestination)
        
        for (index, item) in items.enumerated() {
            item.position = Double(index)
            item.touch()
        }
        
        do {
            try await repository.update(items[destinationIndex])
            rootItems = items.sorted { $0.position < $1.position }
        } catch {
            self.error = error
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new item
    func createItem(_ item: TierItem, parent: TierItem? = nil) async {
        do {
            if let parent = parent {
                try await repository.create(item, parent: parent)
            } else {
                try await repository.create(item)
            }
            await loadTree()
        } catch {
            self.error = error
        }
    }
    
    /// Update an existing item
    func updateItem(_ item: TierItem) async {
        do {
            try await repository.update(item)
            await loadTree()
        } catch {
            self.error = error
        }
    }
    
    /// Delete an item (soft delete)
    func deleteItem(_ item: TierItem) async {
        do {
            try await repository.delete(item)
            await loadTree()
        } catch {
            self.error = error
        }
    }
    
    /// Restore a deleted item
    func restoreItem(_ item: TierItem) async {
        do {
            try await repository.restore(item)
            await loadTree()
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Query Operations
    
    /// Search for items
    func search(query: String) async -> [TierItem] {
        do {
            return try await repository.search(query: query)
        } catch {
            self.error = error
            return []
        }
    }
    
    /// Fetch children of an item
    func fetchChildren(of item: TierItem) async -> [TierItem] {
        do {
            return try await repository.fetchChildren(of: item)
        } catch {
            self.error = error
            return []
        }
    }
    
    // MARK: - Selection State
    
    @Published var selectedItem: TierItem?
    @Published var expandedItems: Set<UUID> = []
    
    /// Toggle expansion state of an item
    func toggleExpansion(_ item: TierItem) {
        if expandedItems.contains(item.id) {
            expandedItems.remove(item.id)
        } else {
            expandedItems.insert(item.id)
        }
    }
    
    /// Expand all items in the tree
    func expandAll() {
        var allIds = Set<UUID>()
        for root in rootItems {
            collectAllIds(root, into: &allIds)
        }
        expandedItems = allIds
    }
    
    /// Collapse all items in the tree
    func collapseAll() {
        expandedItems.removeAll()
    }
    
    private func collectAllIds(_ item: TierItem, into set: inout Set<UUID>) {
        set.insert(item.id)
        for child in item.outlineChildren {
            collectAllIds(child, into: &set)
        }
    }
    
    // MARK: - Utility
    
    /// Clear any error
    func clearError() {
        error = nil
    }
}
