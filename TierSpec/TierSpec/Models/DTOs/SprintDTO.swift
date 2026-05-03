//
//  SprintDTO.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/1.
//

import Foundation

/// Data Transfer Object for Sprint, matching MCP server JSON responses
/// This is a plain struct without SwiftData annotations, used for decoding JSON from the MCP server
struct SprintDTO: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Identity
    
    /// Unique identifier
    let id: UUID
    
    // MARK: - Content
    
    /// Sprint name
    let name: String
    
    /// Sprint description
    let description: String?
    
    // MARK: - Schedule
    
    /// Sprint start date
    let startDate: Date
    
    /// Sprint end date
    let endDate: Date
    
    // MARK: - Capacity
    
    /// Total capacity in story points
    let capacityPoints: Int
    
    /// Current sprint status
    var status: SprintStatusDTO
    
    /// Committed story points
    let committedPoints: Int
    
    /// Completed story points
    let completedPoints: Int
    
    // MARK: - Timestamps
    
    /// Creation timestamp
    let createdAt: Date
    
    /// Last update timestamp
    let updatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Items assigned to this sprint (populated after decoding, not from JSON)
    var items: [TierItemDTO] = []
    
    // MARK: - CodingKeys
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case capacityPoints = "capacity_points"
        case status
        case committedPoints = "committed_points"
        case completedPoints = "completed_points"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - SprintStatusDTO

/// Sprint status enum matching MCP server SprintStatus
enum SprintStatusDTO: String, Codable, CaseIterable {
    case planning
    case active
    case completed
    case cancelled
    
    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}
