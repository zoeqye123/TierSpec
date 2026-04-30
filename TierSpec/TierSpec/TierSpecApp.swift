//
//  TierSpecApp.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

@main
struct TierSpecApp: App {
    private static let projectWindowSceneID = "project-window"

    var body: some Scene {
        WindowGroup(id: Self.projectWindowSceneID) {
            ProjectWindowSceneView()
        }
        .commands {
            ProjectWindowCommands(sceneID: Self.projectWindowSceneID)
        }
    }
}

private struct ProjectWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.projectManager) private var projectManager

    let sceneID: String

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: sceneID)
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("New Project") {
                projectManager?.requestNewProject()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(projectManager == nil)

            Button("Open Project...") {
                projectManager?.openProject()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(projectManager == nil)

            Divider()

            Button("Close Project") {
                projectManager?.closeCurrentProject()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(projectManager == nil)
        }
    }
}

private struct ProjectManagerFocusedValueKey: FocusedValueKey {
    typealias Value = ProjectManager
}

private extension FocusedValues {
    var projectManager: ProjectManager? {
        get { self[ProjectManagerFocusedValueKey.self] }
        set { self[ProjectManagerFocusedValueKey.self] = newValue }
    }
}

private struct ProjectWindowSceneView: View {
    @State private var projectManager = ProjectManager()

    var body: some View {
        Group {
            if let project = projectManager.currentProject {
                ContentView(projectName: project.name)
                    .modelContainer(project.modelContainer)
                    .navigationTitle(project.name)
            } else {
                WelcomeView(projectManager: projectManager)
            }
        }
        .focusedSceneValue(\.projectManager, projectManager)
    }
}

@Observable
class ProjectManager {
    var currentProject: ProjectContext?
    private var openProjects: [UUID: ProjectContext] = [:]
    
    // Dialog state for new project name
    var showingNewProjectDialog = false
    var newProjectName = ""
    
    private let projectsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("TierSpec/Projects", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                assertionFailure("Failed to create projects directory at \(dir.path): \(error)")
            }
        }
        return dir
    }()
    
    func requestNewProject() {
        newProjectName = ""
        showingNewProjectDialog = true
    }
    
    func createNewProject() {
        let id = UUID()
        let dbPath = projectsDirectory.appendingPathComponent("\(id.uuidString).db").path
        let project = ProjectContext(
            id: id,
            name: "Untitled Project",
            databasePath: dbPath
        )
        openProjects[id] = project
        currentProject = project
    }
    
    func createProject(named name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let id = UUID()
        let dbPath = projectsDirectory.appendingPathComponent("\(id.uuidString).db").path
        let project = ProjectContext(
            id: id,
            name: name.trimmingCharacters(in: .whitespaces),
            databasePath: dbPath
        )
        openProjects[id] = project
        currentProject = project
        
        // Auto-create Sprint 1 (2 weeks from today, status: planning)
        createDefaultSprint(in: project.modelContainer)
    }
    
    private func createDefaultSprint(in container: ModelContainer) {
        let context = container.mainContext
        let today = Date()
        let calendar = Calendar.current
        guard let endDate = calendar.date(byAdding: .day, value: 14, to: today) else {
            assertionFailure("Failed to calculate sprint end date")
            return
        }
        
        let sprint = Sprint(
            name: "Sprint 1",
            startDate: today,
            endDate: endDate,
            status: .planning
        )
        context.insert(sprint)
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save default sprint: \(error)")
        }
    }
    
    func openProject() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "tierspec") ?? .item]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            openProject(at: url)
        }
        #endif
    }
    
    func openProject(at url: URL) {
        let id = UUID()
        let project = ProjectContext(
            id: id,
            name: url.deletingPathExtension().lastPathComponent,
            databasePath: url.path
        )
        openProjects[id] = project
        currentProject = project
    }
    
    func closeCurrentProject() {
        if let project = currentProject {
            openProjects.removeValue(forKey: project.id)
        }
        currentProject = nil
    }
    
    func project(withId id: UUID) -> ProjectContext? {
        openProjects[id]
    }
}

struct ProjectContext: Identifiable {
    let id: UUID
    let name: String
    let databasePath: String
    let modelContainer: ModelContainer
    
    init(id: UUID, name: String, databasePath: String) {
        self.id = id
        self.name = name
        self.databasePath = databasePath
        
        let schema = Schema([TierItem.self, Sprint.self])
        let url = URL(fileURLWithPath: databasePath)
        let directory = url.deletingLastPathComponent()
        
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                assertionFailure("Failed to create database directory at \(directory.path): \(error)")
            }
        }
        
        let config = ModelConfiguration(schema: schema, url: url)
        
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

struct WelcomeView: View {
    let projectManager: ProjectManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("TierSpec")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Create a new project to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                Button {
                    projectManager.requestNewProject()
                } label: {
                    Label("New Project", systemImage: "plus")
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    projectManager.openProject()
                } label: {
                    Label("Open Project...", systemImage: "folder")
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .alert("New Project", isPresented: Binding(
            get: { projectManager.showingNewProjectDialog },
            set: { projectManager.showingNewProjectDialog = $0 }
        )) {
            TextField("Project name", text: Binding(
                get: { projectManager.newProjectName },
                set: { projectManager.newProjectName = $0 }
            ))
            Button("Cancel", role: .cancel) {
                projectManager.newProjectName = ""
            }
            Button("Create") {
                projectManager.createProject(named: projectManager.newProjectName)
                projectManager.newProjectName = ""
            }
            .disabled(projectManager.newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Enter a name for your new project.")
        }
    }
}
