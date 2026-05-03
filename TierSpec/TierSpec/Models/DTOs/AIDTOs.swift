//
//  AIDTOs.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/2.
//

import Foundation

struct HierarchySuggestionDTO: Codable {
    let capability: CapabilitySuggestionDTO
    let confidence: Double
    let reasoning: String
}

struct CapabilitySuggestionDTO: Codable {
    let title: String
    let description: String?
    let features: [FeatureSuggestionDTO]
}

struct FeatureSuggestionDTO: Codable {
    let title: String
    let description: String?
    let userStories: [UserStorySuggestionDTO]
}

struct UserStorySuggestionDTO: Codable {
    let title: String
    let description: String?
    let storyType: String
    let testCases: [TestCaseSuggestionDTO]
    let estimatedPoints: Int?
}

struct TestCaseSuggestionDTO: Codable {
    let title: String
    let description: String?
}

struct ComplexityEstimateDTO: Codable {
    let storyPoints: Int
    let complexity: String
    let reasoning: String
    let confidence: Double
}

struct DependencyDetectionDTO: Codable {
    let dependencies: [DependencySuggestionDTO]
    let reasoning: String
    let confidence: Double
}

struct DependencySuggestionDTO: Codable {
    let storyId: String
    let storyTitle: String
    let dependencyType: String
    let reasoning: String
}

extension HierarchySuggestionDTO {
    init?(from dict: [String: Any]) {
        guard let capabilityDict = dict["capability"] as? [String: Any],
              let confidence = dict["confidence"] as? Double,
              let reasoning = dict["reasoning"] as? String else {
            return nil
        }
        
        guard let capability = CapabilitySuggestionDTO(from: capabilityDict) else {
            return nil
        }
        
        self.capability = capability
        self.confidence = confidence
        self.reasoning = reasoning
    }
}

extension CapabilitySuggestionDTO {
    init?(from dict: [String: Any]) {
        guard let title = dict["title"] as? String else {
            return nil
        }
        
        self.title = title
        self.description = dict["description"] as? String
        
        let featureDicts = dict["features"] as? [[String: Any]] ?? []
        self.features = featureDicts.compactMap { FeatureSuggestionDTO(from: $0) }
    }
}

extension FeatureSuggestionDTO {
    init?(from dict: [String: Any]) {
        guard let title = dict["title"] as? String else {
            return nil
        }
        
        self.title = title
        self.description = dict["description"] as? String
        
        let storyDicts = dict["userStories"] as? [[String: Any]] ?? []
        self.userStories = storyDicts.compactMap { UserStorySuggestionDTO(from: $0) }
    }
}

extension UserStorySuggestionDTO {
    init?(from dict: [String: Any]) {
        guard let title = dict["title"] as? String else {
            return nil
        }
        
        self.title = title
        self.description = dict["description"] as? String
        self.storyType = dict["storyType"] as? String ?? "business"
        self.estimatedPoints = dict["estimatedPoints"] as? Int
        
        let testCaseDicts = dict["testCases"] as? [[String: Any]] ?? []
        self.testCases = testCaseDicts.compactMap { TestCaseSuggestionDTO(from: $0) }
    }
}

extension TestCaseSuggestionDTO {
    init?(from dict: [String: Any]) {
        guard let title = dict["title"] as? String else {
            return nil
        }
        
        self.title = title
        self.description = dict["description"] as? String
    }
}