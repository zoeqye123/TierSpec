//
//  TreeStore.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import Foundation
import Combine

/// Observable store for tree UI state management
@MainActor
final class TreeStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var rootItems: [TierItemDTO] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    // MARK: - Private Properties
    
    private let repository: ItemRepository
    private var cancellables = Set<AnyCancellable>()
    
    /// The MCP client used for communication with the server
    var mcpClient: MCPToolClient {
        repository.mcpClient
    }
    
    // MARK: - Initialization
    
    init(mcpClient: MCPToolClient) {
        self.repository = ItemRepository(mcpClient: mcpClient)
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
    func refreshNode(_ item: TierItemDTO) async {
        do {
            if item.parentId == nil {
                rootItems = try await repository.fetchRoot()
            } else if let parentId = item.parentId {
                // Fetch parent to refresh its children
                if let parent = try await repository.fetch(byId: parentId) {
                    _ = try await repository.fetchChildren(of: parent)
                }
            }
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Node Operations
    
    /// Move a node to a new parent
    func moveNode(_ item: TierItemDTO, to newParent: TierItemDTO?) async {
        let oldParentId = item.parentId
        
        do {
            try await repository.move(item, to: newParent)
            
            // Incremental update: refresh both old and new parent subtrees
            if let oldParentId = oldParentId {
                if let oldParent = try await repository.fetch(byId: oldParentId) {
                    await refreshNode(oldParent)
                }
            } else {
                rootItems = try await repository.fetchRoot()
            }
            
            if let newParent = newParent, newParent.id != oldParentId {
                await refreshNode(newParent)
            } else if newParent == nil && oldParentId != nil {
                rootItems = try await repository.fetchRoot()
            }
        } catch {
            self.error = error
        }
    }
    
    /// Move a node within the same parent (reorder)
    func moveNode(_ item: TierItemDTO, from sourceIndex: Int, to destinationIndex: Int) async {
        guard let parentId = item.parentId else {
            await moveRootNode(item, from: sourceIndex, to: destinationIndex)
            return
        }
        
        do {
            if let parent = try await repository.fetch(byId: parentId) {
                try await repository.reorderChildren(of: parent, from: sourceIndex, to: destinationIndex)
                // Incremental update: only refresh parent's children
                await refreshNode(parent)
            }
        } catch {
            self.error = error
        }
    }
    
    private func moveRootNode(_ item: TierItemDTO, from sourceIndex: Int, to destinationIndex: Int) async {
        guard sourceIndex < rootItems.count, destinationIndex <= rootItems.count else { return }
        
        var items = rootItems
        let movedItem = items.remove(at: sourceIndex)
        let clampedDestination = min(destinationIndex, items.count)
        items.insert(movedItem, at: clampedDestination)
        
        // Update positions via repository
        do {
            for (index, var item) in items.enumerated() {
                item.position = Double(index)
                _ = try await repository.update(item)
            }
            rootItems = items.sorted { $0.position < $1.position }
        } catch {
            self.error = error
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new item
    func createItem(_ item: TierItemDTO, parent: TierItemDTO? = nil) async {
        do {
            if let parent = parent {
                _ = try await repository.create(item, parentId: parent.id)
            } else {
                _ = try await repository.create(item)
            }
            // Incremental update: only refresh affected subtree
            if let parent = parent {
                await refreshNode(parent)
            } else {
                // New root item - refresh root list only
                rootItems = try await repository.fetchRoot()
            }
        } catch {
            self.error = error
        }
    }
    
    /// Update an existing item
    func updateItem(_ item: TierItemDTO) async {
        do {
            _ = try await repository.update(item)
            // No tree structure change - no refresh needed
            // Views will update via @Published
        } catch {
            self.error = error
        }
    }
    
    /// Delete an item (soft delete)
    func deleteItem(_ item: TierItemDTO) async {
        do {
            try await repository.delete(item)
            // Incremental update: refresh parent's children
            if let parentId = item.parentId {
                if let parent = try await repository.fetch(byId: parentId) {
                    await refreshNode(parent)
                }
            } else {
                // Root item deleted - refresh root list
                rootItems = try await repository.fetchRoot()
            }
        } catch {
            self.error = error
        }
    }
    
    /// Restore a deleted item
    func restoreItem(_ item: TierItemDTO) async {
        do {
            _ = try await repository.restore(item)
            // Incremental update: refresh parent's children
            if let parentId = item.parentId {
                if let parent = try await repository.fetch(byId: parentId) {
                    await refreshNode(parent)
                }
            } else {
                // Root item restored - refresh root list
                rootItems = try await repository.fetchRoot()
            }
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Query Operations
    
    /// Search for items
    func search(query: String) async -> [TierItemDTO] {
        do {
            return try await repository.search(query: query)
        } catch {
            self.error = error
            return []
        }
    }
    
    /// Fetch children of an item
    func fetchChildren(of item: TierItemDTO) async -> [TierItemDTO] {
        do {
            return try await repository.fetchChildren(of: item)
        } catch {
            self.error = error
            return []
        }
    }
    
    // MARK: - Selection State
    
    @Published var selectedItem: TierItemDTO?
    @Published var expandedItems: Set<UUID> = []
    
    /// Toggle expansion state of an item
    func toggleExpansion(_ item: TierItemDTO) {
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
    
    private func collectAllIds(_ item: TierItemDTO, into set: inout Set<UUID>) {
        set.insert(item.id)
        for child in item.children {
            collectAllIds(child, into: &set)
        }
    }
    
    // MARK: - Utility
    
    /// Clear any error
    func clearError() {
        error = nil
    }
}
