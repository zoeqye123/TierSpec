//
//  UserStoryIDGenerator.swift
//  TierSpec
//
//  Created by z on 2026/4/29.
//

import Foundation

/// Generates sequential display IDs for User Stories
struct UserStoryIDGenerator {
    
    /// Generate a new display ID and increment the counter
    /// - Parameter project: The project to generate the ID for
    /// - Returns: A formatted display ID (e.g., "US-001", "US-1000")
    func generate(for project: Project) -> String {
        project.lastUserStoryNumber += 1
        let number = project.lastUserStoryNumber
        
        // Format: US-001 for numbers < 1000, US-1000 for >= 1000
        if number < 1000 {
            return String(format: "US-%03d", number)
        } else {
            return "US-\(number)"
        }
    }
    
    /// Generate ID only if item is a user_story type
    /// - Parameters:
    ///   - item: The item to check
    ///   - project: The project to generate the ID for
    /// - Returns: A formatted display ID if the item is a user story, nil otherwise
    func generateIfNeeded(for item: TierItem, in project: Project) -> String? {
        guard item.type == .user_story else {
            return nil
        }
        return generate(for: project)
    }
}
