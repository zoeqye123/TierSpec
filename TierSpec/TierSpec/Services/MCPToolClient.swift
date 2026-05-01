import Foundation

class MCPToolClient {
    private let clientManager: MCPClientManager
    
    init(clientManager: MCPClientManager) {
        self.clientManager = clientManager
    }
    
    func createItem(
        type: String,
        title: String,
        description: String? = nil,
        parentId: String? = nil,
        status: String = "todo",
        priority: Int = 0,
        position: Double? = nil
    ) async throws -> [String: Any] {
        var args: [String: Any] = [
            "type": type,
            "title": title,
            "status": status,
            "priority": priority
        ]
        
        if let description = description {
            args["description"] = description
        }
        if let parentId = parentId {
            args["parent_id"] = parentId
        }
        if let position = position {
            args["position"] = position
        }
        
        return try await clientManager.callTool(name: "create_item", arguments: args)
    }
    
    func getItem(id: String) async throws -> [String: Any] {
        return try await clientManager.callTool(name: "get_item", arguments: ["id": id])
    }
    
    func updateItem(
        id: String,
        title: String? = nil,
        description: String? = nil,
        status: String? = nil,
        priority: Int? = nil,
        storyPoints: Int? = nil
    ) async throws -> [String: Any] {
        var args: [String: Any] = ["id": id]
        
        if let title = title {
            args["title"] = title
        }
        if let description = description {
            args["description"] = description
        }
        if let status = status {
            args["status"] = status
        }
        if let priority = priority {
            args["priority"] = priority
        }
        if let storyPoints = storyPoints {
            args["story_points"] = storyPoints
        }
        
        return try await clientManager.callTool(name: "update_item", arguments: args)
    }
    
    func moveItem(itemId: String, newParentId: String?) async throws -> [String: Any] {
        var args: [String: Any] = ["item_id": itemId]
        if let newParentId = newParentId {
            args["new_parent_id"] = newParentId
        }
        return try await clientManager.callTool(name: "move_item", arguments: args)
    }
    
    func reorderItems(parentId: String?, itemPositions: [[String: Any]]) async throws -> [String: Any] {
        var args: [String: Any] = ["item_positions": itemPositions]
        if let parentId = parentId {
            args["parent_id"] = parentId
        }
        return try await clientManager.callTool(name: "reorder_items", arguments: args)
    }
    
    func deleteItem(itemId: String, cascadeChildren: Bool = false) async throws -> [String: Any] {
        return try await clientManager.callTool(
            name: "delete_item",
            arguments: [
                "item_id": itemId,
                "cascade_children": cascadeChildren
            ]
        )
    }
    
    func getItemTree(rootId: String, maxDepth: Int = 10) async throws -> [String: Any] {
        return try await clientManager.callTool(
            name: "get_item_tree",
            arguments: [
                "root_id": rootId,
                "max_depth": maxDepth
            ]
        )
    }
    
    func searchItems(query: String, limit: Int = 50, page: Int = 1) async throws -> [String: Any] {
        return try await clientManager.callTool(
            name: "search_items",
            arguments: [
                "query": query,
                "limit": limit,
                "page": page
            ]
        )
    }
    
    func listItems(
        parentId: String? = nil,
        type: String? = nil,
        status: String? = nil
    ) async throws -> [String: Any] {
        var args: [String: Any] = [:]
        
        if let parentId = parentId {
            args["parent_id"] = parentId
        }
        if let type = type {
            args["type"] = type
        }
        if let status = status {
            args["status"] = status
        }
        
        return try await clientManager.callTool(name: "list_items", arguments: args)
    }
    
    func transitionState(
        itemId: String,
        newState: String,
        reason: String? = nil,
        actorId: String? = nil
    ) async throws -> [String: Any] {
        var args: [String: Any] = [
            "item_id": itemId,
            "new_state": newState
        ]
        
        if let reason = reason {
            args["reason"] = reason
        }
        if let actorId = actorId {
            args["actor_id"] = actorId
        }
        
        return try await clientManager.callTool(name: "transition_state", arguments: args)
    }
    
    func blockItem(
        itemId: String,
        blockerId: String,
        reason: String,
        actorId: String? = nil
    ) async throws -> [String: Any] {
        var args: [String: Any] = [
            "item_id": itemId,
            "blocker_id": blockerId,
            "reason": reason
        ]
        
        if let actorId = actorId {
            args["actor_id"] = actorId
        }
        
        return try await clientManager.callTool(name: "block_item", arguments: args)
    }
    
    func createSprint(
        name: String,
        startDate: Date,
        endDate: Date,
        capacityPoints: Int = 0
    ) async throws -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        
        return try await clientManager.callTool(
            name: "create_sprint",
            arguments: [
                "name": name,
                "start_date": formatter.string(from: startDate),
                "end_date": formatter.string(from: endDate),
                "capacity_points": capacityPoints
            ]
        )
    }
    
    func assignToSprint(itemIds: [String], sprintId: String) async throws -> [String: Any] {
        return try await clientManager.callTool(
            name: "assign_to_sprint",
            arguments: [
                "item_ids": itemIds,
                "sprint_id": sprintId
            ]
        )
    }
    
    func getSprintStatus(sprintId: String) async throws -> [String: Any] {
        return try await clientManager.callTool(
            name: "get_sprint_status",
            arguments: ["sprint_id": sprintId]
        )
    }
    
    func processSprintItems(sprintId: String) async throws -> [String: Any] {
        return try await clientManager.callTool(
            name: "process_sprint_items",
            arguments: ["sprint_id": sprintId]
        )
    }
    
    func askClarification(itemId: String, question: String) async throws -> [String: Any] {
        return try await clientManager.callTool(
            name: "ask_clarification",
            arguments: [
                "item_id": itemId,
                "question": question
            ]
        )
    }
    
    func updateStory(
        itemId: String,
        updates: [String: Any]
    ) async throws -> [String: Any] {
        var args: [String: Any] = ["item_id": itemId]
        args.merge(updates) { _, new in new }
        
        return try await clientManager.callTool(name: "update_story", arguments: args)
    }
    
    func parseRequirement(
        requirement: String,
        apiKey: String? = nil
    ) async throws -> [String: Any] {
        var args: [String: Any] = ["requirement": requirement]
        
        if let apiKey = apiKey {
            args["apiKey"] = apiKey
        }
        
        return try await clientManager.callTool(name: "parse_requirement", arguments: args)
    }
    
    func estimateComplexity(
        storyDescription: String,
        apiKey: String? = nil
    ) async throws -> [String: Any] {
        var args: [String: Any] = ["storyDescription": storyDescription]
        
        if let apiKey = apiKey {
            args["apiKey"] = apiKey
        }
        
        return try await clientManager.callTool(name: "estimate_complexity", arguments: args)
    }
    
    func detectDependencies(
        storyDescription: String,
        existingStoryIds: [String],
        apiKey: String? = nil
    ) async throws -> [String: Any] {
        var args: [String: Any] = [
            "storyDescription": storyDescription,
            "existingStoryIds": existingStoryIds
        ]
        
        if let apiKey = apiKey {
            args["apiKey"] = apiKey
        }
        
        return try await clientManager.callTool(name: "detect_dependencies", arguments: args)
    }
}
