//
//  MultiWindowTests.swift
//  TierSpecTests
//
//  Created by z on 2026/4/30.
//

import Testing
import SwiftData
import Foundation
@testable import TierSpec

@MainActor
struct MultiWindowTests {
    
    private func createInMemoryContainer() -> ModelContainer {
        let schema = Schema([TierItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
    
    @Test func dataIsolationBetweenProjects() async throws {
        // Create two separate ModelContainers (simulating two project windows)
        let container1 = createInMemoryContainer()
        let container2 = createInMemoryContainer()
        
        let context1 = container1.mainContext
        let context2 = container2.mainContext
        
        let repository1 = ItemRepository(modelContext: context1)
        let repository2 = ItemRepository(modelContext: context2)
        
        // Insert an item in project 1
        let capability = TierItem(type: .capability, title: "Project 1 Capability")
        try await repository1.create(capability)
        
        // Verify item exists in project 1
        let fetched1 = try await repository1.fetch(byId: capability.id)
        #expect(fetched1 != nil)
        #expect(fetched1?.title == "Project 1 Capability")
        
        // Verify item does NOT exist in project 2
        let fetched2 = try await repository2.fetch(byId: capability.id)
        #expect(fetched2 == nil)
        
        // Insert different item in project 2
        let feature = TierItem(type: .feature, title: "Project 2 Feature")
        
        // Need a parent for feature - create one in project 2
        let cap2 = TierItem(type: .capability, title: "Project 2 Capability")
        try await repository2.create(cap2)
        try await repository2.create(feature, parent: cap2)
        
        // Verify project 1 still only has its own item
        let roots1 = try await repository1.fetchRoot()
        #expect(roots1.count == 1)
        #expect(roots1.first?.title == "Project 1 Capability")
        
        // Verify project 2 has its own items
        let roots2 = try await repository2.fetchRoot()
        #expect(roots2.count == 1)
        #expect(roots2.first?.title == "Project 2 Capability")
    }
    
    @Test func separateProjectContextsHaveSeparateContainers() async throws {
        // Create two ProjectContext instances with different databases
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath1 = tempDir.appendingPathComponent("test-project-1.db").path
        let dbPath2 = tempDir.appendingPathComponent("test-project-2.db").path
        
        // Clean up any existing test databases
        try? FileManager.default.removeItem(atPath: dbPath1)
        try? FileManager.default.removeItem(atPath: dbPath2)
        
        let project1 = ProjectContext(id: UUID(), name: "Project 1", databasePath: dbPath1)
        let project2 = ProjectContext(id: UUID(), name: "Project 2", databasePath: dbPath2)
        
        let context1 = project1.modelContainer.mainContext
        let context2 = project2.modelContainer.mainContext
        
        let repository1 = ItemRepository(modelContext: context1)
        let repository2 = ItemRepository(modelContext: context2)
        
        // Insert item in project 1
        let cap1 = TierItem(type: .capability, title: "Capability in Project 1")
        try await repository1.create(cap1)
        
        // Insert item in project 2
        let cap2 = TierItem(type: .capability, title: "Capability in Project 2")
        try await repository2.create(cap2)
        
        // Verify isolation
        let roots1 = try await repository1.fetchRoot()
        let roots2 = try await repository2.fetchRoot()
        
        #expect(roots1.count == 1)
        #expect(roots1.first?.title == "Capability in Project 1")
        
        #expect(roots2.count == 1)
        #expect(roots2.first?.title == "Capability in Project 2")
        
        // Clean up
        try? FileManager.default.removeItem(atPath: dbPath1)
        try? FileManager.default.removeItem(atPath: dbPath2)
    }
}
