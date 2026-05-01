//
//  ItemRepository.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import Foundation

/// Repository for TierItem data access using MCP client
actor ItemRepository {
    
    // MARK: - Properties
    
    private let mcpClient: MCPToolClient
    
    // MARK: - Initialization
    
    init(mcpClient: MCPToolClient) {
        self.mcpClient = mcpClient
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new TierItem
    func create(_ item: TierItemDTO) async throws -> TierItemDTO {
        let result = try await mcpClient.createItem(
            type: item.type.rawValue,
            title: item.title,
            description: item.description,
            parentId: item.parentId?.uuidString,
            status: item.status.rawValue,
            priority: item.priority,
            position: item.position
        )
        return try decodeItem(from: result)
    }
    
    /// Create a new TierItem with a parent
    func create(_ item: TierItemDTO, parentId: UUID) async throws -> TierItemDTO {
        let result = try await mcpClient.createItem(
            type: item.type.rawValue,
            title: item.title,
            description: item.description,
            parentId: parentId.uuidString,
            status: item.status.rawValue,
            priority: item.priority,
            position: item.position
        )
        return try decodeItem(from: result)
    }
    
    /// Fetch a TierItem by ID
    func fetch(byId id: UUID) async throws -> TierItemDTO? {
        do {
            let result = try await mcpClient.getItem(id: id.uuidString)
            return try decodeItem(from: result)
        } catch {
            return nil
        }
    }
    
    /// Update a TierItem
    func update(_ item: TierItemDTO) async throws -> TierItemDTO {
        let result = try await mcpClient.updateItem(
            id: item.id.uuidString,
            title: item.title,
            description: item.description,
            status: item.status.rawValue,
            priority: item.priority,
            storyPoints: item.storyPoints
        )
        return try decodeItem(from: result)
    }
    
    /// Delete a TierItem (soft delete)
    func delete(_ item: TierItemDTO) async throws {
        _ = try await mcpClient.deleteItem(itemId: item.id.uuidString, cascadeChildren: false)
    }
    
    /// Hard delete a TierItem (permanent removal)
    func hardDelete(_ item: TierItemDTO) async throws {
        _ = try await mcpClient.deleteItem(itemId: item.id.uuidString, cascadeChildren: true)
    }
    
    /// Restore a soft-deleted TierItem
    func restore(_ item: TierItemDTO) async throws -> TierItemDTO {
        // MCP server should have a restore endpoint - using update with status change for now
        let result = try await mcpClient.updateItem(
            id: item.id.uuidString,
            status: "backlog"
        )
        return try decodeItem(from: result)
    }
    
    // MARK: - Query Operations
    
    /// Fetch all root items (capabilities without parents)
    func fetchRoot() async throws -> [TierItemDTO] {
        let result = try await mcpClient.listItems(parentId: nil, type: nil, status: nil)
        return try decodeItems(from: result)
    }
    
    /// Fetch children of a parent item
    func fetchChildren(of parent: TierItemDTO) async throws -> [TierItemDTO] {
        let result = try await mcpClient.listItems(parentId: parent.id.uuidString, type: nil, status: nil)
        return try decodeItems(from: result)
    }
    
    /// Fetch all items of a specific type
    func fetch(byType type: ItemTypeDTO) async throws -> [TierItemDTO] {
        let result = try await mcpClient.listItems(parentId: nil, type: type.rawValue, status: nil)
        return try decodeItems(from: result)
    }
    
    /// Fetch items by status
    func fetch(byStatus status: ItemStatusDTO) async throws -> [TierItemDTO] {
        let result = try await mcpClient.listItems(parentId: nil, type: nil, status: status.rawValue)
        return try decodeItems(from: result)
    }
    
    /// Search items by title or description
    func search(query: String) async throws -> [TierItemDTO] {
        guard !query.isEmpty else { return [] }
        let result = try await mcpClient.searchItems(query: query, limit: 100, page: 1)
        return try decodeItems(from: result)
    }
    
    /// Fetch all items (including soft-deleted)
    func fetchAll() async throws -> [TierItemDTO] {
        // MCP server doesn't have a specific "fetch all" endpoint
        // Using search with empty query to get all items
        let result = try await mcpClient.searchItems(query: "", limit: 1000, page: 1)
        return try decodeItems(from: result)
    }
    
    /// Fetch soft-deleted items
    func fetchDeleted() async throws -> [TierItemDTO] {
        // MCP server should filter by deleted status
        // Using list with status filter for now
        let result = try await mcpClient.listItems(parentId: nil, type: nil, status: "deleted")
        return try decodeItems(from: result)
    }
    
    /// Fetch AI-generated items
    func fetchAIGenerated() async throws -> [TierItemDTO] {
        // MCP server should have a filter for AI-generated items
        // For now, fetch all and filter client-side
        let allItems = try await fetchAll()
        return allItems.filter { $0.aiGenerated }
    }
    
    /// Count items by type
    func count(byType type: ItemTypeDTO) async throws -> Int {
        let items = try await fetch(byType: type)
        return items.count
    }
    
    /// Count items by status
    func count(byStatus status: ItemStatusDTO) async throws -> Int {
        let items = try await fetch(byStatus: status)
        return items.count
    }
    
    func fetch(byType type: ItemTypeDTO, sprint: SprintDTO?) async throws -> [TierItemDTO] {
        // MCP server should support sprint filtering
        // For now, fetch by type and filter client-side
        let items = try await fetch(byType: type)
        if let sprintId = sprint?.id {
            return items.filter { $0.sprintId == sprintId }
        }
        return items.filter { $0.sprintId == nil }
    }
    
    func fetchUnassigned(byType type: ItemTypeDTO) async throws -> [TierItemDTO] {
        let items = try await fetch(byType: type)
        return items.filter { $0.sprintId == nil }
    }
    
    // MARK: - Hierarchy Operations
    
    /// Move an item to a new parent
    func move(_ item: TierItemDTO, to newParent: TierItemDTO?) async throws {
        _ = try await mcpClient.moveItem(
            itemId: item.id.uuidString,
            newParentId: newParent?.id.uuidString
        )
    }
    
    /// Reorder children within a parent
    func reorderChildren(of parent: TierItemDTO, from sourceIndex: Int, to destinationIndex: Int) async throws {
        var children = try await fetchChildren(of: parent)
        
        guard sourceIndex < children.count && destinationIndex <= children.count else {
            throw RepositoryError.invalidIndex
        }
        
        let movedItem = children.remove(at: sourceIndex)
        let clampedDestination = min(destinationIndex, children.count)
        children.insert(movedItem, at: clampedDestination)
        
        let itemPositions = children.enumerated().map { index, item in
            ["item_id": item.id.uuidString, "position": Double(index)]
        }
        
        _ = try await mcpClient.reorderItems(parentId: parent.id.uuidString, itemPositions: itemPositions)
    }
    
    /// Get the full tree as a flat list (depth-first)
    func fetchTreeFlat() async throws -> [TierItemDTO] {
        let roots = try await fetchRoot()
        var result: [TierItemDTO] = []
        
        for root in roots {
            result.append(root)
            result.append(contentsOf: try await flattenChildren(root))
        }
        
        return result
    }
    
    private func flattenChildren(_ item: TierItemDTO) async throws -> [TierItemDTO] {
        var result: [TierItemDTO] = []
        
        let children = try await fetchChildren(of: item)
        for child in children {
            result.append(child)
            result.append(contentsOf: try await flattenChildren(child))
        }
        
        return result
    }
    
    // MARK: - State Transitions
    
    /// Transition item to a new state
    func transitionState(_ item: TierItemDTO, to newState: ItemStatusDTO, actorId: String? = nil, reason: String? = nil) async throws -> TierItemDTO {
        let result = try await mcpClient.transitionState(
            itemId: item.id.uuidString,
            newState: newState.rawValue,
            reason: reason,
            actorId: actorId
        )
        return try decodeItem(from: result)
    }
    
    /// Block an item
    func blockItem(_ item: TierItemDTO, blockerId: String, reason: String, actorId: String? = nil) async throws -> TierItemDTO {
        let result = try await mcpClient.blockItem(
            itemId: item.id.uuidString,
            blockerId: blockerId,
            reason: reason,
            actorId: actorId
        )
        return try decodeItem(from: result)
    }
    
    /// Get item tree
    func getTree(rootId: UUID, maxDepth: Int = 10) async throws -> TierItemDTO {
        let result = try await mcpClient.getItemTree(rootId: rootId.uuidString, maxDepth: maxDepth)
        return try decodeItem(from: result)
    }
    
    // MARK: - JSON Decoding Helpers
    
    private func decodeItem(from result: [String: Any]) throws -> TierItemDTO {
        let data = try JSONSerialization.data(withJSONObject: result)
        return try JSONDecoder().decode(TierItemDTO.self, from: data)
    }
    
    private func decodeItems(from result: [String: Any]) throws -> [TierItemDTO] {
        // MCP server returns items in an "items" array
        guard let itemsArray = result["items"] as? [[String: Any]] else {
            // If no "items" key, try to decode as single item wrapped in array
            if let _ = result["id"] as? String {
                return [try decodeItem(from: result)]
            }
            return []
        }
        
        let data = try JSONSerialization.data(withJSONObject: itemsArray)
        return try JSONDecoder().decode([TierItemDTO].self, from: data)
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case invalidChildType(parentType: String, childType: String)
    case invalidRootItem(type: String)
    case invalidIndex
    case itemNotFound(id: UUID)
    case decodingError(String)
    case mcpError(String)
    
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
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .mcpError(let message):
            return "MCP server error: \(message)"
        }
    }
}
