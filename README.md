<div align="center">

# TierSpec

**AI-Driven Project Management for Harness Engineers**

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/zoeqye123/TierSpec/actions/workflows/ci.yml/badge.svg)](https://github.com/zoeqye123/TierSpec/actions/workflows/ci.yml)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![Swift](https://img.shields.io/badge/Swift-6.0+-FA7343?logo=swift&logoColor=white)](https://swift.org/)
[![MCP](https://img.shields.io/badge/MCP-Protocol-green)](https://modelcontextprotocol.io/)

*Combining Paper's simplicity with JIRA's power, powered by AI suggestions with human validation*

[Features](#features) • [Quick Start](#quick-start) • [Architecture](#architecture) • [Documentation](#documentation)

</div>

---

## Why TierSpec?

As a Harness Engineer, have you experienced:

- 🫠 **JIRA is too heavy**, Paper is too light — nothing fits just right
- 🤯 **Manual requirement decomposition** — slow and error-prone
- 📊 **Sprint planning by gut feeling** — no data-driven insights
- 🔀 **Tool switching fatigue** — requirements, tests, and tracking in separate tools

**TierSpec solves these problems with a unified, AI-assisted workflow.**

---

## Features

### 🤖 AI as Suggestion Engine (Not Autopilot)

```
┌─────────────────────────────────────────────────────────┐
│  User Input: "Add user authentication with OAuth"       │
│                         ↓                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │ AI Suggestion (92% confidence)                   │   │
│  │ • Capability: User Management                    │   │
│  │ • Feature: Authentication                        │   │
│  │ • Stories: OAuth flow, Token refresh, Logout     │   │
│  └─────────────────────────────────────────────────┘   │
│                         ↓                               │
│  [Accept] [Edit] [Reject] [Regenerate]                  │
└─────────────────────────────────────────────────────────┘
```

Every AI suggestion includes:
- **Confidence score** (0-100%)
- **Reasoning trace** (why this suggestion)
- **Human override** (one-click accept/edit/reject)

### 📊 4-Level Hierarchy

```
Capability (L1)
└── Feature (L2)
    └── User Story (L3)
        └── Test Case (L4)
```

- **Closure table** for O(1) subtree queries
- **Drag-and-drop** reordering with position persistence
- **Parent-child validation** enforced at database level

### 🔄 Full SDLC State Machine

```
todo ──► in_progress ──► test ──► done
  │           │           │
  └───────────┴───────────┴──► blocked
                                │
                                └──► cancelled
```

7 states + 3 global states = **Complete lifecycle coverage**

### ⚡ Native Mac Experience

| TierSpec | Electron Apps |
|----------|---------------|
| **43 MB** bundle | 400+ MB bundle |
| **Native** performance | Web tech overhead |
| **SwiftUI** views | DOM rendering |
| **Instant** startup | Slow cold start |

### 🔐 Human-in-the-Loop

| Actor | Can Do | Cannot Do |
|-------|--------|-----------|
| **Human** | All actions | — |
| **AI** | Suggest, draft, update | Mark as `done` |
| **System** | Automated tasks | Modify content |

**Only humans can sign off on completion.** AI assists, never replaces.

---

## Quick Start

### Prerequisites

- Node.js 18+
- Xcode 15+ (for Mac client)
- OpenAI API key (for AI features)

### 1. Clone & Build MCP Server

```bash
git clone https://github.com/zoeqye123/TierSpec.git
cd TierSpec/mcp-server
npm install
npm run build
```

### 2. Run MCP Server

```bash
node dist/index.js
```

### 3. Build Mac Client

Open `TierSpec/TierSpec.xcodeproj` in Xcode and press `⌘R`.

Or via CLI:
```bash
xcodebuild -project TierSpec/TierSpec.xcodeproj \
  -scheme TierSpec \
  -destination 'platform=macOS' build
```

### 4. Configure AI (Optional)

```bash
export OPENAI_API_KEY=sk-your-key-here
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Mac Desktop Client                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  SwiftUI UI │  │  Drag-Drop  │  │  Real-time Updates  │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         └────────────────┼────────────────────┘              │
│                          │                                   │
│                    MCP Client SDK                            │
└──────────────────────────┼──────────────────────────────────┘
                           │ stdio transport
                           │
┌──────────────────────────┼──────────────────────────────────┐
│                    MCP Server                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   20 Tools  │  │  Resources  │  │    AI Integration   │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         └────────────────┼────────────────────┘              │
│                          │                                   │
│  ┌───────────────────────────────────────────────────────┐   │
│  │         SQLite + Closure Tables + Audit Trail          │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### Tech Stack

| Layer | Technology | Why |
|-------|------------|-----|
| **Server** | TypeScript + Node.js | Best MCP SDK support |
| **Database** | SQLite (dev) / PostgreSQL (prod) | Closure tables, JSONB |
| **Client** | Swift 6 + SwiftUI | Native, 10x smaller |
| **AI** | OpenAI API | Proven requirement parsing |
| **Protocol** | MCP (stdio) | Simple, local-first |

---

## MCP Tools (20 Total)

### Hierarchy Management

| Tool | Purpose |
|------|---------|
| `create_item` | Create item at any level |
| `get_item` | Get item with children |
| `move_item` | Reassign to new parent |
| `reorder_items` | Batch reorder siblings |
| `delete_item` | Soft delete (cascade optional) |
| `update_item` | Update fields |

### Query

| Tool | Purpose |
|------|---------|
| `get_item_tree` | Get full subtree |
| `search_items` | Full-text search |
| `list_items` | Filter by parent/type/status |

### Workflow

| Tool | Purpose |
|------|---------|
| `transition_state` | Change state with validation |
| `block_item` | Mark as blocked |

### Sprint

| Tool | Purpose |
|------|---------|
| `create_sprint` | Create new sprint |
| `assign_to_sprint` | Assign items |
| `get_sprint_status` | Progress summary |

### AI

| Tool | Purpose |
|------|---------|
| `parse_requirement` | NL → hierarchy suggestion |
| `estimate_complexity` | Story points (1-8) |
| `detect_dependencies` | Find related items |

### Agent

| Tool | Purpose |
|------|---------|
| `process_sprint_items` | AI process sprint |
| `ask_clarification` | Request user input |
| `update_story` | Update story content |

---

## Documentation

- [SPEC.md](SPEC.md) — Full product specification
- [AGENTS.md](AGENTS.md) — AI agent instructions
- [Architecture Deep Dive](docs/architecture.md) — Coming soon

---

## Development

### MCP Server

```bash
cd mcp-server
npm run build      # Compile TypeScript
npm run test       # Run 152 tests
npm run typecheck  # Type check
```

### Mac Client

```bash
# Build
xcodebuild -project TierSpec/TierSpec.xcodeproj \
  -scheme TierSpec \
  -destination 'platform=macOS' build

# Test
xcodebuild -project TierSpec/TierSpec.xcodeproj \
  -scheme TierSpec \
  -destination 'platform=macOS' test
```

---

## Project Status

| Component | Status | Details |
|-----------|--------|---------|
| **MCP Server** | ✅ Complete | 152 tests passing |
| **Swift Client** | ✅ Complete | 38 files, all features |
| **AI Integration** | ✅ Complete | OpenAI + Anthropic |
| **Documentation** | ✅ Complete | SPEC + AGENTS |
| **Tests** | ✅ Complete | Unit + Integration |

---

## Roadmap

- [ ] **Web Dashboard** — Browser-based access
- [ ] **Team Collaboration** — Multi-user support
- [ ] **GitHub Integration** — Issue sync
- [ ] **Mobile App** — iOS companion
- [ ] **Plugin System** — Custom tools

---

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Model Context Protocol](https://modelcontextprotocol.io/) — The protocol that makes this possible
- [OpenAI](https://openai.com/) — AI-powered requirement parsing
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) — Native UI framework

---

<div align="center">

**[⬆ Back to Top](#tierspec)**

Made with ❤️ by [zoeqye123](https://github.com/zoeqye123)

</div>
