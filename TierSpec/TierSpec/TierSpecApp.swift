//
//  TierSpecApp.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

@main
struct TierSpecApp: App {
    private static let projectWindowSceneID = "project-window"
    
    @StateObject private var mcpClientManager = MCPClientManager()
    
    var body: some Scene {
        WindowGroup(id: Self.projectWindowSceneID) {
            ProjectWindowSceneView(mcpClientManager: mcpClientManager)
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
    @ObservedObject var mcpClientManager: MCPClientManager
    @State private var projectManager = ProjectManager()
    @State private var mcpToolClient: MCPToolClient?
    
    var body: some View {
        Group {
            if mcpClientManager.isConnected {
                if let project = projectManager.currentProject, let mcpToolClient = mcpToolClient {
                    MainView(mcpToolClient: mcpToolClient, projectName: project.name)
                        .navigationTitle(project.name)
                } else {
                    WelcomeView(projectManager: projectManager)
                }
            } else {
                ConnectionView(mcpClientManager: mcpClientManager)
            }
        }
        .focusedSceneValue(\.projectManager, projectManager)
        .task {
            do {
                try await mcpClientManager.connect()
                mcpToolClient = MCPToolClient(clientManager: mcpClientManager)
            } catch {
                print("[TierSpecApp] Failed to connect to MCP server: \(error)")
            }
        }
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

struct ConnectionView: View {
    @ObservedObject var mcpClientManager: MCPClientManager
    @State private var showingHelp = false
    
    var body: some View {
        VStack(spacing: 24) {
            if let error = mcpClientManager.connectionError {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                
                Text("Connection Failed")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                helpSection
                
                Button("Retry") {
                    Task {
                        try? await mcpClientManager.connect()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Connecting to MCP Server...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Button("Show Setup Instructions") {
                    showingHelp = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 8)
                
                if showingHelp {
                    helpSection
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .frame(width: 200)
            
            Text("Setup Instructions")
                .font(.headline)
            
            Text("The MCP server must be running for TierSpec to work. Start it with:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Text("cd /Users/z/project/tierspec/mcp-server && npm run build && node dist/index.js")
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("cd /Users/z/project/tierspec/mcp-server && npm run build && node dist/index.js", forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy to clipboard")
            }
            
            Text("Or ask your AI assistant:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            
            HStack {
                Text("Please start the TierSpec MCP server")
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("Please start the TierSpec MCP server by running: cd /Users/z/project/tierspec/mcp-server && npm run build && node dist/index.js", forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy to clipboard")
            }
        }
        .frame(maxWidth: 550)
        .padding(.top, 8)
    }
}