//
//  ItemDetailView+Previews.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI

extension TierItemDTO {
    static func makePreviewItem(
        type: ItemTypeDTO,
        title: String,
        status: ItemStatusDTO = .inProgress,
        priority: Int = 50,
        storyPoints: Int? = nil,
        complexity: ComplexityDTO? = nil,
        aiGenerated: Bool = false
    ) -> TierItemDTO {
        TierItemDTO(
            id: UUID(),
            type: type,
            parentId: nil,
            sprintId: nil,
            title: title,
            description: "This is a sample \(type.displayName.lowercased()) with a detailed description that explains what this item is about and what it should accomplish.",
            status: status,
            priority: priority,
            position: 0,
            storyPoints: storyPoints,
            complexity: complexity,
            aiGenerated: aiGenerated,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: ["frontend", "enhancement"],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
    }
}

struct ItemDetailViewCapabilityPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItemDTO.makePreviewItem(
            type: .capability,
            title: "User Authentication System",
            status: .inProgress,
            priority: 80,
            complexity: .l
        )
        
        NavigationStack {
            ItemDetailView(item: item, treeStore: TreeStore(mcpClient: MockMCPToolClient()))
        }
    }
}

struct ItemDetailViewFeaturePreview: PreviewProvider {
    static var previews: some View {
        let item = TierItemDTO.makePreviewItem(
            type: .feature,
            title: "OAuth 2.0 Integration",
            status: .backlog,
            priority: 70,
            storyPoints: 8,
            complexity: .l
        )
        
        NavigationStack {
            ItemDetailView(item: item, treeStore: TreeStore(mcpClient: MockMCPToolClient()))
        }
    }
}

struct ItemDetailViewUserStoryPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItemDTO.makePreviewItem(
            type: .userStory,
            title: "Google Sign-In for Users",
            status: .testing,
            priority: 85,
            storyPoints: 5,
            complexity: .m,
            aiGenerated: true
        )
        
        NavigationStack {
            ItemDetailView(item: item, treeStore: TreeStore(mcpClient: MockMCPToolClient()))
        }
    }
}

struct ItemDetailViewTestCasePreview: PreviewProvider {
    static var previews: some View {
        let item = TierItemDTO.makePreviewItem(
            type: .testCase,
            title: "Verify Token Expiry Handling",
            status: .completed,
            priority: 50,
            storyPoints: 1,
            complexity: .xs
        )
        
        NavigationStack {
            ItemDetailView(item: item, treeStore: TreeStore(mcpClient: MockMCPToolClient()))
        }
    }
}

struct ItemDetailViewAIGeneratedPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItemDTO.makePreviewItem(
            type: .userStory,
            title: "AI-Powered Recommendations",
            status: .backlog,
            priority: 75,
            storyPoints: 21,
            complexity: .xl,
            aiGenerated: true
        )
        
        NavigationStack {
            ItemDetailView(item: item, treeStore: TreeStore(mcpClient: MockMCPToolClient()))
        }
    }
}

struct ItemDetailViewBlockedPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItemDTO.makePreviewItem(
            type: .feature,
            title: "Payment Gateway Integration",
            status: .blocked,
            priority: 95,
            storyPoints: 8,
            complexity: .l
        )
        
        NavigationStack {
            ItemDetailView(item: item, treeStore: TreeStore(mcpClient: MockMCPToolClient()))
        }
    }
}

struct ItemDetailViewStatusGalleryPreview: PreviewProvider {
    static var previews: some View {
        StatusGalleryView()
    }
}

struct StatusGalleryView: View {
    let statuses: [(ItemStatusDTO, String)] = [
        (.backlog, "Backlog"),
        (.inProgress, "Progress"),
        (.testing, "Test"),
        (.completed, "Done"),
        (.blocked, "Blocked")
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 16) {
                ForEach(statuses, id: \.0) { status, label in
                    NavigationLink {
                        ItemDetailView(
                            item: TierItemDTO.makePreviewItem(
                                type: .feature,
                                title: "\(label) Feature Item",
                                status: status,
                                priority: 50
                            ),
                            treeStore: TreeStore(mcpClient: MockMCPToolClient())
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(status.color)
                                    .frame(width: 12, height: 12)
                                Text(status.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            Text("\(label) Feature Item")
                                .font(.headline)
                                .lineLimit(1)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Status Gallery")
    }
}

class MockMCPToolClient: MCPToolClient {
    init() {
        super.init(clientManager: MCPClientManager())
    }
}