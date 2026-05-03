//
//  TreeNodeView+Previews.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI

private enum TreeNodePreviewFactory {
    static func singleCapability() -> TierItemDTO {
        TierItemDTO(
            id: UUID(),
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "User Management",
            description: nil,
            status: .inProgress,
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
    }

    static func singleStory() -> TierItemDTO {
        TierItemDTO(
            id: UUID(),
            type: .userStory,
            parentId: nil,
            sprintId: nil,
            title: "As a user, I want to reset my password",
            description: nil,
            status: .todo,
            priority: 0,
            position: 0,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: true,
            aiConfidence: 0.85,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
    }

    static func hierarchyRoot() -> TierItemDTO {
        let capabilityId = UUID()
        let featureId = UUID()
        let storyId = UUID()
        let testCaseId = UUID()
        
        let testCase = TierItemDTO(
            id: testCaseId,
            type: .testCase,
            parentId: storyId,
            sprintId: nil,
            title: "Verify cart total calculation",
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
        
        let story = TierItemDTO(
            id: storyId,
            type: .userStory,
            parentId: featureId,
            sprintId: nil,
            title: "Add items to cart",
            description: nil,
            status: .todo,
            priority: 0,
            position: 0,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: true,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: [testCase]
        )
        
        let feature = TierItemDTO(
            id: featureId,
            type: .feature,
            parentId: capabilityId,
            sprintId: nil,
            title: "Shopping Cart",
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
            children: [story]
        )

        return TierItemDTO(
            id: capabilityId,
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "E-Commerce Platform",
            description: nil,
            status: .inProgress,
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
            children: [feature]
        )
    }

    static func multipleCapabilities() -> [TierItemDTO] {
        let authId = UUID()
        let loginId = UUID()
        let login = TierItemDTO(
            id: loginId,
            type: .feature,
            parentId: authId,
            sprintId: nil,
            title: "Login",
            description: nil,
            status: .done,
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
        let auth = TierItemDTO(
            id: authId,
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "User Authentication",
            description: nil,
            status: .done,
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
            children: [login]
        )

        let paymentId = UUID()
        let cardId = UUID()
        let card = TierItemDTO(
            id: cardId,
            type: .feature,
            parentId: paymentId,
            sprintId: nil,
            title: "Credit Card",
            description: nil,
            status: .test,
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
        let payment = TierItemDTO(
            id: paymentId,
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "Payment Processing",
            description: nil,
            status: .inProgress,
            priority: 0,
            position: 1,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: [card]
        )

        let inventory = TierItemDTO(
            id: UUID(),
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "Inventory Management",
            description: nil,
            status: .todo,
            priority: 0,
            position: 2,
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

        return [auth, payment, inventory]
    }

    static func statusItems() -> [TierItemDTO] {
        let statuses: [ItemStatusDTO] = [
            .todo, .inProgress, .test, .done,
            .blocked, .cancelled, .needsInfo,
        ]

        return statuses.enumerated().map { index, status in
            TierItemDTO(
                id: UUID(),
                type: index.isMultiple(of: 2) ? .capability : .feature,
                parentId: nil,
                sprintId: nil,
                title: "\(status.displayName) Item",
                description: nil,
                status: status,
                priority: 0,
                position: Double(index),
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
        }
    }
}

private struct PreviewTreeList: View {
    let items: [TierItemDTO]
    @State private var expandedItems: Set<UUID> = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(items) { item in
                    TreeNodeView(
                        item: item,
                        loadChildren: { $0.children },
                        selectedItem: .constant(nil),
                        expandedItems: $expandedItems,
                        onAddChild: { _, _ in },
                        onDelete: { _ in },
                        onUpdateTitle: { _, _ in }
                    )
                }
            }
            .padding(8)
        }
    }
}

#Preview("Single Node - Capability") {
    PreviewTreeList(items: [TreeNodePreviewFactory.singleCapability()])
        .frame(width: 300, height: 200)
}

#Preview("Single Node - Story with AI") {
    PreviewTreeList(items: [TreeNodePreviewFactory.singleStory()])
        .frame(width: 400, height: 200)
}

#Preview("Hierarchy - 4 Levels") {
    PreviewTreeList(items: [TreeNodePreviewFactory.hierarchyRoot()])
        .frame(width: 400, height: 500)
}

#Preview("Multiple Capabilities") {
    PreviewTreeList(items: TreeNodePreviewFactory.multipleCapabilities())
        .frame(width: 400, height: 400)
}

#Preview("All Status Types") {
    PreviewTreeList(items: TreeNodePreviewFactory.statusItems())
        .frame(width: 400, height: 600)
}

#Preview("Empty State") {
    PreviewTreeList(items: [])
        .frame(width: 300, height: 300)
}
