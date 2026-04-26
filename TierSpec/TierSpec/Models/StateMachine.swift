//
//  StateMachine.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/26.
//

import Foundation

/// Represents the valid transitions in the SDLC workflow
enum StateMachine {
    
    // MARK: - Allowed Transitions
    
    /// Returns the allowed target states for a given current state
    static func allowedTransitions(from currentState: ItemStatus, previousState: ItemStatus? = nil) -> [ItemStatus] {
        // Blocked items can only return to previous state or be cancelled
        if currentState == .blocked {
            var transitions: [ItemStatus] = []
            if let previous = previousState {
                transitions.append(previous)
            }
            transitions.append(.cancelled)
            return transitions
        }
        
        // Cancelled is a terminal state
        if currentState == .cancelled {
            return []
        }
        
        // Get base allowed transitions
        var transitions = baseAllowedTransitions(from: currentState)
        
        // Add global transitions (blocked and cancelled)
        transitions.append(.blocked)
        transitions.append(.cancelled)
        
        return transitions
    }
    
    /// Base allowed transitions without global states
    private static func baseAllowedTransitions(from state: ItemStatus) -> [ItemStatus] {
        switch state {
        case .requirement_input:
            return [.requirement_review]
        case .requirement_review:
            return [.backlog, .needs_info]
        case .needs_info:
            return []
        case .backlog:
            return [.ai_decomposing]
        case .ai_decomposing:
            return [.backlog]
        case .in_progress:
            return [.waiting_for_test]
        case .waiting_for_test:
            return [.testing]
        case .testing:
            return [.acceptance, .in_progress]
        case .acceptance:
            return [.completed, .in_progress]
        case .completed:
            return [.published]
        case .published:
            return []
        case .blocked, .cancelled:
            return []
        }
    }
    
    // MARK: - Validation
    
    /// Validates if a transition from one state to another is allowed
    static func isValidTransition(from currentState: ItemStatus, to newState: ItemStatus, previousState: ItemStatus? = nil) -> Bool {
        // Same state is not a transition
        if currentState == newState {
            return false
        }
        
        // Can always transition to blocked or cancelled (global states)
        if newState == .blocked || newState == .cancelled {
            return true
        }
        
        // Blocked items must return to previous state
        if currentState == .blocked {
            return previousState == newState
        }
        
        // Check if transition is in allowed list
        return baseAllowedTransitions(from: currentState).contains(newState)
    }
    
    /// Asserts that a transition is valid, throwing an error if not
    static func assertValidTransition(from currentState: ItemStatus, to newState: ItemStatus, previousState: ItemStatus? = nil) throws {
        // Same state
        if currentState == newState {
            throw StateMachineError.alreadyInState(currentState)
        }
        
        // Global transitions
        if newState == .blocked || newState == .cancelled {
            return
        }
        
        // Blocked items
        if currentState == .blocked {
            guard let previous = previousState else {
                throw StateMachineError.missingPreviousState
            }
            guard previous == newState else {
                throw StateMachineError.invalidBlockedTransition(expected: previous, actual: newState)
            }
            return
        }
        
        // Normal transitions
        let allowed = baseAllowedTransitions(from: currentState)
        guard allowed.contains(newState) else {
            let allowedWithGlobal = allowed + [.blocked, .cancelled]
            throw StateMachineError.invalidTransition(from: currentState, to: newState, allowed: allowedWithGlobal)
        }
    }
    
    // MARK: - State Properties
    
    /// Returns true if the state is a terminal state (no further transitions possible)
    static func isTerminalState(_ state: ItemStatus) -> Bool {
        return state == .published || state == .cancelled
    }
    
    /// Returns true if the state indicates active work
    static func isActiveState(_ state: ItemStatus) -> Bool {
        return state == .in_progress || state == .testing || state == .ai_decomposing
    }
    
    /// Returns the state group for UI display
    static func stateGroup(for state: ItemStatus) -> StateGroup {
        switch state {
        case .requirement_input, .requirement_review, .needs_info:
            return .requirement
        case .backlog, .ai_decomposing:
            return .planning
        case .in_progress, .waiting_for_test, .testing, .acceptance:
            return .execution
        case .completed, .published:
            return .completed
        case .blocked:
            return .blocked
        case .cancelled:
            return .cancelled
        }
    }
}

// MARK: - State Group

enum StateGroup: String, CaseIterable {
    case requirement
    case planning
    case execution
    case completed
    case blocked
    case cancelled
    
    var displayName: String {
        switch self {
        case .requirement: return "Requirement"
        case .planning: return "Planning"
        case .execution: return "Execution"
        case .completed: return "Completed"
        case .blocked: return "Blocked"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Errors

enum StateMachineError: LocalizedError {
    case alreadyInState(ItemStatus)
    case missingPreviousState
    case invalidBlockedTransition(expected: ItemStatus, actual: ItemStatus)
    case invalidTransition(from: ItemStatus, to: ItemStatus, allowed: [ItemStatus])
    
    var errorDescription: String? {
        switch self {
        case .alreadyInState(let state):
            return "Item is already in state '\(state.displayName)'"
        case .missingPreviousState:
            return "Blocked item is missing previous state and cannot be restored"
        case .invalidBlockedTransition(let expected, let actual):
            return "Blocked items must transition back to '\(expected.displayName)', received '\(actual.displayName)'"
        case .invalidTransition(let from, let to, let allowed):
            let allowedNames = allowed.map { $0.displayName }.joined(separator: ", ")
            return "Cannot transition from '\(from.displayName)' to '\(to.displayName)'. Allowed: \(allowedNames.isEmpty ? "none" : allowedNames)"
        }
    }
}
