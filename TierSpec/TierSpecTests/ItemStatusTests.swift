//
//  ItemStatusTests.swift
//  TierSpecTests
//
//  Created for TierSpec
//

import Testing
import Foundation
@testable import TierSpec

@Suite("ItemStatus Tests")
struct ItemStatusTests {
    
    @Test("ItemStatus has exactly 7 cases")
    func testItemStatusHasSevenCases() async throws {
        let allCases = ItemStatus.allCases
        #expect(allCases.count == 7, "ItemStatus should have exactly 7 cases, but has \(allCases.count)")
    }
    
    @Test("ItemStatus contains todo case")
    func testTodoCaseExists() async throws {
        let todo = ItemStatus.todo
        #expect(todo.displayName == "To Do")
        #expect(todo.rawValue == "todo")
    }
    
    @Test("ItemStatus contains in_progress case")
    func testInProgressCaseExists() async throws {
        let inProgress = ItemStatus.in_progress
        #expect(inProgress.displayName == "In Progress")
        #expect(inProgress.rawValue == "in_progress")
    }
    
    @Test("ItemStatus contains test case")
    func testTestCaseExists() async throws {
        let test = ItemStatus.test
        #expect(test.displayName == "Test")
        #expect(test.rawValue == "test")
    }
    
    @Test("ItemStatus contains done case")
    func testDoneCaseExists() async throws {
        let done = ItemStatus.done
        #expect(done.displayName == "Done")
        #expect(done.rawValue == "done")
    }
    
    @Test("ItemStatus contains blocked case")
    func testBlockedCaseExists() async throws {
        let blocked = ItemStatus.blocked
        #expect(blocked.displayName == "Blocked")
        #expect(blocked.rawValue == "blocked")
    }
    
    @Test("ItemStatus contains cancelled case")
    func testCancelledCaseExists() async throws {
        let cancelled = ItemStatus.cancelled
        #expect(cancelled.displayName == "Cancelled")
        #expect(cancelled.rawValue == "cancelled")
    }
    
    @Test("ItemStatus contains needs_info case")
    func testNeedsInfoCaseExists() async throws {
        let needsInfo = ItemStatus.needs_info
        #expect(needsInfo.displayName == "Needs Info")
        #expect(needsInfo.rawValue == "needs_info")
    }
    
    @Test("Terminal states are done and cancelled")
    func testTerminalStates() async throws {
        #expect(ItemStatus.done.isTerminal == true)
        #expect(ItemStatus.cancelled.isTerminal == true)
        #expect(ItemStatus.todo.isTerminal == false)
        #expect(ItemStatus.in_progress.isTerminal == false)
        #expect(ItemStatus.test.isTerminal == false)
        #expect(ItemStatus.blocked.isTerminal == false)
        #expect(ItemStatus.needs_info.isTerminal == false)
    }
    
    @Test("Active states are in_progress and test")
    func testActiveStates() async throws {
        #expect(ItemStatus.in_progress.isActive == true)
        #expect(ItemStatus.test.isActive == true)
        #expect(ItemStatus.todo.isActive == false)
        #expect(ItemStatus.done.isActive == false)
        #expect(ItemStatus.blocked.isActive == false)
        #expect(ItemStatus.cancelled.isActive == false)
        #expect(ItemStatus.needs_info.isActive == false)
    }
}
