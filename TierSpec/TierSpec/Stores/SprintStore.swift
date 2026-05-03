//
//  SprintStore.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/1.
//

import Foundation
import Combine

@MainActor
final class SprintStore: ObservableObject {
    
    @Published private(set) var sprints: [SprintDTO] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    private let mcpClient: MCPToolClient
    private var cancellables = Set<AnyCancellable>()
    
    init(mcpClient: MCPToolClient) {
        self.mcpClient = mcpClient
    }
    
    func loadSprints() async {
        isLoading = true
        error = nil
        
        do {
            let result = try await mcpClient.getSprintStatus(sprintId: "all")
            sprints = try decodeSprints(from: result)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func createSprint(
        name: String,
        startDate: Date,
        endDate: Date,
        capacityPoints: Int = 0
    ) async throws -> SprintDTO {
        let result = try await mcpClient.createSprint(
            name: name,
            startDate: startDate,
            endDate: endDate,
            capacityPoints: capacityPoints
        )
        
        let sprint = try decodeSprint(from: result)
        await loadSprints()
        return sprint
    }
    
    func assignItemsToSprint(itemIds: [UUID], sprintId: UUID) async throws {
        _ = try await mcpClient.assignToSprint(
            itemIds: itemIds.map { $0.uuidString },
            sprintId: sprintId.uuidString
        )
        await loadSprints()
    }
    
    func getSprintStatus(sprintId: UUID) async throws -> SprintDTO {
        let result = try await mcpClient.getSprintStatus(sprintId: sprintId.uuidString)
        return try decodeSprint(from: result)
    }
    
    func processSprintItems(sprintId: UUID) async throws {
        _ = try await mcpClient.processSprintItems(sprintId: sprintId.uuidString)
        await loadSprints()
    }
    
    private func decodeSprint(from result: [String: Any]) throws -> SprintDTO {
        let data = try JSONSerialization.data(withJSONObject: result)
        return try JSONDecoder().decode(SprintDTO.self, from: data)
    }
    
    private func decodeSprints(from result: [String: Any]) throws -> [SprintDTO] {
        guard let sprintsArray = result["sprints"] as? [[String: Any]] else {
            if let _ = result["id"] as? String {
                return [try decodeSprint(from: result)]
            }
            return []
        }
        
        let data = try JSONSerialization.data(withJSONObject: sprintsArray)
        return try JSONDecoder().decode([SprintDTO].self, from: data)
    }
    
    func clearError() {
        error = nil
    }
}