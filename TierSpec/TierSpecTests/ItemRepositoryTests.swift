//
//  ItemRepositoryTests.swift
//  TierSpecTests
//
//  Created by z on 2026/4/25.
//

import Testing
import SwiftData
import Foundation
@testable import TierSpec

@MainActor
struct ItemRepositoryTests {
    
    private func createInMemoryContainer() -> ModelContainer {
        let schema = Schema([TierItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
    
    @Test func createRootItem() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let capability = TierItem(type: .capability, title: "Test Capability")
        
        try await repository.create(capability)
        
        let fetched = try await repository.fetch(byId: capability.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "Test Capability")
        #expect(fetched?.type == .capability)
    }
    
    @Test func createChildItem() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let capability = TierItem(type: .capability, title: "Parent Capability")
        try await repository.create(capability)
        
        let feature = TierItem(type: .feature, title: "Child Feature")
        try await repository.create(feature, parent: capability)
        
        let fetched = try await repository.fetch(byId: feature.id)
        #expect(fetched != nil)
        #expect(fetched?.parent?.id == capability.id)
        #expect(capability.children?.count == 1)
    }
    
    @Test func invalidChildTypeThrowsError() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let capability = TierItem(type: .capability, title: "Capability")
        try await repository.create(capability)
        
        let userStory = TierItem(type: .user_story, title: "Invalid Child")
        
        await #expect(throws: RepositoryError.self) {
            try await repository.create(userStory, parent: capability)
        }
    }
    
    @Test func updateItem() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let item = TierItem(type: .capability, title: "Original Title")
        try await repository.create(item)
        
        item.title = "Updated Title"
        item.status = .in_progress
        try await repository.update(item)
        
        let fetched = try await repository.fetch(byId: item.id)
        #expect(fetched?.title == "Updated Title")
        #expect(fetched?.status == .in_progress)
    }
    
    @Test func softDeleteItem() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let item = TierItem(type: .capability, title: "To Delete")
        try await repository.create(item)
        
        try await repository.delete(item)
        
        let fetched = try await repository.fetch(byId: item.id)
        #expect(fetched?.isDeleted == true)
        #expect(fetched?.deletedAt != nil)
    }
    
    @Test func restoreDeletedItem() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let item = TierItem(type: .capability, title: "To Restore")
        try await repository.create(item)
        try await repository.delete(item)
        
        try await repository.restore(item)
        
        let fetched = try await repository.fetch(byId: item.id)
        #expect(fetched?.isDeleted == false)
        #expect(fetched?.deletedAt == nil)
    }
    
    @Test func fetchRootItems() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let cap1 = TierItem(type: .capability, title: "Capability 1")
        let cap2 = TierItem(type: .capability, title: "Capability 2")
        try await repository.create(cap1)
        try await repository.create(cap2)
        
        let feature = TierItem(type: .feature, title: "Feature")
        try await repository.create(feature, parent: cap1)
        
        let roots = try await repository.fetchRoot()
        #expect(roots.count == 2)
        #expect(roots.allSatisfy { $0.type == .capability })
    }
    
    @Test func fetchChildren() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let capability = TierItem(type: .capability, title: "Parent")
        try await repository.create(capability)
        
        let feature1 = TierItem(type: .feature, title: "Feature 1")
        let feature2 = TierItem(type: .feature, title: "Feature 2")
        try await repository.create(feature1, parent: capability)
        try await repository.create(feature2, parent: capability)
        
        let children = try await repository.fetchChildren(of: capability)
        #expect(children.count == 2)
    }
    
    @Test func fetchByType() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let cap = TierItem(type: .capability, title: "Cap")
        let feature = TierItem(type: .feature, title: "Feature")
        try await repository.create(cap)
        try await repository.create(feature)
        
        let capabilities = try await repository.fetch(byType: .capability)
        let features = try await repository.fetch(byType: .feature)
        
        #expect(capabilities.count == 1)
        #expect(features.count == 1)
    }
    
    @Test func fetchByStatus() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let item1 = TierItem(type: .capability, title: "Item 1", status: .todo)
        let item2 = TierItem(type: .capability, title: "Item 2", status: .in_progress)
        let item3 = TierItem(type: .capability, title: "Item 3", status: .todo)
        try await repository.create(item1)
        try await repository.create(item2)
        try await repository.create(item3)
        
        let backlogItems = try await repository.fetch(byStatus: .todo)
        #expect(backlogItems.count == 2)
    }
    
    @Test func searchItems() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let item1 = TierItem(type: .capability, title: "User Authentication")
        let item2 = TierItem(type: .capability, title: "Payment Processing")
        let item3 = TierItem(type: .capability, title: "User Profile", description: "User profile management")
        try await repository.create(item1)
        try await repository.create(item2)
        try await repository.create(item3)
        
        let results = try await repository.search(query: "User")
        #expect(results.count == 2)
    }
    
    @Test func moveItemToNewParent() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let cap1 = TierItem(type: .capability, title: "Capability 1")
        let cap2 = TierItem(type: .capability, title: "Capability 2")
        try await repository.create(cap1)
        try await repository.create(cap2)
        
        let feature = TierItem(type: .feature, title: "Feature")
        try await repository.create(feature, parent: cap1)
        
        try await repository.move(feature, to: cap2)
        
        let fetched = try await repository.fetch(byId: feature.id)
        #expect(fetched?.parent?.id == cap2.id)
        #expect(cap2.children?.contains { $0.id == feature.id } == true)
        #expect(cap1.children?.contains { $0.id == feature.id } == false)
    }
    
    @Test func moveItemToRoot() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let cap = TierItem(type: .capability, title: "Parent")
        try await repository.create(cap)
        
        let feature = TierItem(type: .feature, title: "Feature")
        try await repository.create(feature, parent: cap)
        
        await #expect(throws: RepositoryError.self) {
            try await repository.move(feature, to: nil)
        }
    }
    
    @Test func reorderChildren() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let cap = TierItem(type: .capability, title: "Parent")
        try await repository.create(cap)
        
        let feature1 = TierItem(type: .feature, title: "Feature 1")
        let feature2 = TierItem(type: .feature, title: "Feature 2")
        let feature3 = TierItem(type: .feature, title: "Feature 3")
        try await repository.create(feature1, parent: cap)
        try await repository.create(feature2, parent: cap)
        try await repository.create(feature3, parent: cap)
        
        try await repository.reorderChildren(of: cap, from: 0, to: 2)
        
        let children = try await repository.fetchChildren(of: cap)
        #expect(children[0].title == "Feature 2")
        #expect(children[1].title == "Feature 3")
        #expect(children[2].title == "Feature 1")
    }
    
    @Test func countByType() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let cap1 = TierItem(type: .capability, title: "Cap 1")
        let cap2 = TierItem(type: .capability, title: "Cap 2")
        let feature = TierItem(type: .feature, title: "Feature")
        try await repository.create(cap1)
        try await repository.create(cap2)
        try await repository.create(feature)
        
        let capabilityCount = try await repository.count(byType: .capability)
        let featureCount = try await repository.count(byType: .feature)
        
        #expect(capabilityCount == 2)
        #expect(featureCount == 1)
    }
    
    @Test func fetchAIGeneratedItems() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let repository = ItemRepository(modelContext: context)
        
        let human = TierItem(type: .capability, title: "Human Created", aiGenerated: false)
        let ai = TierItem(type: .capability, title: "AI Generated", aiGenerated: true)
        try await repository.create(human)
        try await repository.create(ai)
        
        let aiItems = try await repository.fetchAIGenerated()
        #expect(aiItems.count == 1)
        #expect(aiItems.first?.title == "AI Generated")
    }
}

struct TreeStoreTests {
    
    private func createInMemoryContainer() -> ModelContainer {
        let schema = Schema([TierItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
    
    @MainActor
    @Test func loadTreeLoadsRootItems() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let store = TreeStore(modelContext: context)
        
        let cap1 = TierItem(type: .capability, title: "Capability 1")
        let cap2 = TierItem(type: .capability, title: "Capability 2")
        context.insert(cap1)
        context.insert(cap2)
        try context.save()
        
        await store.loadTree()
        
        #expect(store.rootItems.count == 2)
        #expect(store.isLoading == false)
    }
    
    @MainActor
    @Test func createItemAddsToTree() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let store = TreeStore(modelContext: context)
        
        let capability = TierItem(type: .capability, title: "New Capability")
        await store.createItem(capability)
        
        #expect(store.rootItems.count == 1)
        #expect(store.rootItems.first?.title == "New Capability")
    }
    
    @MainActor
    @Test func deleteItemRemovesFromTree() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let store = TreeStore(modelContext: context)
        
        let capability = TierItem(type: .capability, title: "To Delete")
        await store.createItem(capability)
        #expect(store.rootItems.count == 1)
        
        await store.deleteItem(capability)
        
        let repository = ItemRepository(modelContext: context)
        let fetched = try await repository.fetch(byId: capability.id)
        #expect(fetched?.isDeleted == true)
    }
    
    @MainActor
    @Test func toggleExpansionChangesState() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let store = TreeStore(modelContext: context)
        
        let item = TierItem(type: .capability, title: "Test")
        
        store.toggleExpansion(item)
        #expect(store.expandedItems.contains(item.id))
        
        store.toggleExpansion(item)
        #expect(!store.expandedItems.contains(item.id))
    }
    
    @MainActor
    @Test func expandAllExpandsAllItems() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let store = TreeStore(modelContext: context)
        
        let cap = TierItem(type: .capability, title: "Cap")
        let feature = TierItem(type: .feature, title: "Feature")
        context.insert(cap)
        feature.parent = cap
        cap.children = [feature]
        try context.save()
        
        await store.loadTree()
        store.expandAll()
        
        #expect(store.expandedItems.contains(cap.id))
        #expect(store.expandedItems.contains(feature.id))
    }
    
    @MainActor
    @Test func collapseAllRemovesAllExpanded() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let store = TreeStore(modelContext: context)
        
        let item = TierItem(type: .capability, title: "Test")
        store.toggleExpansion(item)
        #expect(!store.expandedItems.isEmpty)
        
        store.collapseAll()
        #expect(store.expandedItems.isEmpty)
    }
    
    @MainActor
    @Test func moveNodeUpdatesParent() async throws {
        let container = createInMemoryContainer()
        let context = container.mainContext
        let store = TreeStore(modelContext: context)
        
        let cap1 = TierItem(type: .capability, title: "Capability 1")
        let cap2 = TierItem(type: .capability, title: "Capability 2")
        context.insert(cap1)
        context.insert(cap2)
        try context.save()
        
        let feature = TierItem(type: .feature, title: "Feature")
        feature.parent = cap1
        cap1.children = [feature]
        try context.save()
        
        await store.loadTree()
        await store.moveNode(feature, to: cap2)
        
        #expect(feature.parent?.id == cap2.id)
    }
}
