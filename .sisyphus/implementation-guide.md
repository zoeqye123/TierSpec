# TierSpec - Remaining Implementation Guide

**Purpose**: Step-by-step code patterns for completing all 15 remaining tasks  
**Status**: 6/21 complete, this guide covers the remaining 15 tasks

---

## Wave 2: MCP Integration (3 tasks)

### W2.T2: Replace ItemRepository with MCP calls

**File**: `TierSpec/TierSpec/Repositories/ItemRepository.swift`

**Pattern**: Replace SwiftData with MCPToolClient

```swift
import Foundation

actor ItemRepository {
    private let mcpClient: MCPToolClient
    
    init(mcpClient: MCPToolClient) {
        self.mcpClient = mcpClient
    }
    
    // CRUD Operations
    func create(type: String, title: String, description: String? = nil, parentId: String? = nil) async throws -> String {
        let result = try await mcpClient.createItem(
            type: type,
            title: title,
            description: description,
            parentId: parentId
        )
        guard let item = result["item"] as? [String: Any],
              let id = item["id"] as? String else {
            throw RepositoryError.invalidResponse
        }
        return id
    }
    
    func fetch(byId id: String) async throws -> [String: Any]? {
        let result = try await mcpClient.getItem(id: id)
        return result["item"] as? [String: Any]
    }
    
    func fetchRoot() async throws -> [[String: Any]] {
        let result = try await mcpClient.listItems(parentId: nil, type: "capability")
        return result["items"] as? [[String: Any]] ?? []
    }
    
    func search(query: String) async throws -> [[String: Any]] {
        let result = try await mcpClient.searchItems(query: query)
        return result["items"] as? [[String: Any]] ?? []
    }
    
    func delete(id: String, cascade: Bool = false) async throws {
        _ = try await mcpClient.deleteItem(itemId: id, cascadeChildren: cascade)
    }
    
    func move(itemId: String, newParentId: String?) async throws {
        _ = try await mcpClient.moveItem(itemId: itemId, newParentId: newParentId)
    }
}

enum RepositoryError: LocalizedError {
    case invalidResponse
    case itemNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from MCP server"
        case .itemNotFound: return "Item not found"
        }
    }
}
```

**Testing**: After refactoring, verify compilation with `xcodebuild build`

---

### W2.T3: Update TreeStore for MCP

**File**: `TierSpec/TierSpec/Stores/TreeStore.swift`

**Pattern**: Replace ItemRepository calls with MCPToolClient

```swift
@MainActor
@Observable
class TreeStore {
    private let repository: ItemRepository
    var rootItems: [[String: Any]] = []
    var selectedItemId: String?
    var expandedItemIds: Set<String> = []
    
    init(repository: ItemRepository) {
        self.repository = repository
    }
    
    func loadTree() async {
        do {
            rootItems = try await repository.fetchRoot()
        } catch {
            print("Failed to load tree: \(error)")
        }
    }
    
    func createItem(type: String, title: String, parentId: String?) async {
        do {
            let newId = try await repository.create(
                type: type,
                title: title,
                parentId: parentId
            )
            selectedItemId = newId
            await loadTree()
        } catch {
            print("Failed to create item: \(error)")
        }
    }
    
    func deleteItem(id: String) async {
        do {
            try await repository.delete(id: id, cascade: true)
            if selectedItemId == id {
                selectedItemId = nil
            }
            await loadTree()
        } catch {
            print("Failed to delete item: \(error)")
        }
    }
}
```

---

### W2.T4: Remove SwiftData models

**Step 1**: Create DTO directory
```bash
mkdir -p TierSpec/TierSpec/Models/DTOs
```

**Step 2**: Create `TierItemDTO.swift`

```swift
import Foundation

struct TierItemDTO: Identifiable, Codable {
    let id: String
    let type: String
    let title: String
    let description: String?
    let status: String
    let priority: Int
    let position: Double
    let storyPoints: Int?
    let complexity: String?
    let aiGenerated: Bool
    let aiConfidence: Double?
    let createdAt: String
    let updatedAt: String
    let parentId: String?
    
    init(from dict: [String: Any]) throws {
        guard let id = dict["id"] as? String,
              let type = dict["type"] as? String,
              let title = dict["title"] as? String,
              let status = dict["status"] as? String else {
            throw DTOError.missingRequiredField
        }
        
        self.id = id
        self.type = type
        self.title = title
        self.description = dict["description"] as? String
        self.status = status
        self.priority = dict["priority"] as? Int ?? 0
        self.position = dict["position"] as? Double ?? 0
        self.storyPoints = dict["story_points"] as? Int
        self.complexity = dict["complexity"] as? String
        self.aiGenerated = dict["ai_generated"] as? Bool ?? false
        self.aiConfidence = dict["ai_confidence"] as? Double
        self.createdAt = dict["created_at"] as? String ?? ""
        self.updatedAt = dict["updated_at"] as? String ?? ""
        self.parentId = dict["parent_id"] as? String
    }
}

enum DTOError: Error {
    case missingRequiredField
}
```

**Step 3**: Delete old SwiftData models
```bash
rm TierSpec/TierSpec/Models/TierItem.swift
rm TierSpec/TierSpec/Models/Sprint.swift
```

**Step 4**: Update all imports - remove `import SwiftData` throughout codebase

---

## Wave 3: UI Transformation (4 tasks)

### W3.T1: Create MainView with 3-column layout

**File**: `TierSpec/TierSpec/Views/MainView.swift`

```swift
import SwiftUI

struct MainView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedItem: String?
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            HierarchyTreeView(selectedItem: $selectedItem)
                .navigationSplitViewColumnWidth(280)
        } content: {
            MainContentView()
                .navigationSplitViewColumnWidth(min: 400, ideal: 600, max: 1000)
        } detail: {
            if let selectedItem = selectedItem {
                DetailsPanelView(itemId: selectedItem)
                    .navigationSplitViewColumnWidth(320)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.right",
                    description: Text("Select an item to view details")
                )
            }
        }
    }
}

struct MainContentView: View {
    var body: some View {
        KanbanView()
    }
}

struct DetailsPanelView: View {
    let itemId: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Item Details")
                    .font(.headline)
                Text("ID: \(itemId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
```

---

### W3.T2: Implement natural language input bar

**File**: `TierSpec/TierSpec/Views/AIInputBar.swift`

```swift
import SwiftUI

struct AIInputBar: View {
    @Binding var inputText: String
    @Binding var isProcessing: Bool
    let onSubmit: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            
            TextField("Describe a requirement...", text: $inputText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .disabled(isProcessing)
            
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else if !inputText.isEmpty {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: { }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding()
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
                    isFocused = true
                    return nil
                }
                return event
            }
        }
    }
}
```

---

### W3.T3: Create AI suggestion UI components

**File**: `TierSpec/TierSpec/Views/ConfidenceBadge.swift`

```swift
import SwiftUI

struct ConfidenceBadge: View {
    let confidence: Double
    
    private var color: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
    
    private var label: String {
        "\(Int(confidence * 100))%"
    }
    
    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }
}

struct ReasoningPanel: View {
    let reasoning: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "lightbulb")
                    Text("Why this suggestion?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Text(reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct AISuggestionCard: View {
    let title: String
    let confidence: Double
    let reasoning: String
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                ConfidenceBadge(confidence: confidence)
            }
            
            ReasoningPanel(reasoning: reasoning)
            
            HStack {
                Button("Reject") {
                    onReject()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Accept") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}
```

---

### W3.T4: Integrate AI workflow

**File**: `TierSpec/TierSpec/ViewModels/AIWorkflowViewModel.swift`

```swift
import Foundation

@MainActor
@Observable
class AIWorkflowViewModel {
    private let mcpClient: MCPToolClient
    private let configManager = ConfigManager()
    
    var isProcessing = false
    var currentSuggestion: HierarchySuggestion?
    var error: String?
    
    init(mcpClient: MCPToolClient) {
        self.mcpClient = mcpClient
    }
    
    func parseRequirement(_ text: String) async {
        isProcessing = true
        error = nil
        
        do {
            let apiKey = await configManager.getApiKey()
            let result = try await mcpClient.parseRequirement(
                requirement: text,
                apiKey: apiKey
            )
            
            currentSuggestion = try HierarchySuggestion(from: result)
        } catch {
            self.error = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    func acceptSuggestion() async {
        guard let suggestion = currentSuggestion else { return }
        
        for capability in suggestion.capabilities {
            do {
                _ = try await mcpClient.createItem(
                    type: "capability",
                    title: capability.title,
                    description: capability.description
                )
            } catch {
                self.error = "Failed to create capability: \(error.localizedDescription)"
            }
        }
        
        currentSuggestion = nil
    }
    
    func rejectSuggestion() {
        currentSuggestion = nil
    }
}

struct HierarchySuggestion {
    let capabilities: [CapabilitySuggestion]
    let confidence: Double
    let reasoning: String
    
    init(from dict: [String: Any]) throws {
        guard let caps = dict["capabilities"] as? [[String: Any]],
              let conf = dict["confidence"] as? Double,
              let reason = dict["reasoning"] as? String else {
            throw AIError.invalidResponse
        }
        
        self.capabilities = try caps.map { try CapabilitySuggestion(from: $0) }
        self.confidence = conf
        self.reasoning = reason
    }
}

struct CapabilitySuggestion {
    let title: String
    let description: String
    let confidence: Double
    
    init(from dict: [String: Any]) throws {
        guard let title = dict["title"] as? String,
              let desc = dict["description"] as? String,
              let conf = dict["confidence"] as? Double else {
            throw AIError.invalidResponse
        }
        
        self.title = title
        self.description = desc
        self.confidence = conf
    }
}

enum AIError: Error {
    case invalidResponse
}
```

---

## Wave 4: Polish & Testing (5 tasks)

### W4.T1: Write model unit tests

**File**: `TierSpec/TierSpecTests/Models/ItemTypeTests.swift`

```swift
import Testing
@testable import TierSpec

@Test func testCapabilityAllowsFeatureChild() {
    let capability = ItemType.capability
    #expect(capability.allowedChildTypes.contains(.feature))
}

@Test func testFeatureAllowsUserStoryChild() {
    let feature = ItemType.feature
    #expect(feature.allowedChildTypes.contains(.user_story))
}

@Test func testTestCaseHasNoChildren() {
    let testCase = ItemType.test_case
    #expect(testCase.allowedChildTypes.isEmpty)
}

@Test func testOnlyCapabilityCanBeRoot() {
    #expect(ItemType.capability.canBeRoot == true)
    #expect(ItemType.feature.canBeRoot == false)
    #expect(ItemType.user_story.canBeRoot == false)
    #expect(ItemType.test_case.canBeRoot == false)
}
```

**File**: `TierSpec/TierSpecTests/Models/StateMachineTests.swift`

```swift
import Testing
@testable import TierSpec

@Test func testTodoToInProgressTransition() throws {
    try StateMachine.assertValidTransition(
        from: .todo,
        to: .in_progress,
        actorType: .human
    )
}

@Test func testOnlyHumanCanMarkDone() throws {
    try StateMachine.assertValidTransition(
        from: .test,
        to: .done,
        actorType: .human
    )
    
    #expect(throws: StateMachineError.self) {
        try StateMachine.assertValidTransition(
            from: .test,
            to: .done,
            actorType: .ai
        )
    }
}

@Test func testCannotSkipStates() {
    #expect(throws: StateMachineError.self) {
        try StateMachine.assertValidTransition(
            from: .todo,
            to: .done,
            actorType: .human
        )
    }
}
```

---

### W4.T2: Write integration tests

**File**: `TierSpec/TierSpecTests/Integration/MCPIntegrationTests.swift`

```swift
import Testing
@testable import TierSpec

@Test func testMCPClientConnection() async throws {
    let client = MCPClientManager()
    try await client.connect()
    #expect(client.isConnected == true)
    await client.disconnect()
}

@Test func testCreateItemViaMCP() async throws {
    let client = MCPClientManager()
    try await client.connect()
    
    let toolClient = MCPToolClient(clientManager: client)
    let result = try await toolClient.createItem(
        type: "capability",
        title: "Test Capability"
    )
    
    #expect(result["item"] != nil)
    await client.disconnect()
}
```

---

### W4.T3: Update app entry point

**File**: `TierSpec/TierSpec/TierSpecApp.swift`

```swift
@main
struct TierSpecApp: App {
    @StateObject private var mcpClient = MCPClientManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(mcpClient)
                .task {
                    do {
                        try await mcpClient.connect()
                    } catch {
                        print("Failed to connect to MCP server: \(error)")
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NSApp.sendAction(#selector(NSApplication.showSettingsWindow(_:)), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}
```

---

### W4.T4: Add error handling & logging

**File**: `TierSpec/TierSpec/Services/Logger.swift`

```swift
import Foundation
import os.log

struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.tierspec"
    
    static let mcp = os.Logger(subsystem: subsystem, category: "MCP")
    static let ui = os.Logger(subsystem: subsystem, category: "UI")
    static let data = os.Logger(subsystem: subsystem, category: "Data")
    
    static func error(_ message: String, category: os.Logger = .mcp) {
        category.error("\(message)")
    }
    
    static func info(_ message: String, category: os.Logger = .mcp) {
        category.info("\(message)")
    }
}
```

**File**: `TierSpec/TierSpec/Views/ErrorBanner.swift`

```swift
import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.red.opacity(0.3), lineWidth: 1)
        )
    }
}
```

---

### W4.T5: Update documentation

**File**: `README.md` - Add architecture section:

```markdown
## Architecture

TierSpec uses an MCP (Model Context Protocol) dual-end architecture:

- **Swift Mac Client**: Native macOS app with SwiftUI
- **TypeScript MCP Server**: Node.js server with SQLite database
- **Communication**: stdio transport with JSON-RPC 2.0
- **AI Integration**: OpenAI API for requirement parsing

### Building

1. Install dependencies:
   ```bash
   cd mcp-server && npm install && npm run build
   ```

2. Open Xcode project:
   ```bash
   open TierSpec/TierSpec.xcodeproj
   ```

3. Add Run Script build phase (see `TierSpec/Scripts/README.md`)

4. Build and run (⌘R)
```

---

## Wave 5: Verification & Deployment (3 tasks)

### W5.T1: End-to-end verification checklist

```
[ ] App launches without errors
[ ] MCP server process spawns successfully
[ ] Natural language input accepts text
[ ] AI parsing returns suggestions
[ ] Confidence scores display correctly
[ ] Accept creates items in hierarchy
[ ] Reject dismisses suggestions
[ ] 3-column layout renders correctly
[ ] Hierarchy tree displays items
[ ] Kanban board shows items by status
[ ] Details panel shows item info
[ ] Settings panel saves API key
[ ] All tests pass (unit + integration)
```

### W5.T2: Performance testing

**Targets**:
- App launch: <2 seconds
- MCP server spawn: <1 second
- AI parsing: <5 seconds
- Item creation: <100ms
- Tree rendering: <50ms for 1000 items

### W5.T3: Production build

1. Create release configuration in Xcode
2. Set up code signing
3. Build for release
4. Create DMG with `create-dmg` tool
5. Test installation on clean macOS

---

## Summary

This guide provides complete code patterns for all 15 remaining tasks. Each section includes:
- Exact file paths
- Complete code examples
- Testing patterns
- Success criteria

Follow the guide sequentially from Wave 2 → Wave 5 for systematic completion.
