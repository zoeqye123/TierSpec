# TierSpec Implementation - Handoff Document

**Date**: 2026-05-01  
**Status**: Wave 1 Complete, Wave 2 Partial  
**Completion**: 6/21 tasks (29%)

---

## What Has Been Completed

### ✅ Wave 1: Foundation (100% Complete)

All 5 foundation tasks are fully implemented and committed:

1. **Node.js Bundling** - Automated build scripts for bundling Node.js runtime and MCP server into app bundle
2. **OpenAI SDK Integration** - AIClient class with parseRequirement, estimateComplexity, detectDependencies
3. **AI Requirement Parser** - 3 new MCP tools with confidence scoring and reasoning
4. **MCP Client Manager** - Full stdio transport with JSON-RPC, process lifecycle management
5. **API Key Settings UI** - Secure configuration storage and user-friendly settings panel

### ✅ Wave 2: MCP Integration (25% Complete)

1. **MCP Tool Wrappers** - Type-safe Swift wrappers for all 20 MCP tools

---

## What Remains To Be Done

### 🔄 Wave 2: MCP Integration (3 tasks remaining)

**W2.T2: Replace ItemRepository with MCP calls**
- **Current State**: ItemRepository.swift uses SwiftData (309 lines)
- **Required Action**: Refactor to use MCPToolClient instead of modelContext
- **Complexity**: HIGH - requires careful mapping of all CRUD operations
- **Estimated Time**: 3-4 hours
- **Key Changes**:
  - Replace `modelContext.insert()` with `mcpClient.createItem()`
  - Replace `FetchDescriptor` queries with `mcpClient.listItems()` / `mcpClient.searchItems()`
  - Remove SwiftData dependencies
  - Update error handling to use MCPError
  - Maintain actor isolation for thread safety

**W2.T3: Update TreeStore for MCP**
- **Current State**: TreeStore.swift uses ItemRepository (SwiftData-based)
- **Required Action**: Update to use MCPToolClient
- **Complexity**: MEDIUM
- **Estimated Time**: 2-3 hours
- **Key Changes**:
  - Replace ItemRepository with MCPToolClient
  - Update loadTree() to use mcpClient.listItems()
  - Update createItem() to use mcpClient.createItem()
  - Update deleteItem() to use mcpClient.deleteItem()
  - Maintain cache invalidation logic

**W2.T4: Remove SwiftData models**
- **Current State**: TierItem.swift and Sprint.swift are @Model classes
- **Required Action**: Create DTO structs matching MCP server types
- **Complexity**: MEDIUM
- **Estimated Time**: 2 hours
- **Key Changes**:
  - Create `TierSpec/TierSpec/Models/DTOs/` directory
  - Create `TierItemDTO.swift` as plain struct (no @Model)
  - Create `SprintDTO.swift` as plain struct
  - Update all views to use DTOs instead of @Model classes
  - Remove SwiftData imports throughout codebase

---

### 🎨 Wave 3: UI Transformation (4 tasks)

**W3.T1: Create MainView with 3-column layout**
- Create new `MainView.swift` with `NavigationSplitView`
- 3 columns: Hierarchy (280px) | Main Content (adaptive) | Details (320px)
- Replace current 2-column ContentView
- **Estimated Time**: 3 hours

**W3.T2: Implement natural language input bar**
- Create `AIInputBar.swift` at top of window
- Add ⌘K keyboard shortcut
- Loading indicator during AI processing
- **Estimated Time**: 2.5 hours

**W3.T3: Create AI suggestion UI components**
- `ConfidenceBadge.swift` with color coding
- `ReasoningPanel.swift` (expandable)
- Accept/Edit/Reject buttons
- **Estimated Time**: 3 hours

**W3.T4: Integrate AI workflow**
- Connect input bar to MCP parse_requirement
- Display suggestions with confidence scores
- Implement accept/reject logic
- **Estimated Time**: 3 hours

---

### 🧪 Wave 4: Polish & Testing (5 tasks)

**W4.T1: Write model unit tests**
- Test ItemType validation rules
- Test state machine transitions
- Test actor type enforcement
- **Estimated Time**: 2 hours

**W4.T2: Write integration tests**
- Test MCP client-server communication
- Test AI workflow end-to-end
- Test error propagation
- **Estimated Time**: 4 hours

**W4.T3: Update app entry point**
- Modify TierSpecApp.swift to use MainView
- Initialize MCPClientManager
- Remove SwiftData setup
- **Estimated Time**: 1 hour

**W4.T4: Add error handling & logging**
- Create Logger service
- Create ErrorBanner component
- Implement user-friendly error messages
- **Estimated Time**: 2 hours

**W4.T5: Update documentation**
- Update README.md with new architecture
- Update AGENTS.md
- Create architecture diagram
- **Estimated Time**: 1.5 hours

---

### ✅ Wave 5: Verification & Deployment (3 tasks)

**W5.T1: End-to-end verification**
- Complete 13-point checklist (see plan document)
- **Estimated Time**: 2 hours

**W5.T2: Performance testing**
- Verify all performance targets
- **Estimated Time**: 1.5 hours

**W5.T3: Production build**
- Create release configuration
- Code signing
- DMG installer
- **Estimated Time**: 2 hours

---

## Critical Files Created

### TypeScript (MCP Server)
```
mcp-server/src/ai/types.ts          - AI type definitions
mcp-server/src/ai/client.ts         - OpenAI integration
mcp-server/src/tools/ai.ts          - AI MCP tools
mcp-server/tests/ai/client.test.ts  - Unit tests
```

### Swift (Mac Client)
```
TierSpec/TierSpec/Services/MCPTypes.swift          - MCP protocol types
TierSpec/TierSpec/Services/MCPProcessManager.swift - Process lifecycle
TierSpec/TierSpec/Services/MCPClientManager.swift  - JSON-RPC client
TierSpec/TierSpec/Services/MCPToolClient.swift     - Tool wrappers (20 tools)
TierSpec/TierSpec/Services/ConfigManager.swift     - Config storage
TierSpec/TierSpec/Views/SettingsView.swift         - Settings UI
```

### Build Scripts
```
TierSpec/Scripts/bundle-node.sh        - Node.js bundling
TierSpec/Scripts/verify-bundling.sh    - Verification
TierSpec/Scripts/README.md             - Documentation
```

---

## How to Continue

### Step 1: Complete Wave 2 (MCP Integration)

Start with W2.T2 - Replace ItemRepository:

```swift
// Example refactoring pattern:
// OLD (SwiftData):
func create(_ item: TierItem) throws {
    modelContext.insert(item)
    try modelContext.save()
}

// NEW (MCP):
func create(type: String, title: String, parentId: String?) async throws -> TierItemDTO {
    let result = try await mcpClient.createItem(
        type: type,
        title: title,
        parentId: parentId
    )
    return try TierItemDTO(from: result)
}
```

### Step 2: Build and Test

After Wave 2 completion:
1. Open TierSpec.xcodeproj in Xcode
2. Add Run Script build phase (see Scripts/README.md)
3. Build project (⌘B)
4. Fix any compilation errors
5. Run app (⌘R)
6. Test MCP connection

### Step 3: Continue with Wave 3

Implement UI transformation:
1. Create MainView with 3-column layout
2. Add AI input bar
3. Build suggestion UI components
4. Integrate AI workflow

### Step 4: Testing & Polish (Wave 4)

Write tests and add error handling.

### Step 5: Final Verification (Wave 5)

Complete end-to-end testing and create production build.

---

## Key Architecture Decisions

### ADR-001: Full MCP Architecture ✅
Swift client spawns Node.js MCP server, communicates via stdio transport.

### ADR-002: Bundle Node.js ✅
Node.js runtime (~50MB) bundled inside app for out-of-box functionality.

### ADR-003: Fresh Start Data ✅
No migration from SwiftData. Clean slate for MCP architecture.

### ADR-004: AI in MCP Server ✅
AI integration in TypeScript with UI settings for API keys.

### ADR-005: New MainView ✅
Create new 3-column MainView, keep ContentView temporarily for reference.

### ADR-006: Top Bar AI Input ✅
Natural language input always visible at top of window.

### ADR-007: Full AI UI ✅
Complete suggestion UI with confidence scores and reasoning.

### ADR-008: Models + Integration Tests ✅
Skip UI tests for MVP, focus on models and integration.

---

## Dependencies

### npm install Status
**Issue**: npm install was running in background and may not have completed.

**Resolution**: Before building MCP server, run:
```bash
cd /Users/z/project/tierspec/mcp-server
npm install
npm run build
```

### Xcode Build Phase
**Issue**: Build script not yet added to Xcode project.

**Resolution**: Follow instructions in `TierSpec/Scripts/README.md` to manually add the Run Script build phase.

---

## Testing Strategy

### Unit Tests (W4.T1)
- Test ItemType.allowedChildTypes
- Test StateMachine.assertValidTransition
- Test ActorType enforcement

### Integration Tests (W4.T2)
- Test MCPClientManager.connect()
- Test MCPToolClient.createItem()
- Test AI workflow: input → parse → display

### Manual Testing (W5.T1)
- App launches without errors
- MCP server spawns successfully
- Natural language input works
- AI suggestions display correctly
- Accept/reject workflow functions

---

## Estimated Remaining Time

- **Wave 2**: 7-9 hours (3 tasks)
- **Wave 3**: 11-12 hours (4 tasks)
- **Wave 4**: 10-11 hours (5 tasks)
- **Wave 5**: 5-6 hours (3 tasks)

**Total Remaining**: ~35-40 hours

---

## Success Criteria

Phase 1 MVP is complete when:
- ✅ All 21 tasks marked complete
- ✅ All tests passing (unit + integration)
- ✅ All verification checklist items checked
- ✅ Performance targets met
- ✅ Production build successful
- ✅ Documentation updated

---

## Contact & Resources

- **Implementation Plan**: `.sisyphus/plans/phase1-mvp-implementation.md`
- **Progress Report**: `.sisyphus/progress-report.md`
- **Requirements**: `SPEC.md` (1883 lines)
- **Architecture**: `AGENTS.md`

---

**Status**: Ready for Wave 2 completion  
**Next Task**: W2.T2 - Replace ItemRepository with MCP calls  
**Estimated Completion**: 5-6 days from now with focused work
