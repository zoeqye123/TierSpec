# TierSpec MCP Server

AI-driven project management tool for Harness/Spec Engineers. Part of the TierSpec ecosystem.

## Overview

TierSpec MCP Server provides a Model Context Protocol (MCP) interface for hierarchical project management with:
- 5-level hierarchy: Capability → Feature → Epic → Story → Test Case
- AI-assisted requirement decomposition (suggestion-based)
- SDLC state machine with 13 states
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

## MCP Tools

### Hierarchy Tools (5)

| Tool | Description |
|------|-------------|
| `create_item` | Create item at any level with parent validation |
| `get_item` | Get item with children |
| `move_item` | Reassign item to different parent |
| `reorder_items` | Batch reorder within parent |
| `delete_item` | Soft delete with optional cascade |

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

## State Machine

Valid state transitions:

```
requirement_input → requirement_review
requirement_review → backlog, needs_info
backlog → ai_decomposing
ai_decomposing → backlog (on failure)
in_progress → waiting_for_test
waiting_for_test → testing
testing → acceptance, in_progress (on failure)
acceptance → completed, in_progress (on rejection)
completed → published
* → blocked (global)
blocked → previous_state
* → cancelled (global)
```

## Database Schema

- **items** - Core hierarchical items
- **item_paths** - Closure table for fast subtree queries
- **item_parent_history** - Parent change audit trail
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
│   ├── db/
│   │   ├── client.ts     # SQLite database wrapper
│   │   ├── migrate.ts    # Migration runner
│   │   ├── schema.sql    # Database schema
│   │   └── types.ts      # TypeScript types
│   ├── tools/
│   │   ├── hierarchy.ts  # CRUD operations
│   │   ├── query.ts      # Query operations
│   │   └── workflow.ts   # State transitions
│   └── schemas/
│       ├── hierarchy.ts  # Zod schemas
│       ├── query.ts
│       └── workflow.ts
└── tests/
    ├── server.test.ts
    ├── state-machine.test.ts
    ├── db/
    └── tools/
```

## Security

All tools include MCP security annotations:
- `readOnlyHint` - Read-only operations
- `destructiveHint` - Destructive operations require confirmation
- `idempotentHint` - Safe to retry
- `openWorldHint` - External system access

## License

MIT
