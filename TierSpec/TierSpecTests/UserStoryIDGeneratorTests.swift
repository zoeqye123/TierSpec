//
//  UserStoryIDGeneratorTests.swift
//  TierSpecTests
//
//  Created by z on 2026/4/29.
//

import Testing
import SwiftData
import Foundation
@testable import TierSpec

@MainActor
struct UserStoryIDGeneratorTests {
    
    private func createTestProject() -> Project {
        Project(name: "Test Project", databasePath: "/tmp/test.db")
    }
    
    @Test func generatesSequentialIDs() async throws {
        let project = createTestProject()
        let generator = UserStoryIDGenerator()
        
        let id1 = generator.generate(for: project)
        let id2 = generator.generate(for: project)
        
        #expect(id1 == "US-001")
        #expect(id2 == "US-002")
        #expect(project.lastUserStoryNumber == 2)
    }
    
    @Test func formatsIDWithThreeDigitPadding() async throws {
        let project = createTestProject()
        project.lastUserStoryNumber = 0
        let generator = UserStoryIDGenerator()
        
        #expect(generator.generate(for: project) == "US-001")
        #expect(generator.generate(for: project) == "US-002")
        #expect(generator.generate(for: project) == "US-003")
    }
    
    @Test func handlesLargeNumbersOver999() async throws {
        let project = createTestProject()
        project.lastUserStoryNumber = 998
        let generator = UserStoryIDGenerator()
        
        #expect(generator.generate(for: project) == "US-999")
        #expect(generator.generate(for: project) == "US-1000")
        #expect(generator.generate(for: project) == "US-1001")
        #expect(project.lastUserStoryNumber == 1001)
    }
    
    @Test func generateIfNeededReturnsNilForNonUserStory() async throws {
        let project = createTestProject()
        let generator = UserStoryIDGenerator()
        
        let capability = TierItem(type: .capability, title: "Capability")
        let feature = TierItem(type: .feature, title: "Feature")
        let testCase = TierItem(type: .test_case, title: "Test Case")
        
        #expect(generator.generateIfNeeded(for: capability, in: project) == nil)
        #expect(generator.generateIfNeeded(for: feature, in: project) == nil)
        #expect(generator.generateIfNeeded(for: testCase, in: project) == nil)
        #expect(project.lastUserStoryNumber == 0)
    }
    
    @Test func generateIfNeededReturnsIDForUserStory() async throws {
        let project = createTestProject()
        let generator = UserStoryIDGenerator()
        
        let userStory = TierItem(type: .user_story, title: "User Story")
        
        let id = generator.generateIfNeeded(for: userStory, in: project)
        
        #expect(id == "US-001")
        #expect(project.lastUserStoryNumber == 1)
    }
    
    @Test func multipleGenerationsIncrementCounter() async throws {
        let project = createTestProject()
        let generator = UserStoryIDGenerator()
        
        for i in 1...10 {
            let id = generator.generate(for: project)
            let expected = String(format: "US-%03d", i)
            #expect(id == expected)
        }
        
        #expect(project.lastUserStoryNumber == 10)
    }
}
