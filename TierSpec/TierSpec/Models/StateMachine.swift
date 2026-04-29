//
//  StateMachine.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/26.
//

import Foundation

// MARK: - Actor Type

/// Represents the type of actor performing a state transition
enum ActorType: String, Codable, CaseIterable {
    case human
    case ai
    case system
}

/// Represents the valid transitions in the SDLC workflow
enum StateMachine {
    
    // MARK: - Allowed Transitions
    
    /// Returns the allowed target states for a given current state
    static func allowedTransitions(from currentState: ItemStatus, actorType: ActorType = .human) -> [ItemStatus] {
        if currentState == .cancelled {
            return []
        }
        
        if currentState == .done {
            return [.blocked, .cancelled, .needs_info]
        }
        
        if currentState == .blocked {
            return [.todo, .in_progress, .cancelled, .needs_info]
        }
        
        if currentState == .needs_info {
            return [.todo, .blocked, .cancelled]
        }
        
        let baseTransitions = baseAllowedTransitions(from: currentState, actorType: actorType)
        return baseTransitions + [.blocked, .cancelled, .needs_info]
    }
    
    private static func baseAllowedTransitions(from state: ItemStatus, actorType: ActorType) -> [ItemStatus] {
        switch state {
        case .todo:
            return [.in_progress]
        case .in_progress:
            return [.test]
        case .test:
            let transitions: [ItemStatus] = [.in_progress]
            if actorType == .human {
                return transitions + [.done]
            }
            return transitions
        case .done, .blocked, .cancelled, .needs_info:
            return []
        }
    }
    
    // MARK: - Validation
    
    /// Validates if a transition from one state to another is allowed
    static func isValidTransition(from currentState: ItemStatus, to newState: ItemStatus, actorType: ActorType = .human) -> Bool {
        if currentState == newState {
            return false
        }
        
        if currentState == .cancelled {
            return false
        }
        
        if newState == .blocked || newState == .cancelled || newState == .needs_info {
            return true
        }
        
        if currentState == .blocked {
            return newState == .todo || newState == .in_progress
        }
        
        if currentState == .needs_info {
            return newState == .todo
        }
        
        if currentState == .done {
            return false
        }
        
        if newState == .done && actorType != .human {
            return false
        }
        
        return baseAllowedTransitions(from: currentState, actorType: actorType).contains(newState)
    }
    
    /// Asserts that a transition is valid, throwing an error if not
    static func assertValidTransition(from currentState: ItemStatus, to newState: ItemStatus, actorType: ActorType = .human) throws {
        if currentState == newState {
            throw StateMachineError.alreadyInState(currentState)
        }
        
        if currentState == .cancelled {
            throw StateMachineError.cancelledIsTerminal
        }
        
        if newState == .blocked {
            return
        }
        
        if newState == .cancelled {
            return
        }
        
        if newState == .needs_info {
            return
        }
        
        if currentState == .blocked {
            if newState == .todo || newState == .in_progress {
                return
            }
            throw StateMachineError.invalidBlockedTransition(allowed: [.todo, .in_progress], actual: newState)
        }
        
        if newState == .done && actorType != .human {
            throw StateMachineError.onlyHumanCanTransitionToDone(actorType: actorType)
        }
        
        if currentState == .needs_info {
            if newState == .todo {
                return
            }
            throw StateMachineError.invalidNeedsInfoTransition(allowed: [.todo], actual: newState)
        }
        
        if currentState == .done {
            throw StateMachineError.doneIsTerminal
        }
        
        let allowed = baseAllowedTransitions(from: currentState, actorType: actorType)
        guard allowed.contains(newState) else {
            let allowedWithGlobal = allowed + [.blocked, .cancelled, .needs_info]
            throw StateMachineError.invalidTransition(from: currentState, to: newState, allowed: allowedWithGlobal)
        }
    }
    
    // MARK: - State Properties
    
    /// Returns true if the state is a terminal state (no further transitions possible)
    static func isTerminalState(_ state: ItemStatus) -> Bool {
        return state == .done || state == .cancelled
    }
    
    /// Returns true if the state indicates active work
    static func isActiveState(_ state: ItemStatus) -> Bool {
        return state == .in_progress || state == .test
    }
    
    /// Returns the state group for UI display
    static func stateGroup(for state: ItemStatus) -> StateGroup {
        switch state {
        case .todo, .needs_info:
            return .requirement
        case .in_progress:
            return .execution
        case .test:
            return .execution
        case .done:
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

enum StateMachineError: LocalizedError, Equatable {
    case alreadyInState(ItemStatus)
    case cancelledIsTerminal
    case doneIsTerminal
    case invalidBlockedTransition(allowed: [ItemStatus], actual: ItemStatus)
    case invalidNeedsInfoTransition(allowed: [ItemStatus], actual: ItemStatus)
    case onlyHumanCanTransitionToDone(actorType: ActorType)
    case invalidTransition(from: ItemStatus, to: ItemStatus, allowed: [ItemStatus])
    
    var errorDescription: String? {
        switch self {
        case .alreadyInState(let state):
            return "Item is already in state '\(state.displayName)'"
        case .cancelledIsTerminal:
            return "Cancelled items cannot be transitioned to any other state"
        case .doneIsTerminal:
            return "Items in 'done' can only transition to 'blocked', 'cancelled', or 'needs_info'"
        case .invalidBlockedTransition(let allowed, let actual):
            let allowedNames = allowed.map { $0.displayName }.joined(separator: ", ")
            return "Blocked items can only transition to \(allowedNames). Cannot transition to '\(actual.displayName)'"
        case .invalidNeedsInfoTransition(let allowed, let actual):
            let allowedNames = allowed.map { $0.displayName }.joined(separator: ", ")
            return "Items in 'needs_info' can only transition to \(allowedNames). Cannot transition to '\(actual.displayName)'"
        case .onlyHumanCanTransitionToDone(let actorType):
            return "Only human actors can transition to 'done'. Actor type '\(actorType.rawValue)' is not allowed"
        case .invalidTransition(let from, let to, let allowed):
            let allowedNames = allowed.map { $0.displayName }.joined(separator: ", ")
            return "Cannot transition from '\(from.displayName)' to '\(to.displayName)'. Allowed: \(allowedNames.isEmpty ? "none" : allowedNames)"
        }
    }
}
