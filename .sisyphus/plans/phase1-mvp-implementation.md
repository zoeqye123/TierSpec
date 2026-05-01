# TierSpec Phase 1 MVP - Complete Implementation Plan

**Version**: 1.0  
**Date**: 2026-05-01  
**Status**: Ready for Execution  
**Target**: 100% Phase 1 MVP Completion  
**Estimated Duration**: 40-50 hours (5-7 days)

---

## Executive Summary

This plan transforms TierSpec from a **90% complete standalone Swift app** into a **100% complete MCP-architected AI-powered project management tool**. The critical gap is MCP client-server integration, which enables the AI features that differentiate TierSpec from traditional project management tools.

**Key Deliverables**:
- ✅ Full MCP client-server integration (Swift ↔ TypeScript via stdio)
- ✅ 3-column layout with natural language AI input
- ✅ AI requirement parsing with confidence scoring
- ✅ Complete test coverage (models + integration)
- ✅ Production-ready Phase 1 MVP

**Timeline**: ~40-50 hours (5-7 days with focused work)  
**Complexity**: High (architectural integration, process management, AI integration)  
**Risk Level**: Medium (mitigated with TDD and incremental approach)

---

## Architecture Decision Records (ADRs)

### ADR-001: Full MCP Architecture with Stdio Transport
**Status**: Accepted | **Date**: 2026-05-01

**Decision**: Implement full MCP architecture where Swift client spawns Node.js MCP server as child process and communicates via stdio transport using JSON-RPC.

**Rationale**:
- ✅ Matches specification (Section 2.1 architecture diagram)
- ✅ Enables AI integration in TypeScript (mature ecosystem)
- ✅ Proven pattern from MCP Swift SDK research
- ✅ Clean separation of concerns (UI vs business logic)

**Consequences**:
- Positive: AI features, scalability, matches spec
- Negative: Node.js dependency, increased complexity
- Mitigation: Bundle Node.js runtime, comprehensive error handling

---

### ADR-002: Bundle Node.js Runtime
**Status**: Accepted | **Date**: 2026-05-01

**Decision**: Bundle Node.js runtime (~50MB) inside `TierSpec.app/Contents/MacOS/` for out-of-box functionality.

**Implementation**:
```
TierSpec.app/
├── Contents/
│   ├── MacOS/
│   │   ├── TierSpec                    # Swift binary
│   │   ├── node                        # Node.js runtime (bundled)
│   │   └── tierspec-mcp-server/        # Compiled MCP server
│   │       ├── dist/
│   │       │   └── index.js
│   │       └── node_modules/
```

---

### ADR-003: Fresh Start Data Strategy
**Status**: Accepted | **Date**: 2026-05-01

**Decision**: Remove SwiftData completely. All new projects use MCP server SQLite database. No migration of existing data.

**Rationale**: Simplest implementation, acceptable for pre-release (no production users)

---

### ADR-004: AI Integration in MCP Server
**Status**: Accepted | **Date**: 2026-05-01

**Decision**: Implement AI integration in TypeScript MCP server. Add UI settings panel in Swift for API key configuration.

**API Key Storage**:
- Swift writes to `~/.tierspec/config.json`
- MCP server reads on startup
- Fallback to environment variable `OPENAI_API_KEY`

---

### ADR-005: New MainView with 3-Column Layout
**Status**: Accepted | **Date**: 2026-05-01

**Decision**: Create new `MainView.swift` with 3-column `NavigationSplitView`. Keep `ContentView.swift` temporarily for reference.

**Layout Specification**:
```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
  // Column 1: Hierarchy Tree (280px fixed)
  HierarchyTreeView()
    .navigationSplitViewColumnWidth(280)
} content: {
  // Column 2: Main Content (adaptive)
  MainContentView() // Kanban or Dashboard
    .navigationSplitViewColumnWidth(min: 400, ideal: 600, max: 1000)
} detail: {
  // Column 3: Details Panel (320px fixed)
  DetailsPanelView()
    .navigationSplitViewColumnWidth(320)
}
```

---

### ADR-006: Top Bar Natural Language Input
**Status**: Accepted | **Date**: 2026-05-01

**Decision**: Place natural language input field in top bar, always visible, prominent placement.

**UI Design**:
```
┌─────────────────────────────────────────────────────────────┐
│  [🤖 Describe a requirement...]              [⌘K]  [Settings]│
├─────────────────────────────────────────────────────────────┤
│  Hierarchy  │  Main Content (Kanban)  │  Details Panel      │
```

---

### ADR-007: Full AI UI with Confidence Scoring
**Status**: Accepted | **Date**: 2026-05-01

**Decision**: Implement complete AI suggestion UI with confidence scores, reasoning display, and accept/modify/reject workflow.

**UI Components**:
1. **Confidence Badge**: Color-coded (green/yellow/orange/red)
2. **Reasoning Panel**: Expandable "Why this suggestion?"
3. **Action Buttons**: Accept / Edit / Reject
4. **Preview Mode**: Show changes before applying

---

### ADR-008: Models + Integration Testing
**Status**: Accepted | **Date**: 2026-05-01

**Decision**: Write Swift Testing tests for models/repositories and integration tests for MCP communication. Skip UI tests for MVP.

**Test Coverage**:
- Unit Tests: TierItem, ItemRepository, state machine (~15 tests)
- Integration Tests: MCP client-server communication (~10 tests)
- Total Estimate: ~7 hours

---

## Implementation Waves

### Wave 1: Foundation (Parallel Execution)
**Duration**: ~12-15 hours | **Dependencies**: None

#### W1.T1: Add Node.js Bundling to Build Process
- **Category**: quick | **Estimate**: 2 hours
- **Files**: 
  - Create `TierSpec/Scripts/bundle-node.sh`
  - Update `TierSpec.xcodeproj` build phases
- **Success Criteria**: 
  - Node.js binary copied to `TierSpec.app/Contents/MacOS/node`
  - Executable permissions set
  - Build succeeds without errors

#### W1.T2: Add OpenAI SDK to MCP Server
- **Category**: quick | **Estimate**: 1.5 hours
- **Files**:
  - `mcp-server/package.json` (add `openai` dependency)
  - `mcp-server/src/ai/client.ts` (new)
  - `mcp-server/src/ai/types.ts` (new)
- **Success Criteria**:
  - `npm install` succeeds
  - AIClient class compiles
  - Can instantiate with API key

#### W1.T3: Implement AI Requirement Parser
- **Category**: ultrabrain | **Estimate**: 4 hours
- **Files**:
  - `mcp-server/src/ai/parser.ts` (new)
  - `mcp-server/src/tools/ai.ts` (new)
  - `mcp-server/tests/tools/ai.test.ts` (new)
- **Success Criteria**:
  - `parse_requirement` tool implemented
  - Returns hierarchy suggestion with confidence
  - Handles errors gracefully
  - Tests pass

#### W1.T4: Create MCP Client Manager (Swift)
- **Category**: ultrabrain | **Estimate**: 5 hours
- **Files**:
  - `TierSpec/TierSpec/Services/MCPClientManager.swift` (new)
  - `TierSpec/TierSpec/Services/MCPProcessManager.swift` (new)
  - `TierSpec/TierSpecTests/MCPClientManagerTests.swift` (new)
- **Success Criteria**:
  - Can spawn MCP server process
  - Establishes stdio transport
  - Handles process termination
  - Tests pass

#### W1.T5: Add API Key Settings UI
- **Category**: visual-engineering | **Estimate**: 3 hours
- **Files**:
  - `TierSpec/TierSpec/Views/SettingsView.swift` (new)
  - `TierSpec/TierSpec/Services/ConfigManager.swift` (new)
- **Success Criteria**:
  - Settings window accessible from menu
  - API key field with secure input
  - Saves to `~/.tierspec/config.json`
  - Validates API key format

---

### Wave 2: MCP Integration (Sequential Dependencies)
**Duration**: ~10-12 hours | **Dependencies**: Wave 1 complete

#### W2.T1: Implement MCP Tool Wrappers (Swift)
- **Category**: quick | **Estimate**: 4 hours
- **Files**:
  - `TierSpec/TierSpec/Services/MCPToolClient.swift` (new)
  - `TierSpec/TierSpecTests/MCPToolClientTests.swift` (new)
- **Success Criteria**:
  - Swift methods for all 17 MCP tools
  - Type-safe request/response handling
  - Error mapping (MCPError → Swift Error)
  - Integration tests pass

#### W2.T2: Replace ItemRepository with MCP Calls
- **Category**: quick | **Estimate**: 3 hours
- **Files**:
  - `TierSpec/TierSpec/Repositories/ItemRepository.swift` (modify)
  - `TierSpec/TierSpecTests/ItemRepositoryTests.swift` (modify)
- **Success Criteria**:
  - All CRUD operations use MCP tools
  - Remove SwiftData dependencies
  - Tests pass with mock MCP client
  - Performance acceptable (<100ms per operation)

#### W2.T3: Update TreeStore for MCP
- **Category**: quick | **Estimate**: 2.5 hours
- **Files**:
  - `TierSpec/TierSpec/Stores/TreeStore.swift` (modify)
  - `TierSpec/TierSpecTests/TreeStoreTests.swift` (new)
- **Success Criteria**:
  - Uses MCPToolClient instead of SwiftData
  - Maintains incremental update optimization
  - Cache invalidation works correctly
  - Tests pass

#### W2.T4: Remove SwiftData Models
- **Category**: quick | **Estimate**: 2 hours
- **Files**:
  - Delete `TierSpec/TierSpec/Models/TierItem.swift`
  - Delete `TierSpec/TierSpec/Models/Sprint.swift`
  - Create `TierSpec/TierSpec/Models/DTOs/` (new directory)
  - `TierSpec/TierSpec/Models/DTOs/TierItemDTO.swift` (new)
  - `TierSpec/TierSpec/Models/DTOs/SprintDTO.swift` (new)
- **Success Criteria**:
  - SwiftData removed completely
  - DTOs match MCP server types
  - All views compile
  - No SwiftData imports remain

---

### Wave 3: UI Transformation (Parallel Execution)
**Duration**: ~8-10 hours | **Dependencies**: Wave 2 complete

#### W3.T1: Create MainView with 3-Column Layout
- **Category**: visual-engineering | **Estimate**: 3 hours
- **Files**:
  - `TierSpec/TierSpec/Views/MainView.swift` (new)
  - `TierSpec/TierSpec/Views/MainContentView.swift` (new)
  - `TierSpec/TierSpec/Views/DetailsPanelView.swift` (new)
- **Success Criteria**:
  - 3-column NavigationSplitView
  - Column widths match spec (280px | adaptive | 320px)
  - Column visibility toggles work
  - Responsive to window resize

#### W3.T2: Implement Natural Language Input Bar
- **Category**: visual-engineering | **Estimate**: 2.5 hours
- **Files**:
  - `TierSpec/TierSpec/Views/AIInputBar.swift` (new)
  - `TierSpec/TierSpec/ViewModels/AIInputViewModel.swift` (new)
- **Success Criteria**:
  - Top bar with search-like input field
  - Placeholder text: "Describe a requirement..."
  - ⌘K keyboard shortcut focuses field
  - Loading indicator during AI processing
  - Error handling with user feedback

#### W3.T3: Create AI Suggestion UI Components
- **Category**: visual-engineering | **Estimate**: 3 hours
- **Files**:
  - `TierSpec/TierSpec/Views/AISuggestionView.swift` (new)
  - `TierSpec/TierSpec/Views/ConfidenceBadge.swift` (new)
  - `TierSpec/TierSpec/Views/ReasoningPanel.swift` (new)
- **Success Criteria**:
  - Confidence badge with color coding
  - Expandable reasoning panel
  - Accept/Edit/Reject buttons
  - Preview mode before applying
  - Matches spec mockups

#### W3.T4: Integrate AI Workflow
- **Category**: ultrabrain | **Estimate**: 3 hours
- **Files**:
  - `TierSpec/TierSpec/ViewModels/AIWorkflowViewModel.swift` (new)
  - `TierSpec/TierSpec/Services/AIService.swift` (new)
- **Success Criteria**:
  - User input → MCP `parse_requirement` → display suggestion
  - Accept creates items via MCP `create_item`
  - Edit opens modal with pre-filled data
  - Reject dismisses suggestion
  - Error handling for API failures

---

### Wave 4: Polish & Testing (Parallel Execution)
**Duration**: ~8-10 hours | **Dependencies**: Wave 3 complete

#### W4.T1: Write Model Unit Tests
- **Category**: quick | **Estimate**: 2 hours
- **Files**:
  - `TierSpec/TierSpecTests/Models/ItemTypeTests.swift` (new)
  - `TierSpec/TierSpecTests/Models/ItemStatusTests.swift` (new)
  - `TierSpec/TierSpecTests/Models/StateMachineTests.swift` (new)
- **Success Criteria**:
  - Test all ItemType validation rules
  - Test all state transitions
  - Test actor type enforcement
  - 100% coverage for models

#### W4.T2: Write Integration Tests
- **Category**: quick | **Estimate**: 4 hours
- **Files**:
  - `TierSpec/TierSpecTests/Integration/MCPIntegrationTests.swift` (new)
  - `TierSpec/TierSpecTests/Integration/AIWorkflowTests.swift` (new)
- **Success Criteria**:
  - Test full MCP client-server communication
  - Test AI requirement parsing flow
  - Test error propagation
  - Test process lifecycle

#### W4.T3: Update App Entry Point
- **Category**: quick | **Estimate**: 1 hour
- **Files**:
  - `TierSpec/TierSpec/TierSpecApp.swift` (modify)
- **Success Criteria**:
  - App launches with MainView
  - MCP server starts automatically
  - Settings accessible from menu
  - No SwiftData initialization

#### W4.T4: Add Error Handling & Logging
- **Category**: quick | **Estimate**: 2 hours
- **Files**:
  - `TierSpec/TierSpec/Services/Logger.swift` (new)
  - `TierSpec/TierSpec/Views/ErrorBanner.swift` (new)
- **Success Criteria**:
  - Structured logging to console
  - User-friendly error messages
  - Error banner for transient errors
  - Alert dialogs for critical errors

#### W4.T5: Documentation & README Updates
- **Category**: quick | **Estimate**: 1.5 hours
- **Files**:
  - `README.md` (update)
  - `AGENTS.md` (update)
  - `TierSpec/TierSpec/README.md` (new)
- **Success Criteria**:
  - Updated architecture diagram
  - Build instructions
  - API key setup guide
  - Troubleshooting section

---

### Wave 5: Verification & Deployment (Sequential)
**Duration**: ~4-6 hours | **Dependencies**: Wave 4 complete

#### W5.T1: End-to-End Verification
- **Category**: quick | **Estimate**: 2 hours
- **Verification Checklist**:
  - [ ] App launches without errors
  - [ ] MCP server process spawns successfully
  - [ ] Natural language input accepts text
  - [ ] AI parsing returns suggestions
  - [ ] Confidence scores display correctly
  - [ ] Accept creates items in hierarchy
  - [ ] Reject dismisses suggestions
  - [ ] 3-column layout renders correctly
  - [ ] Hierarchy tree displays items
  - [ ] Kanban board shows items by status
  - [ ] Details panel shows item info
  - [ ] Settings panel saves API key
  - [ ] All tests pass (unit + integration)

#### W5.T2: Performance Testing
- **Category**: quick | **Estimate**: 1.5 hours
- **Performance Targets**:
  - App launch: <2 seconds
  - MCP server spawn: <1 second
  - AI parsing: <5 seconds
  - Item creation: <100ms
  - Tree rendering: <50ms for 1000 items

#### W5.T3: Production Build
- **Category**: quick | **Estimate**: 2 hours
- **Tasks**:
  - Create release build configuration
  - Code signing setup
  - Bundle Node.js runtime
  - Create DMG installer
  - Test installation on clean macOS

---

## Risk Assessment & Mitigation

### Risk 1: Node.js Process Management Complexity
**Severity**: HIGH | **Probability**: MEDIUM

**Impact**: MCP server fails to spawn or crashes unexpectedly

**Mitigation**:
1. Use proven patterns from MCP Swift SDK research
2. Implement comprehensive error handling with retry logic
3. Add process health monitoring (heartbeat)
4. Graceful degradation: show error UI if MCP unavailable
5. Extensive integration testing with process lifecycle

**Contingency**: Fall back to HTTP transport (requires MCP server to run separately)

---

### Risk 2: AI API Rate Limits / Costs
**Severity**: MEDIUM | **Probability**: MEDIUM

**Impact**: Users hit rate limits or unexpected costs

**Mitigation**:
1. Implement client-side rate limiting (max 10 requests/minute)
2. Cache AI responses for identical inputs (24-hour TTL)
3. Show cost estimate before parsing (based on token count)
4. Provide clear documentation on API costs
5. Add "AI Budget" setting (max requests per day)

**Contingency**: Offer local LLM option (Ollama) as fallback

---

### Risk 3: SwiftData Removal Breaking Existing Features
**Severity**: MEDIUM | **Probability**: LOW

**Impact**: Features work differently or break after migration

**Mitigation**:
1. Comprehensive test coverage before removal
2. Side-by-side comparison (old vs new behavior)
3. Keep ContentView.swift temporarily for reference
4. Incremental migration (one view at a time)
5. Rollback plan (git branches)

**Contingency**: Implement temporary dual-storage mode if critical issues found

---

### Risk 4: Performance Degradation with MCP
**Severity**: MEDIUM | **Probability**: LOW

**Impact**: UI feels sluggish due to IPC overhead

**Mitigation**:
1. Implement aggressive caching in Swift client
2. Batch MCP requests where possible
3. Use async/await properly (non-blocking UI)
4. Performance testing with 1000+ items
5. Optimize MCP server queries (already has indexes)

**Contingency**: Implement local cache with background sync

---

### Risk 5: 3-Column Layout Complexity
**Severity**: LOW | **Probability**: LOW

**Impact**: Layout bugs, responsive issues

**Mitigation**:
1. Use proven NavigationSplitView patterns from research
2. Test on multiple screen sizes (13" to 27")
3. Implement column visibility toggles
4. Follow Apple HIG guidelines
5. Manual testing on real hardware

**Contingency**: Simplify to 2-column with drawer for details

---

## Atomic Commit Strategy

### Commit Principles
1. **One logical change per commit**
2. **All tests pass before commit**
3. **Descriptive commit messages** (conventional commits format)
4. **Incremental progress** (commit frequently)

### Wave 1 Commits
```
feat(build): add Node.js bundling to build process
test(build): verify Node.js bundling works
feat(mcp): add OpenAI SDK to MCP server
test(mcp): add AIClient initialization tests
feat(ai): implement requirement parser
test(ai): add requirement parser tests
feat(swift): implement MCP client manager
test(swift): add MCP client manager tests
feat(ui): add API key settings panel
```

### Wave 2 Commits
```
feat(swift): implement MCP tool wrappers
test(swift): add MCP tool wrapper tests
refactor(swift): replace ItemRepository with MCP calls
test(swift): update ItemRepository tests for MCP
refactor(swift): update TreeStore for MCP
test(swift): add TreeStore tests
refactor(swift): remove SwiftData models
build(swift): verify compilation after SwiftData removal
```

### Wave 3 Commits
```
feat(ui): create MainView with 3-column layout
feat(ui): implement natural language input bar
feat(ui): create AI suggestion UI components
feat(ui): integrate AI workflow
```

### Wave 4 Commits
```
test(swift): add model unit tests
test(swift): add integration tests
refactor(swift): update app entry point
feat(swift): add error handling and logging
docs: update README and architecture documentation
```

### Wave 5 Commits
```
test: complete end-to-end verification
perf: verify performance targets met
build: create production release build
```

---

## TDD Verification Plan

### Unit Test Coverage
- **Models**: ItemType, ItemStatus, StateMachine
- **Services**: MCPClientManager, MCPToolClient, ConfigManager
- **ViewModels**: AIInputViewModel, AIWorkflowViewModel
- **Target**: 80%+ coverage for business logic

### Integration Test Coverage
- **MCP Communication**: Request/response cycle, error handling
- **Process Lifecycle**: Spawn, health check, graceful shutdown
- **AI Workflow**: End-to-end requirement parsing
- **Target**: All critical paths covered

### Manual Testing Checklist
- [ ] App launches successfully
- [ ] MCP server spawns and connects
- [ ] Natural language input works
- [ ] AI suggestions display correctly
- [ ] Accept/reject workflow functions
- [ ] 3-column layout responsive
- [ ] All views render correctly
- [ ] Settings persist correctly
- [ ] Error handling works
- [ ] Performance targets met

---

## Summary

**Total Estimated Hours**: 48.5 hours  
**With Parallel Execution**: ~40-45 hours  
**Timeline**: 5-7 days with focused work

**Key Success Factors**:
1. Follow TDD approach (write tests first)
2. Execute waves in order (respect dependencies)
3. Commit frequently (atomic commits)
4. Test continuously (don't accumulate bugs)
5. Monitor performance (catch regressions early)

**Completion Criteria**:
- ✅ All 21 tasks completed
- ✅ All tests passing (unit + integration)
- ✅ All verification checklist items checked
- ✅ Performance targets met
- ✅ Production build successful
- ✅ Documentation updated

**Next Steps**:
1. Review and approve this plan
2. Set up development environment
3. Begin Wave 1 execution
4. Track progress via TODO list
5. Conduct wave-by-wave reviews

---

**Plan Status**: ✅ Ready for Execution  
**Approval Required**: Yes  
**Estimated Start Date**: 2026-05-01  
**Estimated Completion**: 2026-05-08
