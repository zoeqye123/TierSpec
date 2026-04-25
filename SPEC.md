# TierSpec - AI-Driven Project Management Tool for Harness/Spec Engineers

> **Version**: 1.1 (Revised after Critique)
> **Last Updated**: 2026-04-25
> **Status**: Ready for Planning Phase

---

## Executive Summary

TierSpec is an MCP-architected project management tool designed for Harness Engineers and Spec Engineers. It combines Paper-style simplicity with JIRA-like hierarchical management, featuring AI-assisted (not autonomous) requirement decomposition and sprint planning.

**Key Differentiator**: AI as a **suggestion engine with human validation**, not an autonomous decision maker.

---

## Table of Contents

1. [Product Positioning](#1-product-positioning)
2. [Core Design Philosophy](#2-core-design-philosophy)
3. [Architecture Overview](#3-architecture-overview)
4. [MCP Server Design](#4-mcp-server-design)
5. [Hierarchical Data Model](#5-hierarchical-data-model)
6. [AI-Assisted Requirement Parsing](#6-ai-assisted-requirement-parsing)
7. [SDLC State Machine](#7-sdlc-state-machine)
8. [Sprint Management](#8-sprint-management)
9. [Test Case Integration](#9-test-case-integration)
10. [Mac Client Design](#10-mac-client-design)
11. [Security Model](#11-security-model)
12. [Audit Trail & Compliance](#12-audit-trail--compliance)
13. [Distribution Strategy](#13-distribution-strategy)
14. [Implementation Roadmap](#14-implementation-roadmap)

---

## 1. Product Positioning

### 1.1 Target Users

| User Type | Primary Needs |
|-----------|---------------|
| Harness Engineer | Test execution tracking, technical story management, test data organization |
| Spec Engineer | Requirement decomposition, traceability, SDLC compliance |
| QA Engineer | Test case management, defect tracking, execution reports |
| Project Manager | Sprint planning, progress visibility, resource allocation |

### 1.2 Core Value Proposition

- **Paper-style Simplicity**: Minimal UI, gesture-driven, no distracting menus
- **Hierarchical Clarity**: Capability → Feature → Epic → Story → Test Case
- **AI-Assisted Planning**: Suggestions with confidence scores, not autonomous decisions
- **Harness Integration**: Native support for test execution with real business data
- **Full SDLC Coverage**: From requirement input to production deployment

---

## 2. Core Design Philosophy

### 2.1 MCP Dual-End Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Mac Desktop Client                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  SwiftUI UI │  │  Drag-Drop  │  │  Real-time Updates  │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                    │              │
│         └────────────────┼────────────────────┘              │
│                          │                                   │
│                    MCP Client SDK                            │
└──────────────────────────┼──────────────────────────────────┘
                           │ stdio transport
                           │
┌──────────────────────────┼──────────────────────────────────┐
│                    MCP Server                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Tools     │  │  Resources  │  │    Prompts          │  │
│  │ (19 max)    │  │  (Data)     │  │  (AI Templates)     │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         └────────────────┼────────────────────┘              │
│                          │                                   │
│  ┌───────────────────────────────────────────────────────┐   │
│  │              Business Logic Layer                      │   │
│  │  • Hierarchy Management  • Sprint Planning             │   │
│  │  • State Transitions     • AI Integration              │   │
│  └───────────────────────────────────────────────────────┘   │
│                          │                                   │
│  ┌───────────────────────────────────────────────────────┐   │
│  │              Data Persistence Layer                    │   │
│  │  • PostgreSQL / SQLite   • Closure Tables              │   │
│  │  • Audit Trail           • Version History             │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 AI as Suggestion Engine

**Core Principle**: AI augments human decision-making, never replaces it.

| AI Capability | Mode | Human Role |
|---------------|------|------------|
| Hierarchy placement suggestion | Suggestion | Review, accept, modify, or reject |
| Epic → Story decomposition | Suggestion | Edit, add, remove generated stories |
| Dependency detection | High-confidence flag | Confirm or dismiss |
| Test case generation | Draft | Review and approve each test case |
| Story point estimation | Suggestion | Final decision authority |
| Sprint capacity planning | Analysis | Make all sprint assignment decisions |

**Visual Distinction**: All AI-suggested content displays:
- Confidence score (0-100%)
- Reasoning trace (why this suggestion)
- Clear "AI-generated" indicator
- One-click accept/modify/reject actions

---

## 3. Architecture Overview

### 3.1 Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **MCP Server** | TypeScript + Node.js | Best ecosystem, official SDK support |
| **Database** | PostgreSQL (prod) / SQLite (dev) | Closure table support, JSONB |
| **Mac Client** | Swift 6 + SwiftUI | Native performance, 10x smaller than Electron |
| **Real-time** | WebSocket (AI) + SSE (updates) | Bidirectional AI streaming, unidirectional status |
| **AI Integration** | OpenAI API / Anthropic API | Proven requirement parsing capabilities |

### 3.2 Key Architectural Decisions

| Decision | Choice | Alternative Rejected | Reason |
|----------|--------|---------------------|--------|
| Transport | stdio | HTTP | Simpler for local desktop app |
| Client Framework | SwiftUI | Electron | 43MB vs 416MB bundle size |
| Data Model | Adjacency List + Closure Table | Nested Sets | Simpler writes, adequate reads |
| Position Field | FLOAT | INTEGER | Single-row drag-drop updates |
| Audit Trail | Append-only event log | In-place updates | Compliance, immutability |

---

## 4. MCP Server Design

### 4.1 Tool Boundaries (Task-Focused, Not API Mirrors)

**Maximum**: 19 tools (under 20 for optimal AI selection)

#### Hierarchy Tools

| Tool | Purpose | Input | Output |
|------|---------|-------|--------|
| `parse_requirement` | Parse natural language into hierarchy suggestion | requirement text, context | suggested hierarchy with confidence scores |
| `create_item` | Create single item at any level | type, title, parent_id, description | created item |
| `move_item` | Reassign item to different parent | item_id, new_parent_id | updated item paths |
| `reorder_items` | Batch reorder within parent | parent_id, item_positions[] | updated positions |
| `delete_item` | Soft delete with cascade option | item_id, cascade_children | deletion result |

#### Sprint Tools

| Tool | Purpose | Input | Output |
|------|---------|-------|--------|
| `create_sprint` | Create new sprint | name, start_date, end_date, capacity | created sprint |
| `assign_to_sprint` | Assign items to sprint | item_ids[], sprint_id | assignment result |
| `suggest_sprint_allocation` | AI-suggest sprint distribution | items[], sprint_capacity | suggestions with confidence |

#### Query Tools

| Tool | Purpose | Input | Output |
|------|---------|-------|--------|
| `get_item_tree` | Get full subtree | root_id, max_depth | hierarchical tree |
| `search_items` | Full-text search | query, filters, pagination | matching items |
| `get_sprint_status` | Sprint progress summary | sprint_id | progress metrics |

#### AI Tools

| Tool | Purpose | Input | Output |
|------|---------|-------|--------|
| `suggest_decomposition` | Break down item into children | parent_item, depth | suggested children with confidence |
| `detect_dependencies` | Find related items | item_id, scope | dependency list with types |
| `generate_test_cases` | Create test cases from story | story_id, test_type | draft test cases |
| `estimate_complexity` | Story point suggestion | item_id, historical_data | estimate with confidence |

#### Workflow Tools

| Tool | Purpose | Input | Output |
|------|---------|-------|--------|
| `transition_state` | Change item status | item_id, new_state, reason | transition result |
| `block_item` | Mark as blocked | item_id, blocker_id, reason | blocked status |
| `resolve_blocker` | Clear blocked status | item_id, resolution | unblocked status |

### 4.2 Tool Annotations (Security)

```typescript
// Example tool with security annotations
server.tool(
  'delete_item',
  {
    item_id: z.string().uuid(),
    cascade_children: z.boolean().default(false)
  },
  {
    description: 'Soft delete an item. Requires confirmation for cascade delete.',
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,        // Requires user confirmation
      idempotentHint: true,
      openWorldHint: false
    }
  },
  async (params) => {
    // Implementation
  }
);
```

### 4.3 Resource Definitions

| Resource | URI Pattern | Description |
|----------|-------------|-------------|
| Item | `item://{id}` | Single item with metadata |
| Item Tree | `tree://{root_id}?depth={n}` | Hierarchical subtree |
| Sprint | `sprint://{id}` | Sprint with assigned items |
| Audit Log | `audit://{entity_type}/{entity_id}` | Audit trail for entity |

---

## 5. Hierarchical Data Model

### 5.1 Item Types and Constraints

```
Capability (Level 1)
├── Feature (Level 2)
│   ├── Epic (Level 3)
│   │   ├── User Story (Level 4)
│   │   │   ├── Business User Story
│   │   │   └── Technical User Story
│   │   └── Test Case (Level 5)
│   └── Epic (Level 3)
│       └── ...
└── Feature (Level 2)
    └── ...
```

**Allowed Parent-Child Relationships**:

| Parent | Allowed Children |
|--------|------------------|
| (root) | Capability |
| Capability | Feature |
| Feature | Epic |
| Epic | User Story |
| User Story | Test Case, Sub-task |
| Test Case | (none - leaf node) |

### 5.2 Database Schema

```sql
-- Core items table (Adjacency List)
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL CHECK (type IN (
        'capability', 'feature', 'epic', 
        'business_story', 'technical_story', 'test_case'
    )),
    parent_id UUID REFERENCES items(id) ON DELETE RESTRICT,
    title TEXT NOT NULL,
    description TEXT,
    
    -- Classification
    status TEXT NOT NULL DEFAULT 'backlog',
    priority INTEGER DEFAULT 0 CHECK (priority BETWEEN 0 AND 100),
    labels TEXT[] DEFAULT '{}',
    
    -- Ordering (FLOAT for drag-drop)
    position FLOAT NOT NULL DEFAULT 0,
    
    -- Estimation
    story_points INTEGER CHECK (story_points IS NULL OR story_points > 0),
    complexity TEXT CHECK (complexity IN ('xs', 's', 'm', 'l', 'xl')),
    
    -- AI metadata
    ai_generated BOOLEAN DEFAULT FALSE,
    ai_confidence FLOAT CHECK (ai_confidence IS NULL OR ai_confidence BETWEEN 0 AND 1),
    ai_reasoning TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,  -- Soft delete
    
    -- Audit
    created_by UUID NOT NULL REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    
    -- Constraints
    CONSTRAINT valid_parent_type CHECK (
        (type = 'capability' AND parent_id IS NULL) OR
        (type = 'feature' AND parent_id IN (SELECT id FROM items WHERE type = 'capability')) OR
        (type = 'epic' AND parent_id IN (SELECT id FROM items WHERE type = 'feature')) OR
        (type IN ('business_story', 'technical_story') AND parent_id IN (SELECT id FROM items WHERE type = 'epic')) OR
        (type = 'test_case' AND parent_id IN (SELECT id FROM items WHERE type IN ('business_story', 'technical_story')))
    )
);

-- Indexes
CREATE INDEX idx_items_parent ON items(parent_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_items_type ON items(type) WHERE deleted_at IS NULL;
CREATE INDEX idx_items_status ON items(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_items_position ON items(parent_id, position) WHERE deleted_at IS NULL;

-- Closure table for fast subtree queries
CREATE TABLE item_paths (
    ancestor_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    descendant_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    depth INTEGER NOT NULL CHECK (depth >= 0),
    PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE INDEX idx_item_paths_descendant ON item_paths(descendant_id);

-- Parent change history (audit trail)
CREATE TABLE item_parent_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    old_parent_id UUID REFERENCES items(id),
    new_parent_id UUID REFERENCES items(id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by UUID NOT NULL REFERENCES users(id),
    reason TEXT
);

-- Trigger: Maintain closure table on insert/update
CREATE OR REPLACE FUNCTION maintain_item_paths() RETURNS TRIGGER AS $$
DECLARE
    is_circular BOOLEAN;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Self-reference
        INSERT INTO item_paths (ancestor_id, descendant_id, depth)
        VALUES (NEW.id, NEW.id, 0);
        
        -- Paths from ancestors
        IF NEW.parent_id IS NOT NULL THEN
            -- Check for circular reference
            SELECT EXISTS(
                SELECT 1 FROM item_paths 
                WHERE ancestor_id = NEW.id AND descendant_id = NEW.parent_id
            ) INTO is_circular;
            
            IF is_circular THEN
                RAISE EXCEPTION 'Circular reference detected: item % cannot be parent of %', NEW.parent_id, NEW.id;
            END IF;
            
            INSERT INTO item_paths (ancestor_id, descendant_id, depth)
            SELECT ancestor_id, NEW.id, depth + 1
            FROM item_paths WHERE descendant_id = NEW.parent_id;
        END IF;
        
    ELSIF TG_OP = 'UPDATE' AND NEW.parent_id IS DISTINCT FROM OLD.parent_id THEN
        -- Log parent change
        INSERT INTO item_parent_history (item_id, old_parent_id, new_parent_id, changed_by)
        VALUES (NEW.id, OLD.parent_id, NEW.parent_id, NEW.updated_by);
        
        -- Delete old paths (except self-reference)
        DELETE FROM item_paths 
        WHERE descendant_id = NEW.id AND depth > 0;
        
        -- Insert new paths
        IF NEW.parent_id IS NOT NULL THEN
            -- Check for circular reference
            SELECT EXISTS(
                SELECT 1 FROM item_paths 
                WHERE ancestor_id = NEW.id AND descendant_id = NEW.parent_id
            ) INTO is_circular;
            
            IF is_circular THEN
                RAISE EXCEPTION 'Circular reference detected';
            END IF;
            
            INSERT INTO item_paths (ancestor_id, descendant_id, depth)
            SELECT ancestor_id, NEW.id, depth + 1
            FROM item_paths WHERE descendant_id = NEW.parent_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER maintain_item_paths_trigger
AFTER INSERT OR UPDATE ON items
FOR EACH ROW EXECUTE FUNCTION maintain_item_paths();

-- Trigger: Auto-update updated_at
CREATE OR REPLACE FUNCTION update_timestamp() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_timestamp_trigger
BEFORE UPDATE ON items
FOR EACH ROW EXECUTE FUNCTION update_timestamp();
```

### 5.3 Query Patterns

```sql
-- Get all descendants of a capability (fast with closure table)
SELECT i.*, ip.depth
FROM items i
JOIN item_paths ip ON i.id = ip.descendant_id
WHERE ip.ancestor_id = $1
ORDER BY ip.depth, i.position;

-- Get direct children only
SELECT * FROM items
WHERE parent_id = $1 AND deleted_at IS NULL
ORDER BY position;

-- Get full tree for display
WITH RECURSIVE item_tree AS (
    SELECT id, type, parent_id, title, position, 0 AS depth, ARRAY[id] AS path
    FROM items WHERE parent_id IS NULL AND deleted_at IS NULL
    
    UNION ALL
    
    SELECT i.id, i.type, i.parent_id, i.title, i.position, t.depth + 1, t.path || i.id
    FROM items i
    JOIN item_tree t ON i.parent_id = t.id
    WHERE i.deleted_at IS NULL
)
SELECT * FROM item_tree ORDER BY path;

-- Move item to new position (drag-drop)
UPDATE items SET position = $2 WHERE id = $1;

-- Renumber positions when precision degrades
WITH ranked AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY position) AS new_pos
    FROM items WHERE parent_id = $1 AND deleted_at IS NULL
)
UPDATE items SET position = ranked.new_pos::FLOAT
FROM ranked WHERE items.id = ranked.id;
```

---

## 6. AI-Assisted Requirement Parsing

### 6.1 Proven Capabilities (What We Build)

| Capability | Maturity | Implementation |
|------------|----------|----------------|
| Epic → Story decomposition | Production | Multi-pass LLM with templates |
| Dependency detection | Production | RAG + semantic similarity |
| Test case generation | Assisted | Worker → Judge → Optimizer pipeline |
| Story point estimation | Calibrated | Historical data + LLM analysis |
| Hierarchy placement suggestion | Experimental | Confidence scoring with human override |

### 6.2 AI Processing Pipeline

```
User Input: Natural Language Requirement
    │
    ▼
┌─────────────────────────────────────┐
│  Phase 1: Understanding             │
│  • Extract domain concepts          │
│  • Identify stakeholders            │
│  • Determine scope                  │
│  Output: Requirement Summary        │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│  Phase 2: Hierarchy Suggestion      │
│  • Match to existing Capabilities   │
│  • Suggest new vs existing Feature  │
│  • Determine Epic granularity       │
│  Output: Hierarchy Placement        │
│          (with confidence score)    │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│  Phase 3: Decomposition             │
│  • Break Epic into User Stories     │
│  • Identify Technical Stories       │
│  • Generate acceptance criteria     │
│  Output: Story Suggestions          │
│          (each with confidence)     │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│  Phase 4: Test Case Generation      │
│  • Generate test cases per story    │
│  • Include test data suggestions    │
│  • Score quality (1-10)             │
│  Output: Draft Test Cases           │
│          (awaiting human review)    │
└─────────────────────────────────────┘
    │
    ▼
User Review: Accept / Modify / Reject Each Item
```

### 6.3 AI Output Schema

```typescript
interface AISuggestion {
  id: string;
  type: 'hierarchy' | 'story' | 'test_case' | 'dependency';
  confidence: number;  // 0.0 - 1.0
  reasoning: string;   // Why this suggestion
  content: ItemContent;
  alternatives?: AISuggestion[];  // Other options considered
  warnings?: string[];  // Potential issues
}

interface DecompositionResult {
  parent_item: Item;
  suggestions: AISuggestion[];
  detected_dependencies: DependencySuggestion[];
  estimated_complexity: {
    story_points: number;
    confidence: number;
    factors: string[];
  };
}

// Example API response for `suggest_decomposition` tool
{
  "parent_item": { "id": "epic-123", "type": "epic", "title": "User Authentication" },
  "suggestions": [
    {
      "id": "sug-1",
      "type": "story",
      "confidence": 0.92,
      "reasoning": "Core authentication flow - required for all user interactions",
      "content": {
        "type": "technical_story",
        "title": "Implement JWT token generation",
        "description": "Create JWT tokens with configurable expiration...",
        "acceptance_criteria": ["Token expires after configured time", "Refresh token flow works"]
      },
      "warnings": []
    },
    {
      "id": "sug-2",
      "type": "story",
      "confidence": 0.78,
      "reasoning": "Security best practice, but may overlap with existing middleware",
      "content": {
        "type": "technical_story",
        "title": "Add rate limiting to auth endpoints",
        "description": "Implement rate limiting..."
      },
      "warnings": ["May conflict with existing API gateway rate limiting"]
    }
  ],
  "detected_dependencies": [
    {
      "from_item": "sug-1",
      "to_item": "existing-epic-456",
      "type": "blocked_by",
      "confidence": 0.85,
      "reasoning": "JWT implementation requires user database schema from User Management epic"
    }
  ],
  "estimated_complexity": {
    "story_points": 13,
    "confidence": 0.72,
    "factors": ["Multiple endpoints", "Security implications", "Integration complexity"]
  }
}
```

### 6.4 Human-in-the-Loop Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI Suggestion Panel                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📋 Suggested Stories for: "User Authentication"               │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ ✅ Implement JWT token generation         [Accept] [Edit] │ │
│  │    Confidence: 92%  •  Story Points: 5                    │ │
│  │    Reasoning: Core authentication flow required...        │ │
│  │    [Show Details ▼]                                       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ ⚠️ Add rate limiting to auth endpoints    [Accept] [Edit] │ │
│  │    Confidence: 78%  •  Story Points: 3                    │ │
│  │    Reasoning: Security best practice...                   │ │
│  │    Warning: May conflict with API gateway                 │ │
│  │    [Show Details ▼]                                       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ 🔗 Detected Dependency                                     │ │
│  │    JWT implementation blocked by User Management epic     │ │
│  │    [View Blocking Epic] [Ignore]                          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  [Accept All] [Accept Selected] [Regenerate] [Cancel]          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.5 Confidence Score Interpretation

| Score | Meaning | Default Action | Visual Indicator |
|-------|---------|----------------|------------------|
| 90-100% | High confidence | Auto-select for review | ✅ Green |
| 70-89% | Good confidence | Show for review | ⚠️ Yellow |
| 50-69% | Moderate confidence | Highlight uncertainty | ⚡ Orange |
| <50% | Low confidence | Require explicit accept | ❌ Red |

---

## 7. SDLC State Machine

### 7.1 Complete State Diagram

```
                              ┌─────────────┐
                              │  需求录入   │
                              └──────┬──────┘
                                     │ [需求提交]
                                     ▼
                              ┌─────────────┐
                              │  需求评审   │◄─────────────────┐
                              └──────┬──────┘                  │
                                     │ [评审通过]              │
                      ┌──────────────┼──────────────┐          │
                      │ [评审失败]   │              │          │
                      ▼              │              ▼          │
               ┌─────────────┐       │       ┌─────────────┐   │
               │  Needs Info │───────┘       │    待办     │   │
               └─────────────┘ [信息补充]    └──────┬──────┘   │
                                                     │ [AI拆解开始]
                                                     ▼
                                              ┌─────────────┐
                                              │  AI拆解中   │
                                              └──────┬──────┘
                                                     │
                              ┌──────────────────────┼──────────────────────┐
                              │ [拆解成功]           │ [拆解失败]           │
                              ▼                      │                      ▼
                       ┌─────────────┐               │               ┌─────────────┐
                       │    进行中   │◄──────────────┘               │    待办     │
                       └──────┬──────┘                               └─────────────┘
                              │ [开发完成]
                              ▼
                       ┌─────────────┐
                       │   待测试    │
                       └──────┬──────┘
                              │ [测试开始]
                              ▼
                       ┌─────────────┐
                       │   测试中    │◄─────────────────┐
                       └──────┬──────┘                  │
                              │ [测试通过]              │ [测试失败]
                              ▼                         │
                       ┌─────────────┐                  │
                       │   验收中    │──────────────────┘
                       └──────┬──────┘ [返工]
                              │ [验收通过]
                              ▼
                       ┌─────────────┐
                       │   已完成    │
                       └──────┬──────┘
                              │ [部署完成]
                              ▼
                       ┌─────────────┐
                       │   已发布    │
                       └─────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Global Transitions                          │
│                                                                  │
│   Any State ────► 阻塞 ────► (return to original state)         │
│   Any State ────► 取消                                        │
│   已发布 ───────► 进行中 (回滚)                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 State Definitions

| State | Description | Entry Criteria | Exit Criteria |
|-------|-------------|----------------|---------------|
| **需求录入** | Initial requirement capture | User creates new requirement | User submits for review |
| **需求评审** | Requirement validation | Requirement submitted | Review approved or rejected |
| **Needs Info** | Missing information | Review failed, info needed | Information provided |
| **待办** | Ready for decomposition | Review passed | AI decomposition started |
| **AI拆解中** | AI processing requirement | Decomposition triggered | Success or failure |
| **进行中** | Active development | Item assigned to sprint | Development complete |
| **待测试** | Ready for QA | Development complete | QA starts testing |
| **测试中** | QA in progress | QA starts test run | Tests pass or fail |
| **验收中** | Stakeholder review | Tests passed | Stakeholder approves |
| **已完成** | Development done | Stakeholder approves | Deployment ready |
| **已发布** | Production deployed | Deployment complete | (terminal state) |
| **阻塞** | Blocked by dependency | Blocker identified | Blocker resolved |
| **取消** | Abandoned | User cancels | (terminal state) |

### 7.3 Transition Rules

```typescript
interface TransitionRule {
  from_state: ItemState;
  to_state: ItemState;
  conditions?: TransitionCondition[];
  validators?: TransitionValidator[];
  post_actions?: TransitionAction[];
}

const transitionRules: TransitionRule[] = [
  // 需求录入 → 需求评审
  {
    from_state: 'requirement_input',
    to_state: 'requirement_review',
    conditions: [
      { field: 'description', check: 'not_empty' },
      { field: 'title', check: 'min_length', value: 10 }
    ]
  },
  
  // 需求评审 → 待办
  {
    from_state: 'requirement_review',
    to_state: 'backlog',
    validators: [
      { type: 'approver_check', role: 'project_manager' }
    ],
    post_actions: [
      { type: 'notify', to: 'assignee' },
      { type: 'set_field', field: 'reviewed_at', value: 'now()' }
    ]
  },
  
  // 需求评审 → Needs Info
  {
    from_state: 'requirement_review',
    to_state: 'needs_info',
    conditions: [
      { field: 'review_comment', check: 'not_empty' }
    ],
    post_actions: [
      { type: 'notify', to: 'creator' }
    ]
  },
  
  // 待办 → AI拆解中
  {
    from_state: 'backlog',
    to_state: 'ai_decomposing',
    conditions: [
      { field: 'type', check: 'in', value: ['epic'] }
    ],
    post_actions: [
      { type: 'trigger_ai', task: 'decompose' }
    ]
  },
  
  // 测试中 → 验收中
  {
    from_state: 'testing',
    to_state: 'acceptance',
    conditions: [
      { field: 'test_results', check: 'all_passed' },
      { field: 'test_cases', check: 'all_executed' }
    ]
  },
  
  // 测试中 → 进行中 (测试失败)
  {
    from_state: 'testing',
    to_state: 'in_progress',
    conditions: [
      { field: 'test_results', check: 'has_failures' }
    ],
    post_actions: [
      { type: 'create_defects', from: 'failed_tests' },
      { type: 'notify', to: 'assignee' }
    ]
  },
  
  // Global: Any → 阻塞
  {
    from_state: '*',  // Wildcard
    to_state: 'blocked',
    conditions: [
      { field: 'blocker_reason', check: 'not_empty' },
      { field: 'blocker_item_id', check: 'exists' }
    ],
    post_actions: [
      { type: 'notify', to: 'blocker_assignee' },
      { type: 'add_label', value: 'blocked' }
    ]
  },
  
  // 阻塞 → (original state)
  {
    from_state: 'blocked',
    to_state: 'previous_state',  // Dynamic
    post_actions: [
      { type: 'remove_label', value: 'blocked' },
      { type: 'notify', to: 'assignee' }
    ]
  }
];
```

### 7.4 Blocked State Detail

**Required Fields When Blocking**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `blocker_reason` | TEXT | ✅ | Why item is blocked |
| `blocker_item_id` | UUID | ✅ | ID of blocking item (or external reference) |
| `blocker_type` | ENUM | ✅ | `dependency`, `resource`, `technical`, `decision` |
| `blocker_detected_at` | TIMESTAMP | Auto | When block was detected |
| `blocker_expected_resolution` | DATE | ⚠️ | Expected unblock date (recommended) |

**Automation**:

```typescript
// Daily blocked item scan
async function scanBlockedItems() {
  const staleThreshold = 3; // days
  
  const staleBlocked = await db.query(`
    SELECT * FROM items 
    WHERE status = 'blocked' 
    AND blocker_detected_at < NOW() - INTERVAL '${staleThreshold} days'
  `);
  
  for (const item of staleBlocked) {
    // Notify stakeholders
    await notifyStakeholders(item, 'blocked_stale');
    
    // Flag in dashboard
    await addFlag(item.id, 'attention_required');
  }
}

// SLA tracking
async function trackBlockedTime() {
  await db.query(`
    INSERT INTO blocked_time_metrics (item_id, blocked_duration, blocker_type)
    SELECT 
      id, 
      NOW() - blocker_detected_at,
      blocker_type
    FROM items 
    WHERE status = 'blocked'
  `);
}
```

---

## 8. Sprint Management

### 8.1 Sprint Data Model

```sql
CREATE TABLE sprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    project_id UUID REFERENCES projects(id),
    
    -- Timeline
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- Capacity
    capacity_points INTEGER NOT NULL,  -- Total story points capacity
    capacity_hours INTEGER,            -- Alternative: hours-based capacity
    
    -- Status
    status TEXT NOT NULL DEFAULT 'planning' 
      CHECK (status IN ('planning', 'active', 'completed', 'cancelled')),
    
    -- Metrics (computed)
    committed_points INTEGER DEFAULT 0,
    completed_points INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES users(id)
);

-- Sprint assignments (with history)
CREATE TABLE sprint_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    sprint_id UUID NOT NULL REFERENCES sprints(id) ON DELETE CASCADE,
    
    -- Timing
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    removed_at TIMESTAMPTZ,
    
    -- Who made the change
    assigned_by UUID REFERENCES users(id),
    removed_by UUID REFERENCES users(id),
    
    -- Reason for removal (if any)
    removal_reason TEXT,
    
    -- Prevent duplicate active assignments
    UNIQUE (item_id, assigned_at)
);

-- Index for current sprint lookup
CREATE INDEX idx_sprint_assignments_current 
ON sprint_assignments(item_id) 
WHERE removed_at IS NULL;

-- Sprint metrics history
CREATE TABLE sprint_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sprint_id UUID NOT NULL REFERENCES sprints(id),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Snapshot metrics
    total_items INTEGER,
    completed_items INTEGER,
    blocked_items INTEGER,
    in_progress_items INTEGER,
    
    -- Point metrics
    committed_points INTEGER,
    completed_points INTEGER,
    remaining_points INTEGER,
    
    -- Velocity
    velocity_trend FLOAT  -- Running average
);
```

### 8.2 Sprint Ball Visualization Concept

```
┌─────────────────────────────────────────────────────────────────┐
│                        Sprint Ball                               │
│                                                                  │
│                    ┌─────────────────┐                          │
│                    │                 │                          │
│              ┌─────┤   Sprint 3     ├─────┐                    │
│              │     │                 │     │                    │
│              │     │   ● ● ●        │     │                    │
│              │     │   ● ●          │     │                    │
│              │     │   ● ● ●        │     │                    │
│              └─────┴─────────────────┴─────┘                    │
│                    │ Capacity: 34/40 pts │                      │
│                    │ 85% Full           │                      │
│                    └─────────────────┘                          │
│                                                                  │
│  Legend:                                                        │
│  ● Completed (green)  ○ In Progress (blue)  ◐ Blocked (red)   │
│                                                                  │
│  [Drag items here to add to sprint]                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**SwiftUI Implementation Sketch**:

```swift
struct SprintBall: View {
    let sprint: Sprint
    let items: [Item]
    
    var fillPercentage: Double {
        Double(sprint.committedPoints) / Double(sprint.capacityPoints)
    }
    
    var body: some View {
        ZStack {
            // Outer circle (capacity)
            Circle()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 4)
                .frame(width: 200, height: 200)
            
            // Fill level
            Circle()
                .fill(
                    fillPercentage > 0.9 ? Color.red.opacity(0.3) :
                    fillPercentage > 0.7 ? Color.yellow.opacity(0.3) :
                    Color.green.opacity(0.3)
                )
                .frame(
                    width: 200 * sqrt(min(fillPercentage, 1.0)),
                    height: 200 * sqrt(min(fillPercentage, 1.0))
                )
            
            // Items as draggable nodes
            ForEach(items) { item in
                ItemNode(item: item)
                    .draggable(item.id.uuidString)
                    .position(item.positionInSprint ?? .zero)
            }
            
            // Center label
            VStack {
                Text("\(sprint.committedPoints)/\(sprint.capacityPoints)")
                    .font(.headline)
                Text("pts")
                    .font(.caption)
            }
        }
        .dropDestination(for: String.self) { droppedIds, location in
            // Handle item drop
            handleDrop(droppedIds, at: location)
            return true
        }
    }
}
```

### 8.3 Sprint Planning Workflow

```
1. AI Analysis Phase
   ├── Scan backlog items
   ├── Calculate team velocity (last 4-6 sprints)
   ├── Identify dependencies
   └── Generate capacity recommendations

2. Suggestion Phase
   ├── AI suggests sprint allocation
   ├── Each suggestion shows:
   │   ├── Confidence score
   │   ├── Reasoning
   │   ├── Dependency warnings
   │   └── Risk factors
   └── User reviews, modifies, accepts

3. Assignment Phase
   ├── Drag-drop items into Sprint Ball
   ├── Real-time capacity meter updates
   ├── Dependency conflicts highlighted
   └── Save sprint plan

4. Execution Phase
   ├── Daily burndown tracking
   ├── Blocked item alerts
   ├── Carry-over detection
   └── Sprint health dashboard
```

---

## 9. Test Case Integration

### 9.1 Test Case Lifecycle

```
Draft
  │ [Review Requested]
  ▼
Ready for Review
  │ [Review Approved]        │ [Review Rejected]
  ▼                          ▼
Approved  ◄───────────────  Rework
  │ [Linked to Story]
  ▼
Active
  │ [Execution Started]
  ▼
┌───────────────────────────────────────┐
│           Test Execution              │
├───────────────────────────────────────┤
│  Not Run  │  Passed  │  Failed        │
│     │          │          │           │
│     │          │          ▼           │
│     │          │    Create Defect     │
│     │          │          │           │
│     │          ▼          ▼           │
│     └──────► Closed ◄────────┘        │
│                  │                    │
│                  ▼                    │
│            Obsolete                   │
└───────────────────────────────────────┘
```

### 9.2 Test Case Schema

```sql
CREATE TABLE test_cases (
    id UUID PRIMARY KEY REFERENCES items(id),  -- Inherits from items
    parent_story_id UUID NOT NULL REFERENCES items(id),
    
    -- Test details
    test_type TEXT NOT NULL CHECK (test_type IN (
        'unit', 'integration', 'e2e', 'performance', 'security', 'manual'
    )),
    priority TEXT CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    
    -- Test steps
    steps JSONB NOT NULL DEFAULT '[]',
    -- Example: [
    --   {"step": 1, "action": "Navigate to login", "expected": "Login page displayed"},
    --   {"step": 2, "action": "Enter credentials", "expected": "Fields populated"}
    -- ]
    
    -- Test data
    test_data JSONB,
    -- Example: {"username": "test@example.com", "password": "Test@123"}
    
    -- Pre-conditions
    preconditions TEXT[],
    
    -- Post-conditions
    postconditions TEXT[],
    
    -- Automation
    automated BOOLEAN DEFAULT FALSE,
    automation_script TEXT,  -- Path or reference to automation script
    
    -- Status
    review_status TEXT DEFAULT 'draft' 
      CHECK (review_status IN ('draft', 'ready_for_review', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ
);

-- Test executions
CREATE TABLE test_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_case_id UUID NOT NULL REFERENCES test_cases(id),
    
    -- Execution context
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    executed_by UUID REFERENCES users(id),
    environment TEXT,  -- dev, staging, production
    build_version TEXT,
    
    -- Result
    result TEXT NOT NULL CHECK (result IN ('passed', 'failed', 'blocked', 'skipped')),
    
    -- Evidence
    actual_result TEXT,
    evidence_urls TEXT[],  -- Screenshots, logs, etc.
    
    -- Defect link (if failed)
    defect_id UUID REFERENCES items(id)
);

-- Index for test coverage reporting
CREATE INDEX idx_test_cases_story ON test_cases(parent_story_id);
CREATE INDEX idx_executions_test ON test_executions(test_case_id);
```

### 9.3 Test-Story Integration

```typescript
// Story status reflects test status
async function updateStoryStatusFromTests(storyId: string) {
  const tests = await db.query(`
    SELECT 
      tc.id,
      te.result AS latest_result
    FROM test_cases tc
    LEFT JOIN LATERAL (
      SELECT result FROM test_executions 
      WHERE test_case_id = tc.id 
      ORDER BY executed_at DESC LIMIT 1
    ) te ON true
    WHERE tc.parent_story_id = $1
  `, [storyId]);
  
  const allPassed = tests.every(t => t.latest_result === 'passed');
  const anyFailed = tests.some(t => t.latest_result === 'failed');
  const anyBlocked = tests.some(t => t.latest_result === 'blocked');
  
  if (anyFailed) {
    await transitionState(storyId, 'in_progress', 'Tests failed');
  } else if (anyBlocked) {
    await transitionState(storyId, 'blocked', 'Test blocked');
  } else if (allPassed && tests.length > 0) {
    await transitionState(storyId, 'acceptance', 'All tests passed');
  }
}
```

---

## 10. Mac Client Design

### 10.1 Technology Choices

| Component | Technology | Rationale |
|-----------|------------|-----------|
| UI Framework | SwiftUI | Native performance, declarative syntax |
| Drag-Drop | Native SwiftUI `draggable`/`dropDestination` | First-class support, smooth animations |
| State Management | Combine + ObservableObject | Reactive updates, integration with SwiftUI |
| Networking | URLSession + WebSocket | Native, no third-party dependencies |
| Persistence | Core Data (local cache) | Offline support, conflict resolution |
| AI Streaming | URLSessionWebSocketTask | Real-time AI feedback |

### 10.2 Core Views

```
App
├── MainWindow
│   ├── Sidebar
│   │   ├── CapabilitiesList
│   │   ├── SprintsList
│   │   └── QuickFilters
│   │
│   ├── ContentView
│   │   ├── HierarchyView (main tree)
│   │   ├── SprintBoard (kanban)
│   │   └── SprintBall (visualization)
│   │
│   └── DetailPanel
│       ├── ItemDetail
│       ├── AISuggestionPanel
│       └── TestExecutionPanel
│
├── AISheet (modal)
│   ├── RequirementInput
│   ├── DecompositionProgress
│   └── SuggestionReview
│
└── Settings
    ├── MCPConnection
    ├── AIPreferences
    └── NotificationSettings
```

### 10.3 Drag-Drop Implementation

```swift
// Item Card - Draggable
struct ItemCard: View {
    let item: Item
    
    @State private var isDragging = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                Text(item.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let points = item.storyPoints {
                Text("\(points) pts")
                    .font(.caption)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(isDragging ? Color.gray.opacity(0.2) : Color.clear)
        .cornerRadius(8)
        .draggable(item.id.uuidString) {
            // Drag preview
            ItemCard(item: item)
                .opacity(0.8)
                .onAppear { isDragging = true }
        }
    }
}

// Sprint Column - Drop Destination
struct SprintColumn: View {
    let sprint: Sprint
    @Binding var items: [Item]
    
    @State private var isTargeted = false
    
    var body: some View {
        VStack {
            Text(sprint.name)
                .font(.headline)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        ItemCard(item: item)
                    }
                }
            }
            .dropDestination(for: String.self) { droppedIds, location in
                // Handle dropped items
                for idString in droppedIds {
                    if let itemId = UUID(uuidString: idString) {
                        assignToSprint(itemId: itemId, sprintId: sprint.id)
                    }
                }
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTargeted = targeted
                }
            }
        }
        .padding()
        .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
        )
    }
}
```

### 10.4 AI Feedback UI

```swift
// Streaming AI suggestion panel
struct AISuggestionPanel: View {
    @StateObject private var viewModel: AISuggestionViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            // Header
            HStack {
                ProgressView()
                    .opacity(viewModel.isProcessing ? 1 : 0)
                Text("AI Suggestions")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.suggestions.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Suggestions list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.suggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion) { action in
                            viewModel.handleAction(action, for: suggestion)
                        }
                    }
                }
            }
            
            // Actions
            HStack {
                Button("Accept All") {
                    viewModel.acceptAll()
                }
                .disabled(viewModel.suggestions.isEmpty)
                
                Button("Regenerate") {
                    viewModel.regenerate()
                }
                
                Spacer()
                
                Button("Cancel") {
                    viewModel.cancel()
                }
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

struct SuggestionCard: View {
    let suggestion: AISuggestion
    let onAction: (SuggestionAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            // Title and confidence
            HStack {
                Text(suggestion.content.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                ConfidenceBadge(confidence: suggestion.confidence)
            }
            
            // Reasoning
            Text(suggestion.reasoning)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Warnings
            if let warnings = suggestion.warnings, !warnings.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warnings.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Actions
            HStack {
                Button("Accept") { onAction(.accept) }
                    .buttonStyle(.borderedProminent)
                Button("Edit") { onAction(.edit) }
                    .buttonStyle(.bordered)
                Button("Reject") { onAction(.reject) }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var color: Color {
        if confidence >= 0.9 { return .green }
        if confidence >= 0.7 { return .yellow }
        if confidence >= 0.5 { return .orange }
        return .red
    }
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }
}
```

---

## 11. Security Model

### 11.1 MCP Security Requirements

| Control | Implementation | Priority |
|---------|---------------|----------|
| **User Consent** | Explicit dialog before tool execution | P0 |
| **Tool Annotations** | All tools have `destructiveHint`, `readOnlyHint` | P0 |
| **Input Validation** | Zod schemas on all tool inputs | P0 |
| **Path Validation** | Prevent `../` traversal, scope to project directory | P0 |
| **Rate Limiting** | Max 100 tool calls per minute per user | P1 |
| **Audit Logging** | All tool invocations logged with user, timestamp, params | P1 |

### 11.2 Tool Security Annotations

```typescript
// All tools follow this security pattern
const toolDefinitions = {
  // Read-only tool
  get_item_tree: {
    description: 'Get hierarchical tree of items',
    inputSchema: z.object({
      root_id: z.string().uuid(),
      max_depth: z.number().min(1).max(10).default(5)
    }),
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false
    }
  },
  
  // Destructive tool - requires confirmation
  delete_item: {
    description: 'Soft delete an item. WARNING: May cascade to children.',
    inputSchema: z.object({
      item_id: z.string().uuid(),
      cascade_children: z.boolean().default(false),
      reason: z.string().min(10)
    }),
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,  // UI shows confirmation dialog
      idempotentHint: true,
      openWorldHint: false
    }
  },
  
  // Write tool - moderate risk
  create_item: {
    description: 'Create new item in hierarchy',
    inputSchema: z.object({
      type: z.enum(['capability', 'feature', 'epic', 'business_story', 'technical_story', 'test_case']),
      title: z.string().min(5).max(500),
      parent_id: z.string().uuid().optional(),
      description: z.string().max(10000).optional()
    }),
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false
    }
  }
};
```

### 11.3 User Consent Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Tool Execution Request                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ⚠️  MCP Tool: delete_item                                      │
│                                                                  │
│  This action will:                                              │
│  • Delete "User Authentication Epic"                            │
│  • Cascade delete 5 child stories                               │
│  • Cascade delete 12 test cases                                 │
│                                                                  │
│  Reason: "Replaced by OAuth implementation"                     │
│                                                                  │
│  [Cancel]  [Execute Once]  [Always Allow for Delete]            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 11.4 Permission Model

```sql
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    resource_type TEXT NOT NULL,  -- 'project', 'sprint', 'item'
    resource_id UUID,
    permission_level TEXT NOT NULL CHECK (permission_level IN (
        'read', 'write', 'admin', 'owner'
    )),
    granted_by UUID REFERENCES users(id),
    granted_at TIMESTAMPTZ DEFAULT NOW()
);

-- Row-level security example
CREATE POLICY items_read_policy ON items
    FOR SELECT
    USING (
        -- User has read access to project
        EXISTS (
            SELECT 1 FROM permissions
            WHERE user_id = current_user_id()
            AND resource_type = 'project'
            AND resource_id = items.project_id
            AND permission_level IN ('read', 'write', 'admin', 'owner')
        )
    );
```

---

## 12. Audit Trail & Compliance

### 12.1 Audit Event Schema

```sql
CREATE TABLE audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- When
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Who
    actor_id UUID NOT NULL REFERENCES users(id),
    actor_role TEXT NOT NULL,
    actor_permissions TEXT[] NOT NULL,
    
    -- What
    action_type TEXT NOT NULL CHECK (action_type IN (
        'CREATE', 'UPDATE', 'DELETE', 'STATE_CHANGE', 
        'SPRINT_ASSIGN', 'BLOCK', 'UNBLOCK', 'AI_SUGGEST'
    )),
    entity_type TEXT NOT NULL CHECK (entity_type IN (
        'item', 'sprint', 'test_case', 'test_execution', 'project'
    )),
    entity_id UUID NOT NULL,
    
    -- Changes
    changes JSONB NOT NULL DEFAULT '[]',
    -- Example: [
    --   {"field": "status", "old": "in_progress", "new": "testing"},
    --   {"field": "updated_at", "old": "2026-04-24T10:00:00Z", "new": "2026-04-25T15:30:00Z"}
    -- ]
    
    -- Context
    ip_address INET,
    user_agent TEXT,
    session_id UUID,
    
    -- Reason
    reason TEXT,
    
    -- AI context (if applicable)
    ai_confidence FLOAT,
    ai_reasoning TEXT
);

-- Immutable audit log (prevent modifications)
CREATE INDEX idx_audit_events_entity ON audit_events(entity_type, entity_id);
CREATE INDEX idx_audit_events_actor ON audit_events(actor_id);
CREATE INDEX idx_audit_events_timestamp ON audit_events(timestamp);

-- Trigger to prevent updates/deletes
CREATE FUNCTION prevent_audit_modification() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit events are immutable and cannot be modified or deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_audit_update
BEFORE UPDATE OR DELETE ON audit_events
FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();
```

### 12.2 Audit Query Examples

```sql
-- Get full history for an item
SELECT 
    ae.timestamp,
    u.name AS actor,
    ae.action_type,
    ae.changes,
    ae.reason
FROM audit_events ae
JOIN users u ON ae.actor_id = u.id
WHERE ae.entity_type = 'item' AND ae.entity_id = $1
ORDER BY ae.timestamp DESC;

-- Find all blocked items and their resolution time
SELECT 
    i.id,
    i.title,
    block_event.timestamp AS blocked_at,
    unblock_event.timestamp AS unblocked_at,
    unblock_event.timestamp - block_event.timestamp AS blocked_duration
FROM items i
JOIN audit_events block_event ON 
    block_event.entity_id = i.id AND 
    block_event.action_type = 'BLOCK'
LEFT JOIN audit_events unblock_event ON 
    unblock_event.entity_id = i.id AND 
    unblock_event.action_type = 'UNBLOCK' AND
    unblock_event.timestamp > block_event.timestamp
WHERE i.deleted_at IS NULL;

-- Compliance report: All destructive actions in last 30 days
SELECT 
    ae.timestamp,
    u.name AS actor,
    u.email,
    ae.action_type,
    ae.entity_type,
    ae.ip_address,
    ae.reason
FROM audit_events ae
JOIN users u ON ae.actor_id = u.id
WHERE ae.action_type IN ('DELETE', 'STATE_CHANGE')
AND ae.changes::text LIKE '%"status"%"cancelled"%'
AND ae.timestamp > NOW() - INTERVAL '30 days'
ORDER BY ae.timestamp DESC;
```

### 12.3 Retention Policy

| Event Type | Retention Period | Archive Policy |
|------------|------------------|----------------|
| All events | 7 years | Cold storage after 1 year |
| AI-generated events | 7 years | Include model version in log |
| Security events (auth, permissions) | 7 years | Never archive, always hot |
| Test execution results | 3 years | Aggregate after 1 year |

---

## 13. Distribution Strategy

### 13.1 Split Build Approach (Required for Mac App Store)

```
┌─────────────────────────────────────────────────────────────────┐
│                        Build Targets                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │         Mac App Store Build (Sandboxed)                  │    │
│  │                                                          │    │
│  │  Features:                                               │    │
│  │  ✅ Core UI (Hierarchy, Sprint Board)                   │    │
│  │  ✅ Local SQLite database                               │    │
│  │  ✅ File-based import/export                            │    │
│  │  ❌ No MCP integration (sandbox restriction)            │    │
│  │  ❌ No AI features (requires external API)              │    │
│  │                                                          │    │
│  │  Target: Users who want App Store convenience           │    │
│  │  Update: Automatic via App Store                        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │         Direct Download Build (Full)                     │    │
│  │                                                          │    │
│  │  Features:                                               │    │
│  │  ✅ Full UI + MCP integration                           │    │
│  │  ✅ AI features (OpenAI/Anthropic)                      │    │
│  │  ✅ PostgreSQL support                                   │    │
│  │  ✅ WebSocket real-time updates                         │    │
│  │  ✅ All advanced features                               │    │
│  │                                                          │    │
│  │  Includes:                                               │    │
│  │  • TierSpec.app (main application)                      │    │
│  │  • tierspec-mcp-server (companion binary)               │    │
│  │  • Setup assistant for MCP configuration                │    │
│  │                                                          │    │
│  │  Target: Power users, teams, enterprise                 │    │
│  │  Update: Sparkle framework (auto-update)                │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 13.2 MCP Server Distribution

**Option A: Bundled Binary (Recommended for Direct Download)**
```
TierSpec.app/
├── Contents/
│   ├── MacOS/
│   │   ├── TierSpec              # Main app
│   │   └── tierspec-mcp-server   # Bundled MCP server
│   └── Resources/
│       └── mcp-config.json       # Default MCP config
```

**Option B: Separate Download (For Advanced Users)**
- MCP server available as standalone npm package
- Users install: `npm install -g @tierspec/mcp-server`
- App auto-detects installed server

### 13.3 Feature Matrix by Distribution

| Feature | App Store | Direct Download |
|---------|-----------|-----------------|
| Hierarchy CRUD | ✅ | ✅ |
| Sprint Management | ✅ | ✅ |
| Drag-Drop UI | ✅ | ✅ |
| Local Database | ✅ (SQLite) | ✅ (SQLite/PostgreSQL) |
| MCP Integration | ❌ | ✅ |
| AI Suggestions | ❌ | ✅ |
| Real-time Sync | ❌ | ✅ |
| Test Execution | ⚠️ (Manual) | ✅ (Full) |
| Team Collaboration | ❌ | ✅ |

---

## 14. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-12)

**Goal**: Working MVP with core data model and basic UI

| Week | Deliverables | Success Criteria |
|------|--------------|------------------|
| 1-2 | Project setup, database schema | Schema deployed, migrations work |
| 3-4 | MCP server core (10 tools) | Tools callable from MCP client |
| 5-6 | Basic Mac client UI | Can view/create/edit items |
| 7-8 | Drag-drop hierarchy management | Can reorder, reparent items |
| 9-10 | State machine implementation | All core transitions work |
| 11-12 | Integration testing, bug fixes | All P0 tests pass |

**MVP Scope**:
- ✅ 5-level hierarchy CRUD
- ✅ Basic state transitions
- ✅ Drag-drop reordering
- ✅ Sprint creation and assignment
- ❌ AI features (Phase 2)
- ❌ Advanced visualizations (Phase 3)

### Phase 2: AI Integration (Weeks 13-24)

**Goal**: AI-assisted decomposition and planning

| Week | Deliverables | Success Criteria |
|------|--------------|------------------|
| 13-14 | AI service integration | Can call OpenAI/Anthropic |
| 15-16 | Decomposition pipeline | Generates story suggestions |
| 17-18 | Confidence scoring UI | Shows scores for all suggestions |
| 19-20 | Dependency detection | Detects 80%+ of dependencies |
| 21-22 | Test case generation | Generates valid test drafts |
| 23-24 | Sprint capacity AI | Suggests sprint allocations |

**AI Scope**:
- ✅ Epic → Story decomposition (suggestion-based)
- ✅ Dependency detection (high confidence)
- ✅ Test case generation (with human review)
- ✅ Story point estimation (after calibration)
- ❌ Autonomous hierarchy placement

### Phase 3: Advanced Features (Weeks 25-36)

**Goal**: Full SDLC support and enterprise features

| Week | Deliverables | Success Criteria |
|------|--------------|------------------|
| 25-26 | Complete SDLC state machine | All states and transitions |
| 27-28 | Sprint Ball visualization | Working prototype |
| 29-30 | Audit trail implementation | 7-year retention |
| 31-32 | Test execution integration | Runs tests, reports results |
| 33-34 | Team collaboration features | Multi-user support |
| 35-36 | Polish, performance, documentation | Beta release ready |

### Phase 4: Launch Preparation (Weeks 37-40)

| Week | Deliverables |
|------|--------------|
| 37 | Security audit, penetration testing |
| 38 | Documentation, tutorials, API docs |
| 39 | Beta testing program, feedback collection |
| 40 | App Store submission, website launch |

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **MCP** | Model Context Protocol - JSON-RPC 2.0 based protocol for AI-tool integration |
| **Sprint Ball** | Visual container representing sprint capacity with items as draggable nodes |
| **Closure Table** | Database pattern for fast hierarchical queries |
| **AI Suggestion** | AI-generated proposal requiring human validation |
| **Confidence Score** | 0-100% probability of suggestion correctness |
| **Technical Story** | User story focused on technical implementation |
| **Harness Engineer** | Engineer specializing in test automation frameworks |
| **Spec Engineer** | Engineer focused on requirement specification and analysis |

---

## Appendix B: Reference Implementations

| Source | URL | Relevance |
|--------|-----|-----------|
| MCP Specification | https://modelcontextprotocol.io/specification/2025-11-25 | Protocol reference |
| MCP TypeScript SDK | https://github.com/modelcontextprotocol/typescript-sdk | Server implementation |
| AgentMCP (Swift) | https://github.com/macOS26/AgentMCP | Mac client reference |
| Linear Docs | https://linear.app/docs | Workflow patterns |
| JIRA Best Practices | https://support.atlassian.com/jira-software-cloud/docs/best-practices-for-workflows-in-jira | SDLC patterns |

---

## Appendix C: Decision Log

| Date | Decision | Rationale | Alternatives Considered |
|------|----------|-----------|------------------------|
| 2026-04-25 | AI as suggestion engine | Production tools (JIRA, Linear) use suggestion-based AI | Autonomous AI (rejected: hallucination risk) |
| 2026-04-25 | SwiftUI over Electron | 10x smaller bundle, native performance | Electron (rejected: 416MB bundle) |
| 2026-04-25 | Closure Table for hierarchy | Fast subtree queries, adequate write performance | Nested Sets (rejected: complex reparenting) |
| 2026-04-25 | stdio transport | Simpler for local desktop app | HTTP (rejected: unnecessary complexity) |
| 2026-04-25 | Split build for distribution | App Store sandboxing blocks stdio | Single build (rejected: limits distribution) |

---

**Document Status**: Ready for planning phase
**Next Step**: Invoke Plan Agent for detailed implementation breakdown
**Review Cycle**: Quarterly or after major feature changes
