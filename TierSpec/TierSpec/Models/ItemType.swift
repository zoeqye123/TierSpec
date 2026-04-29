//
//  ItemType.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import Foundation
import SwiftUI

/// Represents the type of an item in the 5-level hierarchy
enum ItemType: String, Codable, CaseIterable {
    case capability
    case feature
    case user_story
    case test_case
    
    var displayName: String {
        switch self {
        case .capability:
            return "Capability"
        case .feature:
            return "Feature"
        case .user_story:
            return "User Story"
        case .test_case:
            return "Test Case"
        }
    }
    
    var icon: String {
        switch self {
        case .capability:
            return "building.2"
        case .feature:
            return "cube.box"
        case .user_story:
            return "person.text.rectangle"
        case .test_case:
            return "checkmark.shield"
        }
    }
    
    var allowedChildTypes: [ItemType] {
        switch self {
        case .capability:
            return [.feature]
        case .feature:
            return [.user_story]
        case .user_story:
            return [.test_case]
        case .test_case:
            return []
        }
    }
    
    var level: Int {
        switch self {
        case .capability:
            return 1
        case .feature:
            return 2
        case .user_story:
            return 3
        case .test_case:
            return 4
        }
    }
    
    var canBeRoot: Bool {
        return self == .capability
    }

    var canHaveChildren: Bool {
        return !allowedChildTypes.isEmpty
    }

    var isStoryType: Bool {
        return self == .user_story
    }
}
