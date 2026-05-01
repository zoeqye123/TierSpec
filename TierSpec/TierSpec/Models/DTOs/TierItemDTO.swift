//
//  TierItemDTO.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/1.
//

import Foundation

/// Data Transfer Object for TierItem, matching MCP server JSON responses
/// This is a plain struct without SwiftData annotations, used for decoding JSON from the MCP server
struct TierItemDTO: Identifiable, Codable, Equatable {
    // MARK: - Identity
    
    /// Unique identifier
    let id: UUID
    
    /// Type of this item (capability, feature, epic, story, test_case)
    let type: ItemTypeDTO
    
    // MARK: - Hierarchy Relationships
    
    /// Parent item ID (nil for root capabilities)
    let parentId: UUID?
    
    /// Sprint ID if assigned to a sprint
    let sprintId: UUID?
    
    // MARK: - Content
    
    /// Item title
    let title: String
    
    /// Detailed description
    let description: String?
    
    /// Current status in SDLC
    let status: ItemStatusDTO
    
    /// Priority (0-100)
    let priority: Int
    
    /// Position for ordering within parent (supports drag-drop)
    let position: Double
    
    // MARK: - Estimation
    
    /// Story points estimate
    let storyPoints: Int?
    
    /// Complexity level
    let complexity: ComplexityDTO?
    
    // MARK: - AI Metadata
    
    /// Whether this item was AI-generated
    let aiGenerated: Bool
    
    /// AI confidence score (0.0 - 1.0)
    let aiConfidence: Double?
    
    /// AI reasoning for suggestions
    let aiReasoning: String?
    
    // MARK: - Labels
    
    /// Labels/tags for categorization
    let labels: [String]
    
    // MARK: - Timestamps
    
    /// Creation timestamp
    let createdAt: Date
    
    /// Last update timestamp
    let updatedAt: Date
    
    /// Soft delete timestamp
    let deletedAt: Date?
    
    // MARK: - Computed Properties
    
    /// Child items (populated after decoding, not from JSON)
    var children: [TierItemDTO] = []
    
    // MARK: - CodingKeys
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case parentId = "parent_id"
        case sprintId = "sprint_id"
        case title
        case description
        case status
        case priority
        case position
        case storyPoints = "story_points"
        case complexity
        case aiGenerated = "ai_generated"
        case aiConfidence = "ai_confidence"
        case aiReasoning = "ai_reasoning"
        case labels
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - ItemTypeDTO

/// Item type enum matching MCP server ItemType
enum ItemTypeDTO: String, Codable, CaseIterable {
    case capability
    case feature
    case userStory = "user_story"
    case testCase = "test_case"
    
    var displayName: String {
        switch self {
        case .capability: return "Capability"
        case .feature: return "Feature"
        case .userStory: return "User Story"
        case .testCase: return "Test Case"
        }
    }
}

// MARK: - ComplexityDTO

/// Complexity levels for estimation
enum ComplexityDTO: String, Codable, CaseIterable {
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
