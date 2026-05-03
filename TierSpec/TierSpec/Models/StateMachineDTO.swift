//
//  StateMachineDTO.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/1.
//

import Foundation

enum ActorTypeDTO: String, Codable, CaseIterable {
    case human
    case ai
    case system
}

enum StateMachineDTO {
    
    /// Returns valid transitions from a given state
    /// Matches MCP server's 7-state schema: todo → in_progress → test → done
    /// Global states: blocked, cancelled, needs_info
    static func allowedTransitions(from currentState: ItemStatusDTO, actorType: ActorTypeDTO = .human) -> [ItemStatusDTO] {
        switch currentState {
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
    
    static func isValidTransition(from currentState: ItemStatusDTO, to newState: ItemStatusDTO, actorType: ActorTypeDTO = .human) -> Bool {
        if currentState == newState {
            return false
        }
        
        if currentState == .cancelled {
            return false
        }
        
        // Only human actors can transition to done
        if newState == .done && actorType != .human {
            return false
        }
        
        return allowedTransitions(from: currentState, actorType: actorType).contains(newState)
    }
    
    static func assertValidTransition(from currentState: ItemStatusDTO, to newState: ItemStatusDTO, actorType: ActorTypeDTO = .human) throws {
        if currentState == newState {
            throw StateMachineDTOError.alreadyInState(currentState)
        }
        
        if currentState == .cancelled {
            throw StateMachineDTOError.cancelledIsTerminal
        }
        
        if newState == .done && actorType != .human {
            throw StateMachineDTOError.onlyHumanCanTransitionToDone(actorType: actorType)
        }
        
        let allowed = allowedTransitions(from: currentState, actorType: actorType)
        guard allowed.contains(newState) else {
            throw StateMachineDTOError.invalidTransition(from: currentState, to: newState, allowed: allowed)
        }
    }
    
    static func isTerminalState(_ state: ItemStatusDTO) -> Bool {
        return state == .done || state == .cancelled
    }
    
    static func isActiveState(_ state: ItemStatusDTO) -> Bool {
        return state == .inProgress || state == .test
    }
}

enum StateGroupDTO: String, CaseIterable {
    case planning
    case execution
    case completed
    case blocked
    case cancelled
    
    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .execution: return "Execution"
        case .completed: return "Completed"
        case .blocked: return "Blocked"
        case .cancelled: return "Cancelled"
        }
    }
}

enum StateMachineDTOError: LocalizedError, Equatable {
    case alreadyInState(ItemStatusDTO)
    case cancelledIsTerminal
    case onlyHumanCanTransitionToDone(actorType: ActorTypeDTO)
    case invalidTransition(from: ItemStatusDTO, to: ItemStatusDTO, allowed: [ItemStatusDTO])
    
    var errorDescription: String? {
        switch self {
        case .alreadyInState(let state):
            return "Item is already in state '\(state.displayName)'"
        case .cancelledIsTerminal:
            return "Cancelled items cannot be transitioned to any other state"
        case .onlyHumanCanTransitionToDone(let actorType):
            return "Only human actors can transition to 'done'. Actor type '\(actorType.rawValue)' is not allowed"
        case .invalidTransition(let from, let to, let allowed):
            let allowedNames = allowed.map { $0.displayName }.joined(separator: ", ")
            return "Cannot transition from '\(from.displayName)' to '\(to.displayName)'. Allowed: \(allowedNames.isEmpty ? "none" : allowedNames)"
        }
    }
}