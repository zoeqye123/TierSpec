//
//  ItemStatus.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import Foundation
import SwiftUI

/// Represents the SDLC status of an item
enum ItemStatus: String, Codable, CaseIterable {
    case requirement_input
    case requirement_review
    case needs_info
    case backlog
    case ai_decomposing
    case in_progress
    case waiting_for_test
    case testing
    case acceptance
    case completed
    case published
    case blocked
    case cancelled
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .requirement_input:
            return "Requirement Input"
        case .requirement_review:
            return "Requirement Review"
        case .needs_info:
            return "Needs Info"
        case .backlog:
            return "Backlog"
        case .ai_decomposing:
            return "AI Decomposing"
        case .in_progress:
            return "In Progress"
        case .waiting_for_test:
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
    
    /// Color for status indicator
    var color: Color {
        switch self {
        case .requirement_input:
            return .gray
        case .requirement_review:
            return .orange
        case .needs_info:
            return .yellow
        case .backlog:
            return .secondary
        case .ai_decomposing:
            return .purple
        case .in_progress:
            return .blue
        case .waiting_for_test:
            return .cyan
        case .testing:
            return .indigo
        case .acceptance:
            return .mint
        case .completed:
            return .green
        case .published:
            return .teal
        case .blocked:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    /// SF Symbol icon for status
    var icon: String {
        switch self {
        case .requirement_input:
            return "pencil.and.list.clipboard"
        case .requirement_review:
            return "doc.text.magnifyingglass"
        case .needs_info:
            return "exclamationmark.circle"
        case .backlog:
            return "tray"
        case .ai_decomposing:
            return "cpu"
        case .in_progress:
            return "play.circle"
        case .waiting_for_test:
            return "hourglass"
        case .testing:
            return "testtube.2"
        case .acceptance:
            return "checkmark.seal"
        case .completed:
            return "checkmark.circle"
        case .published:
            return "cloud.upload"
        case .blocked:
            return "xmark.octagon"
        case .cancelled:
            return "xmark.circle"
        }
    }
    
    /// Whether this is a terminal state (no further transitions)
    var isTerminal: Bool {
        switch self {
        case .published, .cancelled:
            return true
        default:
            return false
        }
    }
    
    /// Whether this status indicates active work
    var isActive: Bool {
        switch self {
        case .in_progress, .testing, .ai_decomposing:
            return true
        default:
            return false
        }
    }
}
