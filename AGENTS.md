# TierSpec - Agent Instructions

> AI-driven project management tool for Harness/Spec Engineers. MCP dual-end architecture.

## Architecture

```
TierSpec/
├── mcp-server/          # TypeScript MCP Server (backend)
│   ├── src/index.ts     # MAIN ENTRYPOINT - stdio transport
│   ├── src/ai/          # OpenAI integration for requirement parsing
│   ├── src/tools/       # MCP tool implementations (20 tools)
│   └── tests/           # Vitest test suite (152 tests)
└── TierSpec/            # Swift Mac Client (frontend)
    └── TierSpec/
        ├── TierSpecApp.swift    # @main entry point
        ├── Models/DTOs/         # Data Transfer Objects (no SwiftData)
        ├── Views/               # SwiftUI views
        ├── ViewModels/          # Observable view models
        ├── Services/            # MCP client, config, AI services
        ├── Stores/              # State management (TreeStore)
        └── Repositories/        # Data access layer (MCP-based)
```

## Commands

### MCP Server
```bash
cd mcp-server
npm run build      # Compile TypeScript → dist/
npm run test       # Run vitest tests (152 tests)
npm run typecheck  # Type check without emit
node dist/index.js # Start MCP server (stdio transport)
```

### Mac Client
```bash
# Build from CLI (requires Xcode)
xcodebuild -project TierSpec/TierSpec.xcodeproj -scheme TierSpec -destination 'platform=macOS' build

# Run tests
xcodebuild -project TierSpec/TierSpec.xcodeproj -scheme TierSpec -destination 'platform=macOS' test
```

Or open `TierSpec/TierSpec.xcodeproj` in Xcode: ⌘B (build), ⌘R (run), ⌘U (test).

## Hierarchy Model

4-level hierarchy enforced at database and model level:

```
Capability (L1) → Feature (L2) → User Story (L3) → Test Case (L4)
```

- Only `Capability` can be root (no parent)
- `Test Case` is leaf (no children allowed)
- `User Story` can be `Business` or `Technical` subtype
- Parent-child validation in `ItemType.allowedChildTypes`

## SDLC States (7-State Schema)

States with enforced transitions:

```
todo → in_progress → test → done
```

Global states: `blocked`, `cancelled`, `needs_info`

State transitions are validated on Kanban drag-drop. Invalid transitions are rejected.

### State Transition Rules

| From | Valid To |
|------|----------|
| `todo` | `in_progress`, `blocked`, `cancelled`, `needs_info` |
| `in_progress` | `test`, `todo`, `blocked`, `cancelled`, `needs_info` |
| `test` | `done`, `in_progress`, `blocked`, `cancelled`, `needs_info` |
| `done` | (terminal) |
| `blocked` | (return to previous state), `cancelled` |
| `cancelled` | (terminal) |
| `needs_info` | `todo`, `in_progress`, `blocked`, `cancelled` |

## Actor Types

Every state transition is tracked with an actor type:

| Actor | Description |
|-------|-------------|
| `human` | User-initiated action. Only human can transition to `done`. |
| `ai` | AI agent suggestion. Cannot mark items as done. |
| `system` | Automated system action (e.g., scheduled cleanup). |

This ensures human oversight on completion. AI can suggest, draft, and update content, but final sign-off requires human action.

## Swift Patterns

### DTO Models (No SwiftData)
- Plain structs with `Codable` conformance
- Map to MCP server JSON responses
- `TierItemDTO`, `SprintDTO`, `ItemStatusDTO`, `ItemTypeDTO`

### Repository Pattern
- `actor ItemRepository` for thread-safe data access
- All calls require `await`
- Uses `MCPToolClient` for all operations

### View Models
- `@MainActor @Observable` for SwiftUI integration
- `AIWorkflowViewModel` for AI-powered requirement parsing

### Testing
- Unit tests: Swift Testing framework (`import Testing`, `@Test`, `#expect`)
- MCP server tests: Vitest with 152 passing tests

## MCP Server Tools (20 Total)

| Category | Tools |
|----------|-------|
| Hierarchy | `create_item`, `get_item`, `move_item`, `reorder_items`, `delete_item`, `update_item` |
| Query | `get_item_tree`, `search_items`, `list_items` |
| Workflow | `transition_state`, `block_item` |
| Sprint | `create_sprint`, `assign_to_sprint`, `get_sprint_status` |
| Agent | `process_sprint_items`, `ask_clarification`, `update_story` |
| AI | `parse_requirement`, `estimate_complexity`, `detect_dependencies` |

## AI Integration

### Requirement Parsing Flow
1. User enters natural language in `AIInputBar`
2. `AIWorkflowViewModel.parseRequirement()` calls MCP `parse_requirement`
3. Response mapped to `HierarchySuggestion` tree
4. Displayed in `AISuggestionsSheet` with confidence scores
5. User accepts/rejects suggestions
6. Accepted suggestions create items via MCP `create_item`

### AI Tools
- `parse_requirement` - Parse natural language into hierarchy
- `estimate_complexity` - Estimate story points (1-8 Fibonacci)
- `detect_dependencies` - Find dependencies between stories

## Environment Variables

```bash
TSPEC_MCP_DB=/path/to/tierspec.db    # Database path (default: ~/.tierspec/tierspec.db)
TSPEC_MCP_ACTOR=user-id              # Default actor (default: system)
OPENAI_API_KEY=sk-...                # OpenAI API key for AI tools
```

## Key Files

### Swift Client
- `Services/MCPClientManager.swift` - JSON-RPC client, process lifecycle
- `Services/MCPToolClient.swift` - Type-safe wrappers for 20 MCP tools
- `ViewModels/AIWorkflowViewModel.swift` - AI requirement parsing workflow
- `Views/MainView.swift` - 3-column NavigationSplitView layout
- `Views/AI/AIInputBar.swift` - Natural language input with ⌘K shortcut

### MCP Server
- `src/ai/client.ts` - OpenAI integration
- `src/tools/ai.ts` - AI MCP tools
- `src/tools/hierarchy.ts` - CRUD operations
- `src/state-machine.ts` - State transition validation

## Notes

- DTOs replace SwiftData models - no `@Model` macro
- AI integration is **suggestion-based** - human validates all AI output
- Position uses `Double` for drag-drop reordering support
- SQLite with closure tables for fast subtree queries
- Full audit trail in `audit_events` table
- All 152 MCP server tests pass