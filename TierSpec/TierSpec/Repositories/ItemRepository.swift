//
//  ItemRepository.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import Foundation
import SwiftData

/// Repository for TierItem data access using SwiftData
actor ItemRepository {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new TierItem
    func create(_ item: TierItem) throws {
        modelContext.insert(item)
        try modelContext.save()
    }
    
    /// Create a new TierItem with a parent
    func create(_ item: TierItem, parent: TierItem) throws {
        guard parent.canAddChild(ofType: item.type) else {
            throw RepositoryError.invalidChildType(
                parentType: parent.type.displayName,
                childType: item.type.displayName
            )
        }
        
        item.parent = parent
        if parent.children == nil {
            parent.children = []
        }
        parent.children?.append(item)
        
        // Set position to be at the end
        item.position = Double(parent.children?.count ?? 0)
        
        modelContext.insert(item)
        try modelContext.save()
    }
    
    /// Fetch a TierItem by ID
    func fetch(byId id: UUID) throws -> TierItem? {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { $0.id == id }
        )
        let items = try modelContext.fetch(descriptor)
        return items.first
    }
    
    /// Update a TierItem
    func update(_ item: TierItem) throws {
        item.touch()
        try modelContext.save()
    }
    
    /// Delete a TierItem (soft delete)
    func delete(_ item: TierItem) throws {
        item.softDelete()
        try modelContext.save()
    }
    
    /// Hard delete a TierItem (permanent removal)
    func hardDelete(_ item: TierItem) throws {
        modelContext.delete(item)
        try modelContext.save()
    }
    
    /// Restore a soft-deleted TierItem
    func restore(_ item: TierItem) throws {
        item.restore()
        try modelContext.save()
    }
    
    // MARK: - Query Operations
    
    /// Fetch all root items (capabilities without parents)
    func fetchRoot() throws -> [TierItem] {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { $0.parent == nil && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.position)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch children of a parent item
    func fetchChildren(of parent: TierItem) throws -> [TierItem] {
        return parent.outlineChildren
    }
    
    /// Fetch all items of a specific type
    func fetch(byType type: ItemType) throws -> [TierItem] {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { $0.type == type && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch items by status
    func fetch(byStatus status: ItemStatus) throws -> [TierItem] {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { $0.status == status && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Search items by title or description
    func search(query: String) throws -> [TierItem] {
        guard !query.isEmpty else { return [] }
        
        let lowercasedQuery = query.lowercased()
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { item in
                item.deletedAt == nil &&
                (item.title.localizedStandardContains(lowercasedQuery) ||
                 (item.itemDescription != nil && item.itemDescription!.localizedStandardContains(lowercasedQuery)))
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch all items (including soft-deleted)
    func fetchAll() throws -> [TierItem] {
        let descriptor = FetchDescriptor<TierItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch soft-deleted items
    func fetchDeleted() throws -> [TierItem] {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { $0.deletedAt != nil },
            sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch AI-generated items
    func fetchAIGenerated() throws -> [TierItem] {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { $0.aiGenerated == true && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Count items by type
    func count(byType type: ItemType) throws -> Int {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { $0.type == type && $0.deletedAt == nil }
        )
        return try modelContext.fetchCount(descriptor)
    }
    
    /// Count items by status
    func count(byStatus status: ItemStatus) throws -> Int {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { $0.status == status && $0.deletedAt == nil }
        )
        return try modelContext.fetchCount(descriptor)
    }
    
    func fetch(byType type: ItemType, sprint: Sprint?) throws -> [TierItem] {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { item in
                item.type == type && 
                item.deletedAt == nil && 
                item.sprint?.id == sprint?.id
            },
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func fetchUnassigned(byType type: ItemType) throws -> [TierItem] {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { item in
                item.type == type && 
                item.deletedAt == nil && 
                item.sprint == nil
            },
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Hierarchy Operations
    
    /// Move an item to a new parent
    func move(_ item: TierItem, to newParent: TierItem?) throws {
        if let newParent = newParent {
            guard newParent.canAddChild(ofType: item.type) else {
                throw RepositoryError.invalidChildType(
                    parentType: newParent.type.displayName,
                    childType: item.type.displayName
                )
            }
        } else {
            guard item.type == .capability else {
                throw RepositoryError.invalidRootItem(type: item.type.displayName)
            }
        }
        
        let oldParent = item.parent
        
        if let oldParent = oldParent {
            oldParent.children?.removeAll { $0.id == item.id }
            oldParent.invalidateCache()
        }
        
        if let newParent = newParent {
            item.parent = newParent
            if newParent.children == nil {
                newParent.children = []
            }
            newParent.children?.append(item)
            item.position = Double(newParent.children?.count ?? 0)
            newParent.invalidateCache()
        } else {
            item.parent = nil
        }
        
        item.touch()
        try modelContext.save()
    }
    
    /// Reorder children within a parent
    func reorderChildren(of parent: TierItem, from sourceIndex: Int, to destinationIndex: Int) throws {
        guard var children = parent.children else { return }
        guard sourceIndex < children.count && destinationIndex <= children.count else {
            throw RepositoryError.invalidIndex
        }

        let movedItem = children.remove(at: sourceIndex)
        let clampedDestination = min(destinationIndex, children.count)
        children.insert(movedItem, at: clampedDestination)
        parent.children = children
        
        for (index, child) in children.enumerated() {
            child.position = Double(index)
            child.touch()
        }
        
        parent.invalidateCache()
        try modelContext.save()
    }
    
    /// Get the full tree as a flat list (depth-first)
    func fetchTreeFlat() throws -> [TierItem] {
        let roots = try fetchRoot()
        var result: [TierItem] = []
        
        for root in roots {
            result.append(root)
            result.append(contentsOf: flattenChildren(root))
        }
        
        return result
    }
    
    private func flattenChildren(_ item: TierItem) -> [TierItem] {
        var result: [TierItem] = []
        
        for child in item.outlineChildren {
            result.append(child)
            result.append(contentsOf: flattenChildren(child))
        }
        
        return result
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case invalidChildType(parentType: String, childType: String)
    case invalidRootItem(type: String)
    case invalidIndex
    case itemNotFound(id: UUID)
    
    var errorDescription: String? {
        switch self {
        case .invalidChildType(let parentType, let childType):
            return "Cannot add \(childType) as child of \(parentType)"
        case .invalidRootItem(let type):
            return "Only capabilities can be root items, not \(type)"
        case .invalidIndex:
            return "Invalid index for reordering"
        case .itemNotFound(let id):
            return "Item not found with ID: \(id)"
        }
    }
}
