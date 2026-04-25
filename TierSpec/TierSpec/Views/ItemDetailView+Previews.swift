//
//  ItemDetailView+Previews.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

// MARK: - Preview Helpers

extension TierItem {
    static func makePreviewItem(
        type: ItemType,
        title: String,
        status: ItemStatus = .in_progress,
        priority: Int = 50,
        storyPoints: Int? = nil,
        complexity: Complexity? = nil,
        aiGenerated: Bool = false
    ) -> TierItem {
        TierItem(
            type: type,
            title: title,
            description: "This is a sample \(type.displayName.lowercased()) with a detailed description that explains what this item is about and what it should accomplish.",
            status: status,
            priority: priority,
            storyPoints: storyPoints,
            complexity: complexity,
            aiGenerated: aiGenerated,
            labels: ["frontend", "enhancement"]
        )
    }
}

// MARK: - Previews

struct ItemDetailViewCapabilityPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItem.makePreviewItem(
            type: .capability,
            title: "User Authentication System",
            status: .in_progress,
            priority: 80,
            complexity: .l
        )
        
        NavigationStack {
            ItemDetailView(item: item)
        }
        .modelContainer(for: TierItem.self, inMemory: true)
    }
}

struct ItemDetailViewFeaturePreview: PreviewProvider {
    static var previews: some View {
        let item = TierItem.makePreviewItem(
            type: .feature,
            title: "OAuth 2.0 Integration",
            status: .requirement_review,
            priority: 70,
            storyPoints: 8,
            complexity: .l
        )
        
        NavigationStack {
            ItemDetailView(item: item)
        }
        .modelContainer(for: TierItem.self, inMemory: true)
    }
}

struct ItemDetailViewEpicPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItem.makePreviewItem(
            type: .epic,
            title: "Social Login Providers",
            status: .backlog,
            priority: 60,
            storyPoints: 13,
            complexity: .xl
        )
        
        NavigationStack {
            ItemDetailView(item: item)
        }
        .modelContainer(for: TierItem.self, inMemory: true)
    }
}

struct ItemDetailViewBusinessStoryPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItem.makePreviewItem(
            type: .business_story,
            title: "Google Sign-In for Users",
            status: .testing,
            priority: 85,
            storyPoints: 5,
            complexity: .m,
            aiGenerated: true
        )
        
        NavigationStack {
            ItemDetailView(item: item)
        }
        .modelContainer(for: TierItem.self, inMemory: true)
    }
}

struct ItemDetailViewTechnicalStoryPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItem.makePreviewItem(
            type: .technical_story,
            title: "Implement Token Refresh Flow",
            status: .in_progress,
            priority: 90,
            storyPoints: 3,
            complexity: .s
        )
        
        NavigationStack {
            ItemDetailView(item: item)
        }
        .modelContainer(for: TierItem.self, inMemory: true)
    }
}

struct ItemDetailViewTestCasePreview: PreviewProvider {
    static var previews: some View {
        let item = TierItem.makePreviewItem(
            type: .test_case,
            title: "Verify Token Expiry Handling",
            status: .completed,
            priority: 50,
            storyPoints: 1,
            complexity: .xs
        )
        
        NavigationStack {
            ItemDetailView(item: item)
        }
        .modelContainer(for: TierItem.self, inMemory: true)
    }
}

struct ItemDetailViewAIGeneratedPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItem.makePreviewItem(
            type: .epic,
            title: "AI-Powered Recommendations",
            status: .ai_decomposing,
            priority: 75,
            storyPoints: 21,
            complexity: .xl,
            aiGenerated: true
        )
        
        NavigationStack {
            ItemDetailView(item: item)
        }
        .modelContainer(for: TierItem.self, inMemory: true)
    }
}

struct ItemDetailViewBlockedPreview: PreviewProvider {
    static var previews: some View {
        let item = TierItem.makePreviewItem(
            type: .feature,
            title: "Payment Gateway Integration",
            status: .blocked,
            priority: 95,
            storyPoints: 8,
            complexity: .l
        )
        
        NavigationStack {
            ItemDetailView(item: item)
        }
        .modelContainer(for: TierItem.self, inMemory: true)
    }
}

struct ItemDetailViewStatusGalleryPreview: PreviewProvider {
    static var previews: some View {
        StatusGalleryView()
            .modelContainer(for: TierItem.self, inMemory: true)
    }
}

struct StatusGalleryView: View {
    let statuses: [(ItemStatus, String)] = [
        (.requirement_input, "Input"),
        (.requirement_review, "Review"),
        (.backlog, "Backlog"),
        (.in_progress, "Progress"),
        (.testing, "Testing"),
        (.completed, "Done"),
        (.blocked, "Blocked")
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 16) {
                ForEach(statuses, id: \.0) { status, label in
                    NavigationLink {
                        ItemDetailView(item: TierItem.makePreviewItem(
                            type: .feature,
                            title: "\(label) Feature Item",
                            status: status,
                            priority: 50
                        ))
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
