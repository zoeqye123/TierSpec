//
//  TreeNodeView+Previews.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI

private enum TreeNodePreviewFactory {
    static func singleCapability() -> TierItem {
        TierItem(
            type: .capability,
            title: "User Management",
            status: .in_progress
        )
    }

    static func singleStory() -> TierItem {
        TierItem(
            type: .user_story,
            title: "As a user, I want to reset my password",
            status: .todo,
            aiGenerated: true,
            aiConfidence: 0.85
        )
    }

    static func hierarchyRoot() -> TierItem {
        let capability = TierItem(type: .capability, title: "E-Commerce Platform", status: .in_progress)
        let feature = TierItem(type: .feature, title: "Shopping Cart", status: .todo)
        let story = TierItem(type: .user_story, title: "Add items to cart", status: .todo, aiGenerated: true)
        let testCase = TierItem(type: .test_case, title: "Verify cart total calculation", status: .todo)

        feature.parent = capability
        story.parent = feature
        testCase.parent = story

        capability.children = [feature]
        feature.children = [story]
        story.children = [testCase]

        return capability
    }

    static func multipleCapabilities() -> [TierItem] {
        let auth = TierItem(type: .capability, title: "User Authentication", status: .done)
        let login = TierItem(type: .feature, title: "Login", status: .done)
        login.parent = auth
        auth.children = [login]

        let payment = TierItem(type: .capability, title: "Payment Processing", status: .in_progress)
        let card = TierItem(type: .feature, title: "Credit Card", status: .test)
        card.parent = payment
        payment.children = [card]

        let inventory = TierItem(type: .capability, title: "Inventory Management", status: .todo)

        return [auth, payment, inventory]
    }

    static func statusItems() -> [TierItem] {
        let statuses: [ItemStatus] = [
            .todo, .in_progress, .test, .done,
            .blocked, .cancelled, .needs_info,
        ]

        return statuses.enumerated().map { index, status in
            TierItem(
                type: index.isMultiple(of: 2) ? .capability : .feature,
                title: "\(status.displayName) Item",
                status: status
            )
        }
    }
}

private struct PreviewTreeList: View {
    let items: [TierItem]
    @State private var expandedItems: Set<UUID> = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(items) { item in
                    TreeNodeView(
                        item: item,
                        loadChildren: { $0.outlineChildren },
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
