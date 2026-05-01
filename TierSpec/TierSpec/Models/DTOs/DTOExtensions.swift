//
//  DTOExtensions.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/1.
//

import SwiftUI

extension TierItemDTO {
    var displayId: String? {
        nil
    }
    
    var canHaveChildren: Bool {
        !type.allowedChildTypes.isEmpty
    }
    
    var depth: Int {
        var currentDepth = 0
        var currentParentId = parentId
        while currentParentId != nil {
            currentDepth += 1
            currentParentId = nil
        }
        return currentDepth
    }
}

extension ItemTypeDTO {
    var icon: String {
        switch self {
        case .capability:
            return "building.2"
        case .feature:
            return "cube.box"
        case .userStory:
            return "person.text.rectangle"
        case .testCase:
            return "checkmark.shield"
        }
    }
    
    var allowedChildTypes: [ItemTypeDTO] {
        switch self {
        case .capability:
            return [.feature]
        case .feature:
            return [.userStory]
        case .userStory:
            return [.testCase]
        case .testCase:
            return []
        }
    }
}

extension ItemStatusDTO {
    var color: Color {
        switch self {
        case .requirementInput:
            return .secondary
        case .requirementReview:
            return .blue
        case .needsInfo:
            return .yellow
        case .backlog:
            return .gray
        case .aiDecomposing:
            return .purple
        case .inProgress:
            return .blue
        case .waitingForTest:
            return .orange
        case .testing:
            return .indigo
        case .acceptance:
            return .mint
        case .completed:
            return .green
        case .published:
            return .green
        case .blocked:
            return .red
        case .cancelled:
            return .gray
        }
    }
}

extension SprintStatusDTO {
    var color: Color {
        switch self {
        case .planning:
            return .orange
        case .active:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .gray
        }
    }
}

extension SprintDTO {
    var progress: Double {
        guard committedPoints > 0 else { return 0 }
        return Double(completedPoints) / Double(committedPoints)
    }
    
    var capacityUsedPercent: Double {
        guard capacityPoints > 0 else { return 0 }
        return Double(committedPoints) / Double(capacityPoints) * 100
    }
    
    var isActive: Bool {
        return status == .active
    }
    
    var isCurrent: Bool {
        let now = Date()
        return status == .active && startDate <= now && endDate >= now
    }
    
    var daysRemaining: Int? {
        guard status == .active else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
}

extension ComplexityDTO {
    var color: Color {
        switch self {
        case .xs: return .green
        case .s: return .mint
        case .m: return .yellow
        case .l: return .orange
        case .xl: return .red
        }
    }
}