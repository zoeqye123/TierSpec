//
//  TierItemDTOTests.swift
//  TierSpecTests
//
//  Created for TierSpec
//

import Testing
import Foundation
@testable import TierSpec

@Suite("TierItemDTO Tests")
struct TierItemDTOTests {
    
    @Test("TierItemDTO creates with correct defaults")
    func testCreation() async throws {
        let id = UUID()
        let item = TierItemDTO(
            id: id,
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "Test Capability",
            description: "A test capability",
            status: .todo,
            priority: 0,
            position: 1.0,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
        
        #expect(item.id == id)
        #expect(item.type == .capability)
        #expect(item.parentId == nil)
        #expect(item.title == "Test Capability")
        #expect(item.status == .todo)
        #expect(item.children.isEmpty == true)
    }
    
    @Test("TierItemDTO encodes and decodes correctly")
    func testCodable() async throws {
        let id = UUID()
        let createdAt = Date()
        let item = TierItemDTO(
            id: id,
            type: .feature,
            parentId: UUID(),
            sprintId: nil,
            title: "Test Feature",
            description: "A test feature",
            status: .inProgress,
            priority: 50,
            position: 2.5,
            storyPoints: 5,
            complexity: .l,
            aiGenerated: true,
            aiConfidence: 0.85,
            aiReasoning: "AI suggested this feature",
            labels: ["backend", "api"],
            createdAt: createdAt,
            updatedAt: createdAt,
            deletedAt: nil,
            children: []
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TierItemDTO.self, from: data)
        
        #expect(decoded.id == item.id)
        #expect(decoded.type == item.type)
        #expect(decoded.title == item.title)
        #expect(decoded.status == item.status)
        #expect(decoded.priority == item.priority)
        #expect(decoded.storyPoints == item.storyPoints)
        #expect(decoded.complexity == item.complexity)
        #expect(decoded.aiGenerated == item.aiGenerated)
        #expect(decoded.aiConfidence == item.aiConfidence)
        #expect(decoded.labels == item.labels)
    }
    
    @Test("TierItemDTO is Identifiable")
    func testIdentifiable() async throws {
        let id = UUID()
        let item = TierItemDTO(
            id: id,
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "Test",
            description: nil,
            status: .todo,
            priority: 0,
            position: 0,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
        
        #expect(item.id == id)
    }
    
    @Test("TierItemDTO is Equatable")
    func testEquatable() async throws {
        let id = UUID()
        let date = Date()
        
        let item1 = TierItemDTO(
            id: id,
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "Test",
            description: nil,
            status: .todo,
            priority: 0,
            position: 0,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: date,
            updatedAt: date,
            deletedAt: nil,
            children: []
        )
        
        let item2 = TierItemDTO(
            id: id,
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "Test",
            description: nil,
            status: .todo,
            priority: 0,
            position: 0,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: date,
            updatedAt: date,
            deletedAt: nil,
            children: []
        )
        
        #expect(item1 == item2)
    }
    
    @Test("TierItemDTO is Hashable")
    func testHashable() async throws {
        let id = UUID()
        let item = TierItemDTO(
            id: id,
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "Test",
            description: nil,
            status: .todo,
            priority: 0,
            position: 0,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
        
        let set: Set<TierItemDTO> = [item]
        #expect(set.contains(item))
    }
    
    @Test("TierItemDTO children can be updated")
    func testChildrenUpdate() async throws {
        var item = TierItemDTO(
            id: UUID(),
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "Parent",
            description: nil,
            status: .todo,
            priority: 0,
            position: 0,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
        
        let child = TierItemDTO(
            id: UUID(),
            type: .feature,
            parentId: item.id,
            sprintId: nil,
            title: "Child",
            description: nil,
            status: .todo,
            priority: 0,
            position: 0,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
        
        item.children = [child]
        #expect(item.children.count == 1)
        #expect(item.children.first?.title == "Child")
    }
}
