//
//  ItemStatusDTO.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/1.
//

import Foundation

/// Data Transfer Object for ItemStatus, matching MCP server JSON responses
/// This enum matches the 7-state SDLC from the MCP server schema:
/// todo → in_progress → test → done
/// Global states: blocked, cancelled, needs_info
enum ItemStatusDTO: String, Codable, CaseIterable {
    case todo
    case inProgress = "in_progress"
    case test
    case done
    case blocked
    case cancelled
    case needsInfo = "needs_info"
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .todo:
            return "To Do"
        case .inProgress:
            return "In Progress"
        case .test:
            return "Testing"
        case .done:
            return "Done"
        case .blocked:
            return "Blocked"
        case .cancelled:
            return "Cancelled"
        case .needsInfo:
            return "Needs Info"
        }
    }
    
    /// Whether this is a terminal state (no further transitions)
    var isTerminal: Bool {
        switch self {
        case .done, .cancelled:
            return true
        default:
            return false
        }
    }
    
    /// Whether this status indicates active work
    var isActive: Bool {
        switch self {
        case .inProgress, .test:
            return true
        default:
            return false
        }
    }
    
    /// Valid next states from this state
    var validTransitions: [ItemStatusDTO] {
        switch self {
        case .todo:
            return [.inProgress, .blocked, .cancelled, .needsInfo]
        case .inProgress:
            return [.test, .blocked, .cancelled, .needsInfo, .todo]
        case .test:
            return [.done, .inProgress, .blocked, .cancelled, .needsInfo]
        case .done:
            return []  // Terminal state
        case .blocked:
            return [.todo, .inProgress, .test, .cancelled, .needsInfo]  // Return to previous state
        case .cancelled:
            return []  // Terminal state
        case .needsInfo:
            return [.todo, .inProgress, .blocked, .cancelled]
        }
    }
    
    /// Check if transition to a new state is valid
    func canTransition(to newState: ItemStatusDTO) -> Bool {
        return validTransitions.contains(newState)
    }
}
