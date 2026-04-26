//
//  Sprint.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/26.
//

import Foundation
import SwiftData

enum SprintStatus: String, Codable, CaseIterable {
    case planning
    case active
    case completed
    case cancelled
    
    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .planning: return .orange
        case .active: return .blue
        case .completed: return .green
        case .cancelled: return .gray
        }
    }
}

import SwiftUI

@Model
final class Sprint {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var capacityPoints: Int
    var status: SprintStatus
    var committedPoints: Int
    var completedPoints: Int
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .nullify, inverse: \TierItem.sprint)
    var items: [TierItem]?
    
    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        capacityPoints: Int = 0,
        status: SprintStatus = .planning
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.capacityPoints = capacityPoints
        self.status = status
        self.committedPoints = 0
        self.completedPoints = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
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
    
    func touch() {
        updatedAt = Date()
    }
}
