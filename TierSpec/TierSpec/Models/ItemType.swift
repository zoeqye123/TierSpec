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
    case epic
    case business_story
    case technical_story
    case test_case
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .capability:
            return "Capability"
        case .feature:
            return "Feature"
        case .epic:
            return "Epic"
        case .business_story:
            return "Business Story"
        case .technical_story:
            return "Technical Story"
        case .test_case:
            return "Test Case"
        }
    }
    
    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .capability:
            return "building.2"
        case .feature:
            return "cube.box"
        case .epic:
            return "book.closed"
        case .business_story:
            return "person.text.rectangle"
        case .technical_story:
            return "gearshape.2"
        case .test_case:
            return "checkmark.shield"
        }
    }
    
    /// Allowed child types based on hierarchy rules
    var allowedChildTypes: [ItemType] {
        switch self {
        case .capability:
            return [.feature]
        case .feature:
            return [.epic]
        case .epic:
            return [.business_story, .technical_story]
        case .business_story, .technical_story:
            return [.test_case]
        case .test_case:
            return [] // Leaf node - no children allowed
        }
    }
    
    /// Level in the hierarchy (1-based)
    var level: Int {
        switch self {
        case .capability:
            return 1
        case .feature:
            return 2
        case .epic:
            return 3
        case .business_story, .technical_story:
            return 4
        case .test_case:
            return 5
        }
    }
    
    /// Whether this type can be created at root level
    var canBeRoot: Bool {
        return self == .capability
    }
    
    /// Whether this is a story type (business or technical)
    var isStoryType: Bool {
        return self == .business_story || self == .technical_story
    }
}
