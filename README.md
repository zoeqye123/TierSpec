# TierSpec

AI-driven project management tool for Harness/Spec Engineers. MCP dual-end architecture.

## Overview

TierSpec combines a TypeScript MCP server with a native macOS Swift client to provide:

- **4-Level Hierarchy**: Capability → Feature → User Story → Test Case
- **AI-Assisted Planning**: Natural language requirement parsing with confidence scores
- **7-State SDLC Workflow**: todo → in_progress → test → done (+ blocked/cancelled/needs_info)
- **Sprint Management**: Create, assign, and track sprint progress
- **Full Audit Trail**: Every change tracked with actor and timestamp

## Architecture

```
TierSpec/
├── mcp-server/          # TypeScript MCP Server (backend)
│   ├── src/index.ts     # Main entrypoint - stdio transport
│   ├── src/ai/          # OpenAI integration
│   ├── src/tools/       # 20 MCP tool implementations
│   └── tests/           # Vitest test suite (152 tests)
└── TierSpec/            # Swift Mac Client (frontend)
    └── TierSpec/
        ├── TierSpecApp.swift    # @main entry point
        ├── Models/DTOs/         # Data Transfer Objects
        ├── Views/               # SwiftUI views
        ├── ViewModels/          # Observable view models
        ├── Services/            # MCP client, config, AI services
        ├── Stores/              # State management (TreeStore)
        └── Repositories/        # Data access layer
```

## Quick Start

### 1. Build MCP Server

```bash
cd mcp-server
npm install
npm run build
```

### 2. Run MCP Server

```bash
node dist/index.js
```

### 3. Build Mac Client

Open `TierSpec/TierSpec.xcodeproj` in Xcode and press ⌘R to run.

Or use CLI:
```bash
xcodebuild -project TierSpec/TierSpec.xcodeproj -scheme TierSpec -destination 'platform=macOS' build
```

## MCP Tools (20 Total)

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

1. User enters natural language (⌘K to focus input)
2. `AIWorkflowViewModel.parseRequirement()` calls MCP `parse_requirement`
3. Response mapped to `HierarchySuggestion` tree with confidence scores
4. Displayed in `AISuggestionsSheet` for review
5. User accepts/rejects suggestions
6. Accepted suggestions create items via MCP `create_item`

### AI Tools

- **parse_requirement** - Parse natural language into Capability→Feature→Story→Test hierarchy
- **estimate_complexity** - Estimate story points (1-8 Fibonacci scale)
- **detect_dependencies** - Find dependencies between user stories

## Environment Variables

```bash
TSPEC_MCP_DB=/path/to/tierspec.db    # Database path (default: ~/.tierspec/tierspec.db)
TSPEC_MCP_ACTOR=user-id              # Default actor (default: system)
OPENAI_API_KEY=sk-...                # OpenAI API key for AI tools
```

## Development

### MCP Server

```bash
cd mcp-server
npm run build      # Compile TypeScript
npm run test       # Run 152 Vitest tests
npm run typecheck  # Type check
```

### Mac Client

```bash
# Build
xcodebuild -project TierSpec/TierSpec.xcodeproj -scheme TierSpec -destination 'platform=macOS' build

# Test
xcodebuild -project TierSpec/TierSpec.xcodeproj -scheme TierSpec -destination 'platform=macOS' test
```

## SDLC States

```
todo → in_progress → test → done
```

Global states: `blocked`, `cancelled`, `needs_info`

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

| Actor | Description |
|-------|-------------|
| `human` | User-initiated action. Only human can transition to `done`. |
| `ai` | AI agent suggestion. Cannot mark items as done. |
| `system` | Automated system action. |

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

## Project Status

**Completion**: 18/21 tasks (86%)

| Wave | Status | Tasks |
|------|--------|-------|
| Wave 1: Foundation | ✅ Complete | 5/5 |
| Wave 2: MCP Integration | ✅ Complete | 4/4 |
| Wave 3: UI Transformation | ✅ Complete | 4/4 |
| Wave 4: Polish & Testing | ✅ Complete | 5/5 |
| Wave 5: Verification | ⏳ Requires Xcode IDE | 0/3 |

### MCP Server ✅
- TypeScript: ✅ No errors
- Build: ✅ Success
- Tests: ✅ 152/152 passing

### Swift Client ✅
- Code: ✅ 38 Swift files
- Architecture: ✅ All components implemented
- Build: Requires Xcode IDE

### Verification

Run the verification script:
```bash
cd mcp-server
./scripts/verify-wave5.sh
```

See `.sisyphus/wave5-verification-report.md` for detailed status.

## License

MIT
