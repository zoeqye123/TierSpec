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
    case todo
    case in_progress
    case test
    case done
    case blocked
    case cancelled
    case needs_info
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .todo:
            return "To Do"
        case .in_progress:
            return "In Progress"
        case .test:
            return "Test"
        case .done:
            return "Done"
        case .blocked:
            return "Blocked"
        case .cancelled:
            return "Cancelled"
        case .needs_info:
            return "Needs Info"
        }
    }
    
    /// Color for status indicator
    var color: Color {
        switch self {
        case .todo:
            return .secondary
        case .in_progress:
            return .blue
        case .test:
            return .indigo
        case .done:
            return .green
        case .blocked:
            return .red
        case .cancelled:
            return .gray
        case .needs_info:
            return .yellow
        }
    }
    
    /// SF Symbol icon for status
    var icon: String {
        switch self {
        case .todo:
            return "circle"
        case .in_progress:
            return "play.circle"
        case .test:
            return "testtube.2"
        case .done:
            return "checkmark.circle"
        case .blocked:
            return "xmark.octagon"
        case .cancelled:
            return "xmark.circle"
        case .needs_info:
            return "exclamationmark.circle"
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
        case .in_progress, .test:
            return true
        default:
            return false
        }
    }
}
