//
//  TreeNodeView+Previews.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

// MARK: - TreeNodeView Previews

#Preview("Single Node - Capability") {
    let item = TierItem(
        type: .capability,
        title: "User Management",
        status: .in_progress
    )
    
    return List {
        TreeNodeView(
            item: item,
            loadChildren: { _ in [] },
            selectedItem: .constant(nil)
        )
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 200)
}

#Preview("Single Node - Story with AI") {
    let item = TierItem(
        type: .business_story,
        title: "As a user, I want to reset my password",
        status: .backlog,
        aiGenerated: true,
        aiConfidence: 0.85
    )
    
    return List {
        TreeNodeView(
            item: item,
            loadChildren: { _ in [] },
            selectedItem: .constant(nil)
        )
    }
    .listStyle(.sidebar)
    .frame(width: 400, height: 200)
}

#Preview("Hierarchy - 5 Levels") {
    let container = try! ModelContainer(
        for: TierItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let context = container.mainContext
    
    let capability = TierItem(type: .capability, title: "E-Commerce Platform", status: .in_progress)
    context.insert(capability)
    
    let feature = TierItem(type: .feature, title: "Shopping Cart", status: .backlog)
    feature.parent = capability
    capability.children?.append(feature)
    context.insert(feature)
    
    let epic = TierItem(type: .epic, title: "Cart Management", status: .requirement_input)
    epic.parent = feature
    feature.children?.append(epic)
    context.insert(epic)
    
    let story = TierItem(type: .business_story, title: "Add items to cart", status: .backlog, aiGenerated: true)
    story.parent = epic
    epic.children?.append(story)
    context.insert(story)
    
    let testCase = TierItem(type: .test_case, title: "Verify cart total calculation", status: .backlog)
    testCase.parent = story
    story.children?.append(testCase)
    context.insert(testCase)
    
    return HierarchyTreeView()
        .modelContainer(container)
        .frame(width: 400, height: 500)
}

#Preview("Multiple Capabilities") {
    let container = try! ModelContainer(
        for: TierItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let context = container.mainContext
    
    let cap1 = TierItem(type: .capability, title: "User Authentication", status: .completed)
    context.insert(cap1)
    
    let feature1 = TierItem(type: .feature, title: "Login", status: .completed)
    feature1.parent = cap1
    cap1.children?.append(feature1)
    context.insert(feature1)
    
    let cap2 = TierItem(type: .capability, title: "Payment Processing", status: .in_progress)
    context.insert(cap2)
    
    let feature2 = TierItem(type: .feature, title: "Credit Card", status: .testing)
    feature2.parent = cap2
    cap2.children?.append(feature2)
    context.insert(feature2)
    
    let cap3 = TierItem(type: .capability, title: "Inventory Management", status: .backlog)
    context.insert(cap3)
    
    return HierarchyTreeView()
        .modelContainer(container)
        .frame(width: 400, height: 400)
}

#Preview("All Status Types") {
    let container = try! ModelContainer(
        for: TierItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let context = container.mainContext
    let statuses: [ItemStatus] = [
        .requirement_input, .requirement_review, .needs_info, .backlog,
        .ai_decomposing, .in_progress, .waiting_for_test, .testing,
        .acceptance, .completed, .published, .blocked, .cancelled
    ]
    
    for (index, status) in statuses.enumerated() {
        let item = TierItem(
            type: index % 2 == 0 ? .capability : .feature,
            title: "\(status.displayName) Item",
            status: status
        )
        context.insert(item)
    }
    
    return HierarchyTreeView()
        .modelContainer(container)
        .frame(width: 400, height: 600)
}

#Preview("Empty State") {
    HierarchyTreeView()
        .modelContainer(for: TierItem.self, inMemory: true)
        .frame(width: 300, height: 300)
}
