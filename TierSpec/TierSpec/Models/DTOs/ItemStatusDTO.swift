//
//  ItemStatusDTO.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/1.
//

import Foundation

/// Data Transfer Object for ItemStatus, matching MCP server JSON responses
/// This enum matches the state machine states from the MCP server
enum ItemStatusDTO: String, Codable, CaseIterable {
    case requirementInput = "requirement_input"
    case requirementReview = "requirement_review"
    case needsInfo = "needs_info"
    case backlog
    case aiDecomposing = "ai_decomposing"
    case inProgress = "in_progress"
    case waitingForTest = "waiting_for_test"
    case testing
    case acceptance
    case completed
    case published
    case blocked
    case cancelled
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .requirementInput:
            return "Requirement Input"
        case .requirementReview:
            return "Requirement Review"
        case .needsInfo:
            return "Needs Info"
        case .backlog:
            return "Backlog"
        case .aiDecomposing:
            return "AI Decomposing"
        case .inProgress:
            return "In Progress"
        case .waitingForTest:
            return "Waiting for Test"
        case .testing:
            return "Testing"
        case .acceptance:
            return "Acceptance"
        case .completed:
            return "Completed"
        case .published:
            return "Published"
        case .blocked:
            return "Blocked"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    /// Whether this is a terminal state (no further transitions)
    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .published:
            return true
        default:
            return false
        }
    }
    
    /// Whether this status indicates active work
    var isActive: Bool {
        switch self {
        case .inProgress, .testing, .aiDecomposing:
            return true
        default:
            return false
        }
    }
}
