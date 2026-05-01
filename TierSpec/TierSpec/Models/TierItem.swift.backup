//
//  TierItem.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import Foundation
import SwiftData
import SwiftUI

/// Represents an item in the TierSpec hierarchy
@Model
final class TierItem {
    // MARK: - Identity
    
    /// Unique identifier
    var id: UUID
    
    /// Type of this item (capability, feature, epic, story, test_case)
    var type: ItemType
    
    // MARK: - Hierarchy Relationships
    
    /// Parent item (nil for root capabilities)
    var parent: TierItem? = nil
    
    /// Child items
    @Relationship(inverse: \TierItem.parent)
    var children: [TierItem]? = []
    
    var sprint: Sprint?
    
    // MARK: - Content
    
    /// Item title
    var title: String
    
    /// Detailed description
    var itemDescription: String?
    
    /// Current status in SDLC
    var status: ItemStatus
    
    /// Priority (0-100)
    var priority: Int
    
    /// Position for ordering within parent (supports drag-drop)
    var position: Double
    
    // MARK: - Estimation
    
    /// Story points estimate
    var storyPoints: Int?
    
    /// Complexity level
    var complexity: Complexity?
    
    // MARK: - AI Metadata
    
    /// Whether this item was AI-generated
    var aiGenerated: Bool
    
    /// AI confidence score (0.0 - 1.0)
    var aiConfidence: Double?
    
    /// AI reasoning for suggestions
    var aiReasoning: String?
    
    // MARK: - Timestamps
    
    /// Creation timestamp
    var createdAt: Date
    
    /// Last update timestamp
    var updatedAt: Date
    
    /// Soft delete timestamp
    var deletedAt: Date?
    
    /// Display ID for user-friendly identification (e.g., "CAP-001", "FEAT-042")
    var displayId: String?
    
    // MARK: - Labels
    
    /// Labels/tags for categorization
    var labels: [String]
    
    // MARK: - Cached Properties
    
    @Transient private var cachedOutlineChildren: [TierItem]?
    @Transient private var cachedDepth: Int?
    @Transient private var cachedPath: [TierItem]?
    
    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        type: ItemType,
        title: String,
        description: String? = nil,
        status: ItemStatus = .todo,
        priority: Int = 0,
        position: Double = 0,
        storyPoints: Int? = nil,
        complexity: Complexity? = nil,
        aiGenerated: Bool = false,
        aiConfidence: Double? = nil,
        aiReasoning: String? = nil,
        labels: [String] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.itemDescription = description
        self.status = status
        self.priority = priority
        self.position = position
        self.storyPoints = storyPoints
        self.complexity = complexity
        self.aiGenerated = aiGenerated
        self.aiConfidence = aiConfidence
        self.aiReasoning = aiReasoning
        self.labels = labels
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var outlineChildren: [TierItem] {
        if let cached = cachedOutlineChildren {
            return cached
        }
        let result = (children ?? [])
            .filter { $0.deletedAt == nil }
            .sorted { $0.position < $1.position }
        cachedOutlineChildren = result
        return result
    }
    
    var depth: Int {
        if let cached = cachedDepth {
            return cached
        }
        var currentDepth = 0
        var currentParent = parent
        while currentParent != nil {
            currentDepth += 1
            currentParent = currentParent?.parent
        }
        cachedDepth = currentDepth
        return currentDepth
    }
    
    /// Whether this item can have children
    var canHaveChildren: Bool {
        return !type.allowedChildTypes.isEmpty
    }
    
    /// Whether this item is a root (capability without parent)
    var isRoot: Bool {
        return parent == nil && type == .capability
    }
    
    /// Whether this item is deleted
    var isDeleted: Bool {
        return deletedAt != nil
    }
    
    var path: [TierItem] {
        if let cached = cachedPath {
            return cached
        }
        var result: [TierItem] = [self]
        var currentParent = parent
        while let parent = currentParent {
            result.insert(parent, at: 0)
            currentParent = parent.parent
        }
        cachedPath = result
        return result
    }
    
    // MARK: - Methods
    
    func invalidateCache() {
        cachedOutlineChildren = nil
        cachedDepth = nil
        cachedPath = nil
    }
    
    func touch() {
        updatedAt = Date()
        invalidateCache()
    }
    
    func softDelete() {
        deletedAt = Date()
        touch()
    }
    
    func restore() {
        deletedAt = nil
        touch()
    }
    
    /// Check if a child type is valid for this item
    func canAddChild(ofType childType: ItemType) -> Bool {
        return type.allowedChildTypes.contains(childType)
    }
}

extension Complexity {
    var color: SwiftUI.Color {
        switch self {
        case .xs: return .green
        case .s: return .mint
        case .m: return .yellow
        case .l: return .orange
        case .xl: return .red
        }
    }
}

// MARK: - Complexity Enum

/// Complexity levels for estimation
enum Complexity: String, Codable, CaseIterable {
    case xs
    case s
    case m
    case l
    case xl
    
    var displayName: String {
        switch self {
        case .xs: return "XS"
        case .s: return "S"
        case .m: return "M"
        case .l: return "L"
        case .xl: return "XL"
        }
    }
    
    var defaultStoryPoints: Int {
        switch self {
        case .xs: return 1
        case .s: return 2
        case .m: return 3
        case .l: return 5
        case .xl: return 8
        }
    }
}
