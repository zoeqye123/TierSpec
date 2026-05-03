//
//  ItemTypeDTOTests.swift
//  TierSpecTests
//
//  Created for TierSpec
//

import Testing
import Foundation
@testable import TierSpec

@Suite("ItemTypeDTO Tests")
struct ItemTypeDTOTests {
    
    @Test("ItemTypeDTO has exactly 4 cases")
    func testItemTypeDTOHasFourCases() async throws {
        let allCases = ItemTypeDTO.allCases
        #expect(allCases.count == 4, "ItemTypeDTO should have exactly 4 cases, but has \(allCases.count)")
    }
    
    @Test("ItemTypeDTO contains capability case")
    func testCapabilityCaseExists() async throws {
        let capability = ItemTypeDTO.capability
        #expect(capability.displayName == "Capability")
        #expect(capability.rawValue == "capability")
    }
    
    @Test("ItemTypeDTO contains feature case")
    func testFeatureCaseExists() async throws {
        let feature = ItemTypeDTO.feature
        #expect(feature.displayName == "Feature")
        #expect(feature.rawValue == "feature")
    }
    
    @Test("ItemTypeDTO contains userStory case")
    func testUserStoryCaseExists() async throws {
        let userStory = ItemTypeDTO.userStory
        #expect(userStory.displayName == "User Story")
        #expect(userStory.rawValue == "user_story")
    }
    
    @Test("ItemTypeDTO contains testCase case")
    func testTestCaseExists() async throws {
        let testCase = ItemTypeDTO.testCase
        #expect(testCase.displayName == "Test Case")
        #expect(testCase.rawValue == "test_case")
    }
    
    @Test("ItemTypeDTO decodes from JSON correctly")
    func testDecodingFromJSON() async throws {
        let json = #""user_story""#
        let data = json.data(using: .utf8)!
        let type = try JSONDecoder().decode(ItemTypeDTO.self, from: data)
        #expect(type == .userStory)
    }
    
    @Test("ItemTypeDTO encodes to JSON correctly")
    func testEncodingToJSON() async throws {
        let type = ItemTypeDTO.userStory
        let data = try JSONEncoder().encode(type)
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString == #""user_story""#)
    }
}

@Suite("ComplexityDTO Tests")
struct ComplexityDTOTests {
    
    @Test("ComplexityDTO has exactly 5 cases")
    func testComplexityDTOHasFiveCases() async throws {
        let allCases = ComplexityDTO.allCases
        #expect(allCases.count == 5, "ComplexityDTO should have exactly 5 cases, but has \(allCases.count)")
    }
    
    @Test("ComplexityDTO display names")
    func testDisplayNames() async throws {
        #expect(ComplexityDTO.xs.displayName == "XS")
        #expect(ComplexityDTO.s.displayName == "S")
        #expect(ComplexityDTO.m.displayName == "M")
        #expect(ComplexityDTO.l.displayName == "L")
        #expect(ComplexityDTO.xl.displayName == "XL")
    }
    
    @Test("ComplexityDTO default story points follow Fibonacci")
    func testDefaultStoryPoints() async throws {
        #expect(ComplexityDTO.xs.defaultStoryPoints == 1)
        #expect(ComplexityDTO.s.defaultStoryPoints == 2)
        #expect(ComplexityDTO.m.defaultStoryPoints == 3)
        #expect(ComplexityDTO.l.defaultStoryPoints == 5)
        #expect(ComplexityDTO.xl.defaultStoryPoints == 8)
    }
    
    @Test("ComplexityDTO decodes from JSON correctly")
    func testDecodingFromJSON() async throws {
        let json = #""xl""#
        let data = json.data(using: .utf8)!
        let complexity = try JSONDecoder().decode(ComplexityDTO.self, from: data)
        #expect(complexity == .xl)
    }
}
