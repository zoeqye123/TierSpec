//
//  Project.swift
//  TierSpec
//
//  Created by z on 2026/4/27.
//

import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var name: String
    var databasePath: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        databasePath: String
    ) {
        self.id = id
        self.name = name
        self.databasePath = databasePath
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var databaseURL: URL {
        URL(fileURLWithPath: databasePath)
    }
    
    func touch() {
        updatedAt = Date()
    }
}
