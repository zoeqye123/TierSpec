# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- GitHub Discussions support
- Issue templates (bug report, feature request)
- Pull request template
- Contributing guidelines
- CI/CD with GitHub Actions

## [0.1.0] - 2025-05-03

### Added

#### Core Features

- **4-Level Hierarchy**: Capability → Feature → User Story → Test Case
- **AI-Assisted Planning**: Natural language requirement parsing with confidence scores
- **7-State SDLC Workflow**: `todo` → `in_progress` → `test` → `done` (+ `blocked`, `cancelled`, `needs_info`)
- **Sprint Management**: Create, assign, and track sprint progress
- **Full Audit Trail**: Every change tracked with actor and timestamp

#### MCP Server (TypeScript)

- 20 MCP tools for hierarchy, workflow, sprint, and AI operations
- SQLite database with closure tables for efficient tree queries
- OpenAI integration for AI-powered features
- Comprehensive test suite (152 tests)

#### Mac Client (Swift)

- Native SwiftUI interface
- 3-column NavigationSplitView layout
- Drag-and-drop item reordering
- AI input bar with ⌘K shortcut
- Real-time state management

#### AI Features

- `parse_requirement` - Parse natural language into hierarchy
- `estimate_complexity` - Estimate story points (1-8 Fibonacci scale)
- `detect_dependencies` - Find dependencies between user stories

#### Architecture

- MCP dual-end architecture (stdio transport)
- Actor-based state transitions (human, AI, system)
- Human-in-the-loop validation for all AI suggestions

### Technical Details

- **MCP Server**: TypeScript 5.0+, Node.js 18+
- **Mac Client**: Swift 6.0+, SwiftUI, macOS 14+
- **Database**: SQLite (dev) / PostgreSQL (prod)
- **AI**: OpenAI API

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.1.0 | 2025-05-03 | Initial release |

---

[Unreleased]: https://github.com/zoeqye123/TierSpec/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/zoeqye123/TierSpec/releases/tag/v0.1.0