//
//  ItemStatusDTOTests.swift
//  TierSpecTests
//
//  Created for TierSpec
//

import Testing
import Foundation
@testable import TierSpec

@Suite("ItemStatusDTO Tests")
struct ItemStatusDTOTests {
    
    @Test("ItemStatusDTO has exactly 7 cases")
    func testItemStatusDTOHasSevenCases() async throws {
        let allCases = ItemStatusDTO.allCases
        #expect(allCases.count == 7, "ItemStatusDTO should have exactly 7 cases, but has \(allCases.count)")
    }
    
    @Test("ItemStatusDTO contains todo case")
    func testTodoCaseExists() async throws {
        let todo = ItemStatusDTO.todo
        #expect(todo.displayName == "To Do")
        #expect(todo.rawValue == "todo")
    }
    
    @Test("ItemStatusDTO contains inProgress case")
    func testInProgressCaseExists() async throws {
        let inProgress = ItemStatusDTO.inProgress
        #expect(inProgress.displayName == "In Progress")
        #expect(inProgress.rawValue == "in_progress")
    }
    
    @Test("ItemStatusDTO contains test case")
    func testTestCaseExists() async throws {
        let test = ItemStatusDTO.test
        #expect(test.displayName == "Testing")
        #expect(test.rawValue == "test")
    }
    
    @Test("ItemStatusDTO contains done case")
    func testDoneCaseExists() async throws {
        let done = ItemStatusDTO.done
        #expect(done.displayName == "Done")
        #expect(done.rawValue == "done")
    }
    
    @Test("ItemStatusDTO contains blocked case")
    func testBlockedCaseExists() async throws {
        let blocked = ItemStatusDTO.blocked
        #expect(blocked.displayName == "Blocked")
        #expect(blocked.rawValue == "blocked")
    }
    
    @Test("ItemStatusDTO contains cancelled case")
    func testCancelledCaseExists() async throws {
        let cancelled = ItemStatusDTO.cancelled
        #expect(cancelled.displayName == "Cancelled")
        #expect(cancelled.rawValue == "cancelled")
    }
    
    @Test("ItemStatusDTO contains needsInfo case")
    func testNeedsInfoCaseExists() async throws {
        let needsInfo = ItemStatusDTO.needsInfo
        #expect(needsInfo.displayName == "Needs Info")
        #expect(needsInfo.rawValue == "needs_info")
    }
    
    @Test("Terminal states are done and cancelled")
    func testTerminalStates() async throws {
        #expect(ItemStatusDTO.done.isTerminal == true)
        #expect(ItemStatusDTO.cancelled.isTerminal == true)
        #expect(ItemStatusDTO.todo.isTerminal == false)
        #expect(ItemStatusDTO.inProgress.isTerminal == false)
        #expect(ItemStatusDTO.test.isTerminal == false)
        #expect(ItemStatusDTO.blocked.isTerminal == false)
        #expect(ItemStatusDTO.needsInfo.isTerminal == false)
    }
    
    @Test("Active states are inProgress and test")
    func testActiveStates() async throws {
        #expect(ItemStatusDTO.inProgress.isActive == true)
        #expect(ItemStatusDTO.test.isActive == true)
        #expect(ItemStatusDTO.todo.isActive == false)
        #expect(ItemStatusDTO.done.isActive == false)
        #expect(ItemStatusDTO.blocked.isActive == false)
        #expect(ItemStatusDTO.cancelled.isActive == false)
        #expect(ItemStatusDTO.needsInfo.isActive == false)
    }
    
    @Test("Valid transitions from todo")
    func testValidTransitionsFromTodo() async throws {
        let todo = ItemStatusDTO.todo
        #expect(todo.canTransition(to: .inProgress) == true)
        #expect(todo.canTransition(to: .blocked) == true)
        #expect(todo.canTransition(to: .cancelled) == true)
        #expect(todo.canTransition(to: .needsInfo) == true)
        #expect(todo.canTransition(to: .test) == false)
        #expect(todo.canTransition(to: .done) == false)
    }
    
    @Test("Valid transitions from inProgress")
    func testValidTransitionsFromInProgress() async throws {
        let inProgress = ItemStatusDTO.inProgress
        #expect(inProgress.canTransition(to: .test) == true)
        #expect(inProgress.canTransition(to: .todo) == true)
        #expect(inProgress.canTransition(to: .blocked) == true)
        #expect(inProgress.canTransition(to: .cancelled) == true)
        #expect(inProgress.canTransition(to: .needsInfo) == true)
        #expect(inProgress.canTransition(to: .done) == false)
    }
    
    @Test("Valid transitions from test")
    func testValidTransitionsFromTest() async throws {
        let test = ItemStatusDTO.test
        #expect(test.canTransition(to: .done) == true)
        #expect(test.canTransition(to: .inProgress) == true)
        #expect(test.canTransition(to: .blocked) == true)
        #expect(test.canTransition(to: .cancelled) == true)
        #expect(test.canTransition(to: .needsInfo) == true)
        #expect(test.canTransition(to: .todo) == false)
    }
    
    @Test("No transitions from terminal states")
    func testNoTransitionsFromTerminalStates() async throws {
        #expect(ItemStatusDTO.done.validTransitions.isEmpty == true)
        #expect(ItemStatusDTO.cancelled.validTransitions.isEmpty == true)
    }
    
    @Test("ItemStatusDTO decodes from JSON correctly")
    func testDecodingFromJSON() async throws {
        let json = #""in_progress""#
        let data = json.data(using: .utf8)!
        let status = try JSONDecoder().decode(ItemStatusDTO.self, from: data)
        #expect(status == .inProgress)
    }
    
    @Test("ItemStatusDTO encodes to JSON correctly")
    func testEncodingToJSON() async throws {
        let status = ItemStatusDTO.inProgress
        let data = try JSONEncoder().encode(status)
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString == #""in_progress""#)
    }
}
