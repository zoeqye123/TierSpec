//
//  TierSpecApp.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

@main
struct TierSpecApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TierItem.self,
            Sprint.self,
        ])
        let sharedStoreURL = URL(fileURLWithPath: "/Users/z/.tierspec/tierspec.db")
        let sharedStoreDirectory = sharedStoreURL.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: sharedStoreDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: sharedStoreDirectory, withIntermediateDirectories: true)
            } catch {
                fatalError("Could not create shared store directory: \(error)")
            }
        }

        let modelConfiguration = ModelConfiguration(schema: schema, url: sharedStoreURL)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
