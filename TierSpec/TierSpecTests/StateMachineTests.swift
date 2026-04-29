//
//  StateMachineTests.swift
//  TierSpecTests
//
//  Created for TierSpec
//

import Testing
import Foundation
@testable import TierSpec

@Suite("StateMachine Tests")
struct StateMachineTests {
    
    // MARK: - ActorType Tests
    
    @Test("ActorType has exactly 3 cases")
    func testActorTypeHasThreeCases() async throws {
        let allCases = ActorType.allCases
        #expect(allCases.count == 3, "ActorType should have exactly 3 cases")
    }
    
    @Test("ActorType contains human, ai, and system")
    func testActorTypeCases() async throws {
        #expect(ActorType.human.rawValue == "human")
        #expect(ActorType.ai.rawValue == "ai")
        #expect(ActorType.system.rawValue == "system")
    }
    
    // MARK: - Allowed Transitions Tests
    
    @Test("Todo can transition to in_progress")
    func testTodoTransitions() async throws {
        let transitions = StateMachine.allowedTransitions(from: .todo)
        #expect(transitions.contains(.in_progress))
        #expect(transitions.contains(.blocked))
        #expect(transitions.contains(.cancelled))
        #expect(transitions.contains(.needs_info))
        #expect(!transitions.contains(.done))
        #expect(!transitions.contains(.test))
    }
    
    @Test("In_progress can transition to test")
    func testInProgressTransitions() async throws {
        let transitions = StateMachine.allowedTransitions(from: .in_progress)
        #expect(transitions.contains(.test))
        #expect(transitions.contains(.blocked))
        #expect(transitions.contains(.cancelled))
        #expect(transitions.contains(.needs_info))
        #expect(!transitions.contains(.done))
        #expect(!transitions.contains(.todo))
    }
    
    @Test("Test can transition to in_progress and done (human only)")
    func testTestTransitions() async throws {
        let humanTransitions = StateMachine.allowedTransitions(from: .test, actorType: .human)
        #expect(humanTransitions.contains(.in_progress))
        #expect(humanTransitions.contains(.done))
        #expect(humanTransitions.contains(.blocked))
        #expect(humanTransitions.contains(.cancelled))
        
        let aiTransitions = StateMachine.allowedTransitions(from: .test, actorType: .ai)
        #expect(aiTransitions.contains(.in_progress))
        #expect(!aiTransitions.contains(.done))
        
        let systemTransitions = StateMachine.allowedTransitions(from: .test, actorType: .system)
        #expect(systemTransitions.contains(.in_progress))
        #expect(!systemTransitions.contains(.done))
    }
    
    @Test("Done can only transition to auxiliary states")
    func testDoneTransitions() async throws {
        let transitions = StateMachine.allowedTransitions(from: .done)
        #expect(transitions.contains(.blocked))
        #expect(transitions.contains(.cancelled))
        #expect(transitions.contains(.needs_info))
        #expect(!transitions.contains(.todo))
        #expect(!transitions.contains(.in_progress))
        #expect(!transitions.contains(.test))
    }
    
    @Test("Blocked can transition to todo or in_progress")
    func testBlockedTransitions() async throws {
        let transitions = StateMachine.allowedTransitions(from: .blocked)
        #expect(transitions.contains(.todo))
        #expect(transitions.contains(.in_progress))
        #expect(transitions.contains(.cancelled))
        #expect(transitions.contains(.needs_info))
        #expect(!transitions.contains(.done))
        #expect(!transitions.contains(.test))
    }
    
    @Test("Cancelled is terminal state")
    func testCancelledTransitions() async throws {
        let transitions = StateMachine.allowedTransitions(from: .cancelled)
        #expect(transitions.isEmpty)
    }
    
    @Test("Needs_info can transition to todo")
    func testNeedsInfoTransitions() async throws {
        let transitions = StateMachine.allowedTransitions(from: .needs_info)
        #expect(transitions.contains(.todo))
        #expect(transitions.contains(.blocked))
        #expect(transitions.contains(.cancelled))
        #expect(!transitions.contains(.in_progress))
        #expect(!transitions.contains(.test))
        #expect(!transitions.contains(.done))
    }
    
    // MARK: - isValidTransition Tests
    
    @Test("Same state is not a valid transition")
    func testSameStateInvalid() async throws {
        #expect(!StateMachine.isValidTransition(from: .todo, to: .todo))
        #expect(!StateMachine.isValidTransition(from: .in_progress, to: .in_progress))
    }
    
    @Test("Global transitions are always valid")
    func testGlobalTransitions() async throws {
        #expect(StateMachine.isValidTransition(from: .todo, to: .blocked))
        #expect(StateMachine.isValidTransition(from: .todo, to: .cancelled))
        #expect(StateMachine.isValidTransition(from: .todo, to: .needs_info))
        #expect(StateMachine.isValidTransition(from: .in_progress, to: .blocked))
        #expect(StateMachine.isValidTransition(from: .test, to: .cancelled))
    }
    
    @Test("Only human can transition to done")
    func testOnlyHumanCanTransitionToDone() async throws {
        #expect(StateMachine.isValidTransition(from: .test, to: .done, actorType: .human))
        #expect(!StateMachine.isValidTransition(from: .test, to: .done, actorType: .ai))
        #expect(!StateMachine.isValidTransition(from: .test, to: .done, actorType: .system))
    }
    
    @Test("Cancelled cannot transition to any state")
    func testCancelledCannotTransition() async throws {
        #expect(!StateMachine.isValidTransition(from: .cancelled, to: .todo))
        #expect(!StateMachine.isValidTransition(from: .cancelled, to: .blocked))
        #expect(!StateMachine.isValidTransition(from: .cancelled, to: .needs_info))
    }
    
    @Test("Blocked can transition to todo or in_progress")
    func testBlockedValidTransitions() async throws {
        #expect(StateMachine.isValidTransition(from: .blocked, to: .todo))
        #expect(StateMachine.isValidTransition(from: .blocked, to: .in_progress))
        #expect(!StateMachine.isValidTransition(from: .blocked, to: .test))
        #expect(!StateMachine.isValidTransition(from: .blocked, to: .done))
    }
    
    // MARK: - assertValidTransition Tests
    
    @Test("assertValidTransition throws for same state")
    func testAssertSameStateThrows() async throws {
        await #expect(throws: StateMachineError.alreadyInState(.todo)) {
            try StateMachine.assertValidTransition(from: .todo, to: .todo)
        }
    }
    
    @Test("assertValidTransition throws for cancelled as source")
    func testAssertCancelledThrows() async throws {
        await #expect(throws: StateMachineError.cancelledIsTerminal) {
            try StateMachine.assertValidTransition(from: .cancelled, to: .todo)
        }
    }
    
    @Test("assertValidTransition throws when AI tries to transition to done")
    func testAssertAICannotTransitionToDone() async throws {
        await #expect(throws: StateMachineError.onlyHumanCanTransitionToDone(actorType: .ai)) {
            try StateMachine.assertValidTransition(from: .test, to: .done, actorType: .ai)
        }
        
        await #expect(throws: StateMachineError.onlyHumanCanTransitionToDone(actorType: .system)) {
            try StateMachine.assertValidTransition(from: .test, to: .done, actorType: .system)
        }
    }
    
    @Test("assertValidTransition succeeds for human transitioning to done")
    func testAssertHumanCanTransitionToDone() async throws {
        #expect(throws: Never.self) {
            try StateMachine.assertValidTransition(from: .test, to: .done, actorType: .human)
        }
    }
    
    @Test("assertValidTransition throws for invalid transition")
    func testAssertInvalidTransitionThrows() async throws {
        await #expect(throws: StateMachineError.self) {
            try StateMachine.assertValidTransition(from: .todo, to: .done)
        }
    }
    
    @Test("assertValidTransition succeeds for global transitions")
    func testAssertGlobalTransitionsSucceed() async throws {
        #expect(throws: Never.self) {
            try StateMachine.assertValidTransition(from: .todo, to: .blocked)
            try StateMachine.assertValidTransition(from: .in_progress, to: .cancelled)
            try StateMachine.assertValidTransition(from: .test, to: .needs_info)
        }
    }
    
    // MARK: - State Properties Tests
    
    @Test("isTerminalState returns correct values")
    func testIsTerminalState() async throws {
        #expect(StateMachine.isTerminalState(.done) == true)
        #expect(StateMachine.isTerminalState(.cancelled) == true)
        #expect(StateMachine.isTerminalState(.todo) == false)
        #expect(StateMachine.isTerminalState(.in_progress) == false)
        #expect(StateMachine.isTerminalState(.test) == false)
        #expect(StateMachine.isTerminalState(.blocked) == false)
        #expect(StateMachine.isTerminalState(.needs_info) == false)
    }
    
    @Test("isActiveState returns correct values")
    func testIsActiveState() async throws {
        #expect(StateMachine.isActiveState(.in_progress) == true)
        #expect(StateMachine.isActiveState(.test) == true)
        #expect(StateMachine.isActiveState(.todo) == false)
        #expect(StateMachine.isActiveState(.done) == false)
        #expect(StateMachine.isActiveState(.blocked) == false)
        #expect(StateMachine.isActiveState(.cancelled) == false)
        #expect(StateMachine.isActiveState(.needs_info) == false)
    }
    
    @Test("stateGroup returns correct groups")
    func testStateGroup() async throws {
        #expect(StateMachine.stateGroup(for: .todo) == .requirement)
        #expect(StateMachine.stateGroup(for: .needs_info) == .requirement)
        #expect(StateMachine.stateGroup(for: .in_progress) == .execution)
        #expect(StateMachine.stateGroup(for: .test) == .execution)
        #expect(StateMachine.stateGroup(for: .done) == .completed)
        #expect(StateMachine.stateGroup(for: .blocked) == .blocked)
        #expect(StateMachine.stateGroup(for: .cancelled) == .cancelled)
    }
}
