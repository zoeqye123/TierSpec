# TierSpec - Agent Instructions

> AI-driven project management tool for Harness/Spec Engineers. MCP dual-end architecture.

## Architecture

```
TierSpec/
├── mcp-server/          # TypeScript MCP Server (backend)
│   ├── src/index.ts     # MAIN ENTRYPOINT - stdio transport
│   └── tests/           # Vitest test suite
└── TierSpec/            # Swift Mac Client (frontend)
    └── TierSpec/
        ├── TierSpecApp.swift    # @main entry point
        ├── Models/              # SwiftData models
        ├── Views/               # SwiftUI views
        └── Repositories/        # Data access layer
```

## Commands

### MCP Server
```bash
cd mcp-server
npm run build      # Compile TypeScript → dist/
npm run test       # Run vitest tests
npm run typecheck  # Type check without emit
node dist/index.js # Start MCP server (stdio transport)
```

### Mac Client
```bash
# Build from CLI
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

## SDLC States

7 states with enforced transitions:

```
todo → in_progress → test → done
```

Global states: `blocked`, `cancelled`, `needs_info`

State transitions are validated on Kanban drag-drop. Invalid transitions are rejected.

## Actor Types

Every state transition is tracked with an actor type:

| Actor | Description |
|-------|-------------|
| `human` | User-initiated action. Only human can transition to `done`. |
| `ai` | AI agent suggestion. Cannot mark items as done. |
| `system` | Automated system action (e.g., scheduled cleanup). |

This ensures human oversight on completion. AI can suggest, draft, and update content, but final sign-off requires human action.

## Swift Patterns

### SwiftData Models
- `@Model` macro with `final class`
- Self-referential hierarchy: `parent: TierItem?` / `children: [TierItem]?`
- Inverse relationship: `@Relationship(inverse: \TierItem.parent)`
- Soft delete: `deletedAt: Date?` with `isDeleted` computed property

### Repository Pattern
- `actor ItemRepository` for thread-safe data access
- All calls require `await`
- Uses `FetchDescriptor<TierItem>` with `#Predicate`

### Testing
- Unit tests: Swift Testing framework (`import Testing`, `@Test`, `#expect`)
- In-memory `ModelContainer` for isolation
- UI tests: XCTest

## MCP Server Tools

| Category | Tools |
|----------|-------|
| Hierarchy | `create_item`, `get_item`, `move_item`, `reorder_items`, `delete_item` |
| Query | `get_item_tree`, `search_items`, `list_items` |
| Workflow | `transition_state`, `block_item` |

## Agent Tools

Tools for AI-assisted Sprint processing (manual trigger, not automatic):

| Tool | Description |
|------|-------------|
| `process_sprint_items` | Process all items in current sprint, generate AI suggestions |
| `ask_clarification` | Request clarification from user on ambiguous items |
| `update_story` | Update story content with AI-generated text |

These tools are invoked manually by the user. AI generates content but cannot mark items as done.

## Environment Variables

```bash
TSPEC_MCP_DB=/path/to/tierspec.db    # Database path (default: ~/.tierspec/tierspec.db)
TSPEC_MCP_ACTOR=user-id              # Default actor (default: system)
```

## Notes

- `Item.swift` is legacy template - `TierItem` is the actual model
- AI integration is **suggestion-based** - human validates all AI output
- Position uses `Double` for drag-drop reordering support
- SQLite with closure tables for fast subtree queries
- Full audit trail in `audit_events` table
