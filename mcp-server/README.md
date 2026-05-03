# TierSpec MCP Server

AI-driven project management tool for Harness/Spec Engineers. Part of the TierSpec ecosystem.

## Overview

TierSpec MCP Server provides a Model Context Protocol (MCP) interface for hierarchical project management with:
- 4-level hierarchy: Capability → Feature → User Story → Test Case
- AI-assisted requirement decomposition (suggestion-based)
- SDLC state machine with 7 states
- Sprint planning support
- Full audit trail

## Installation

```bash
cd mcp-server
npm install
npm run build
```

## Usage

### Start MCP Server

```bash
node dist/index.js
```

The server uses stdio transport and can be connected to any MCP-compatible client.

### Configuration

Environment variables:
- `TSPEC_MCP_DB` - Database path (default: `~/.tierspec/tierspec.db`)
- `TSPEC_MCP_ACTOR` - Default actor user ID (default: `system`)
- `OPENAI_API_KEY` - OpenAI API key for AI tools

Legacy compatibility aliases are also accepted:
- `TIERSPEC_MCP_DB_PATH`
- `TIERSPEC_MCP_ACTOR_ID`

## MCP Tools (20 Total)

### Hierarchy Tools (6)

| Tool | Description |
|------|-------------|
| `create_item` | Create item at any level with parent validation |
| `get_item` | Get item with children |
| `move_item` | Reassign item to different parent |
| `reorder_items` | Batch reorder within parent |
| `delete_item` | Soft delete with optional cascade |
| `update_item` | Update item fields |

### Query Tools (3)

| Tool | Description |
|------|-------------|
| `get_item_tree` | Get subtree using closure table |
| `search_items` | Full-text search with pagination |
| `list_items` | List items with filters |

### Workflow Tools (2)

| Tool | Description |
|------|-------------|
| `transition_state` | Change item status with validation |
| `block_item` | Mark item as blocked |

### Sprint Tools (3)

| Tool | Description |
|------|-------------|
| `create_sprint` | Create a new sprint |
| `assign_to_sprint` | Assign items to sprint |
| `get_sprint_status` | Get sprint status and metrics |

### Agent Tools (3)

| Tool | Description |
|------|-------------|
| `process_sprint_items` | Process sprint items for AI suggestions |
| `ask_clarification` | Request clarification on ambiguous items |
| `update_story` | Update story content |

### AI Tools (3)

| Tool | Description |
|------|-------------|
| `parse_requirement` | Parse natural language into hierarchy suggestions |
| `estimate_complexity` | Estimate story points for user stories |
| `detect_dependencies` | Detect dependencies between stories |

## State Machine (7 States)

Valid state transitions:

```
todo → in_progress → test → done
```

Global states available from any state:
- `blocked` - Item is blocked by dependency
- `cancelled` - Item is cancelled
- `needs_info` - Item needs more information

Special rules:
- Only human actors can transition to `done`
- Blocked items return to their previous state when unblocked

## Database Schema

- **items** - Core hierarchical items
- **item_paths** - Closure table for fast subtree queries
- **item_parent_history** - Parent change audit trail
- **sprints** - Sprint definitions
- **sprint_assignments** - Item-to-sprint assignments
- **users** - User accounts
- **audit_events** - Full audit trail

## Development

```bash
# Run tests
npm test

# Run tests in watch mode
npm run test:watch

# Type check
npm run typecheck

# Build
npm run build
```

## Architecture

```
mcp-server/
├── src/
│   ├── index.ts          # MCP entry point
│   ├── server.ts         # Server factory and tool registration
│   ├── state-machine.ts  # State transition validation
│   ├── ai/
│   │   ├── client.ts     # OpenAI integration
│   │   └── types.ts      # AI type definitions
│   ├── db/
│   │   ├── client.ts     # SQLite database wrapper
│   │   ├── migrate.ts    # Migration runner
│   │   ├── schema.sql    # Database schema
│   │   └── types.ts      # TypeScript types
│   ├── tools/
│   │   ├── hierarchy.ts  # CRUD operations
│   │   ├── query.ts      # Query operations
│   │   ├── workflow.ts   # State transitions
│   │   ├── sprint.ts     # Sprint management
│   │   ├── agent.ts      # AI agent tools
│   │   └ ai.ts           # AI parsing tools
│   └── schemas/
│       ├── hierarchy.ts  # Zod schemas
│       ├── query.ts
│       ├── workflow.ts
│       ├── sprint.ts
│       └── agent.ts
└── tests/
    ├── server.test.ts
    ├── state-machine.test.ts
    ├── ai/
    ├── db/
    └── tools/
```

## Security

All tools include MCP security annotations:
- `readOnlyHint` - Read-only operations
- `destructiveHint` - Destructive operations require confirmation
- `idempotentHint` - Safe to retry
- `openWorldHint` - External system access (AI tools)

## License

MIT