-- TierSpec Database Schema
-- SQLite version with closure tables for hierarchical data

-- Enable foreign keys (must be enabled at runtime too)
PRAGMA foreign_keys = ON;

-- Users table (referenced by items)
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,  -- UUID as TEXT
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Core items table (Adjacency List)
CREATE TABLE IF NOT EXISTS items (
    id TEXT PRIMARY KEY,  -- UUID as TEXT
    type TEXT NOT NULL CHECK (type IN (
        'capability', 'feature', 'epic',
        'business_story', 'technical_story', 'test_case'
    )),
    parent_id TEXT REFERENCES items(id) ON DELETE RESTRICT,
    title TEXT NOT NULL,
    description TEXT,

    -- Classification
    status TEXT NOT NULL DEFAULT 'backlog',
    previous_state TEXT,
    priority INTEGER DEFAULT 0 CHECK (priority BETWEEN 0 AND 100),
    labels TEXT DEFAULT '[]',  -- JSON array of strings
    blocker_item_id TEXT,
    blocker_reason TEXT,
    blocker_type TEXT,
    blocker_detected_at TEXT,
    blocker_expected_resolution TEXT,

    -- Ordering (REAL for drag-drop)
    position REAL NOT NULL DEFAULT 0,

    -- Estimation
    story_points INTEGER CHECK (story_points IS NULL OR story_points > 0),
    complexity TEXT CHECK (complexity IN ('xs', 's', 'm', 'l', 'xl')),

    -- AI metadata
    ai_generated INTEGER DEFAULT 0,  -- BOOLEAN as INTEGER
    ai_confidence REAL CHECK (ai_confidence IS NULL OR (ai_confidence >= 0 AND ai_confidence <= 1)),
    ai_reasoning TEXT,

    -- Timestamps
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT,  -- Soft delete (NULL = not deleted)

    -- Audit
    created_by TEXT NOT NULL REFERENCES users(id),
    updated_by TEXT REFERENCES users(id)
);

-- Indexes for items
CREATE INDEX IF NOT EXISTS idx_items_parent ON items(parent_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_type ON items(type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_status ON items(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_position ON items(parent_id, position) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_created_by ON items(created_by);
CREATE INDEX IF NOT EXISTS idx_items_updated_by ON items(updated_by);

-- Audit events for workflow/state changes
CREATE TABLE IF NOT EXISTS audit_events (
    id TEXT PRIMARY KEY,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    actor_id TEXT NOT NULL REFERENCES users(id),
    action_type TEXT NOT NULL CHECK (action_type IN ('STATE_CHANGE', 'BLOCK', 'UNBLOCK')),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('item')),
    entity_id TEXT NOT NULL,
    changes TEXT NOT NULL DEFAULT '[]',
    reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_audit_events_entity ON audit_events(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_events_timestamp ON audit_events(timestamp);

-- Closure table for fast subtree queries
CREATE TABLE IF NOT EXISTS item_paths (
    ancestor_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    descendant_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    depth INTEGER NOT NULL CHECK (depth >= 0),
    PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE INDEX IF NOT EXISTS idx_item_paths_descendant ON item_paths(descendant_id);
CREATE INDEX IF NOT EXISTS idx_item_paths_ancestor ON item_paths(ancestor_id);

-- Parent change history (audit trail)
CREATE TABLE IF NOT EXISTS item_parent_history (
    id TEXT PRIMARY KEY,  -- UUID as TEXT
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    old_parent_id TEXT REFERENCES items(id),
    new_parent_id TEXT REFERENCES items(id),
    changed_at TEXT NOT NULL DEFAULT (datetime('now')),
    changed_by TEXT NOT NULL REFERENCES users(id),
    reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_item_parent_history_item ON item_parent_history(item_id);
CREATE INDEX IF NOT EXISTS idx_item_parent_history_changed_at ON item_parent_history(changed_at);

-- Trigger: Auto-update updated_at on items
CREATE TRIGGER IF NOT EXISTS update_items_timestamp
AFTER UPDATE ON items
FOR EACH ROW
BEGIN
    UPDATE items SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Trigger: Enforce valid parent-child type combinations on INSERT
CREATE TRIGGER IF NOT EXISTS validate_item_parent_type_insert
BEFORE INSERT ON items
FOR EACH ROW
WHEN NEW.parent_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'valid_parent_type')
    WHERE NOT EXISTS (
        SELECT 1
        FROM items parent
        WHERE parent.id = NEW.parent_id
          AND (
              (NEW.type = 'feature' AND parent.type = 'capability') OR
              (NEW.type = 'epic' AND parent.type = 'feature') OR
              (NEW.type = 'business_story' AND parent.type = 'epic') OR
              (NEW.type = 'technical_story' AND parent.type = 'epic') OR
              (NEW.type = 'test_case' AND parent.type IN ('business_story', 'technical_story'))
          )
    );
END;

-- Trigger: Enforce root-only capabilities and validate parent-child type combinations on UPDATE
CREATE TRIGGER IF NOT EXISTS validate_item_parent_type_update
BEFORE UPDATE OF parent_id, type ON items
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'valid_parent_type')
    WHERE NEW.parent_id IS NULL AND NEW.type != 'capability';

    SELECT RAISE(ABORT, 'valid_parent_type')
    WHERE NEW.parent_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM items parent
        WHERE parent.id = NEW.parent_id
          AND (
              (NEW.type = 'feature' AND parent.type = 'capability') OR
              (NEW.type = 'epic' AND parent.type = 'feature') OR
              (NEW.type = 'business_story' AND parent.type = 'epic') OR
              (NEW.type = 'technical_story' AND parent.type = 'epic') OR
              (NEW.type = 'test_case' AND parent.type IN ('business_story', 'technical_story'))
          )
    );
END;

-- Trigger: Prevent non-root item types from being inserted without a parent
CREATE TRIGGER IF NOT EXISTS validate_item_root_type_insert
BEFORE INSERT ON items
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'valid_parent_type')
    WHERE NEW.parent_id IS NULL AND NEW.type != 'capability';
END;

-- Trigger: Detect direct self-parenting on INSERT
CREATE TRIGGER IF NOT EXISTS prevent_self_parent_insert
BEFORE INSERT ON items
FOR EACH ROW
WHEN NEW.parent_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'circular reference')
    WHERE NEW.parent_id = NEW.id;
END;

-- Trigger: Detect circular references before reparenting
CREATE TRIGGER IF NOT EXISTS prevent_circular_reference_update
BEFORE UPDATE OF parent_id ON items
FOR EACH ROW
WHEN NEW.parent_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'circular reference')
    WHERE NEW.parent_id = NEW.id;

    SELECT RAISE(ABORT, 'circular reference')
    WHERE EXISTS (
        SELECT 1
        FROM item_paths
        WHERE ancestor_id = NEW.id
          AND descendant_id = NEW.parent_id
    );
END;

-- Trigger: Maintain closure table on INSERT
-- Self-reference and ancestor paths
CREATE TRIGGER IF NOT EXISTS maintain_item_paths_insert
AFTER INSERT ON items
FOR EACH ROW
BEGIN
    -- Self-reference (depth 0)
    INSERT INTO item_paths (ancestor_id, descendant_id, depth)
    VALUES (NEW.id, NEW.id, 0);

    -- Paths from ancestors (if has parent)
    -- Note: Circular reference check should be done in application layer
    INSERT INTO item_paths (ancestor_id, descendant_id, depth)
    SELECT ip.ancestor_id, NEW.id, ip.depth + 1
    FROM item_paths ip
    WHERE ip.descendant_id = NEW.parent_id;
END;

-- Trigger: Maintain closure table on UPDATE (parent change)
CREATE TRIGGER IF NOT EXISTS maintain_item_paths_update
AFTER UPDATE OF parent_id ON items
FOR EACH ROW WHEN NEW.parent_id IS NOT OLD.parent_id
BEGIN
    -- Log parent change (updated_by must be set before this trigger)
    INSERT INTO item_parent_history (id, item_id, old_parent_id, new_parent_id, changed_by)
    VALUES (
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)), 2) || '-' || substr(hex(randomblob(2)), 1, 1) || '8' || substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6))),
        NEW.id,
        OLD.parent_id,
        NEW.parent_id,
        NEW.updated_by
    );

    -- Delete links from old ancestors into the moved subtree
    DELETE FROM item_paths
    WHERE descendant_id IN (
        SELECT descendant_id
        FROM item_paths
        WHERE ancestor_id = NEW.id
    )
    AND ancestor_id IN (
        SELECT ancestor_id
        FROM item_paths
        WHERE descendant_id = OLD.id
          AND ancestor_id != descendant_id
    );

    -- Insert links from new ancestors into the moved subtree
    INSERT INTO item_paths (ancestor_id, descendant_id, depth)
    SELECT supertree.ancestor_id, subtree.descendant_id, supertree.depth + subtree.depth + 1
    FROM item_paths AS supertree
    JOIN item_paths AS subtree
      ON subtree.ancestor_id = NEW.id
    WHERE supertree.descendant_id = NEW.parent_id;
END;

-- Trigger: Cascade delete paths when item is deleted
CREATE TRIGGER IF NOT EXISTS delete_item_paths_on_delete
AFTER DELETE ON items
FOR EACH ROW
BEGIN
    DELETE FROM item_paths WHERE ancestor_id = OLD.id OR descendant_id = OLD.id;
END;

-- View: Active items (not soft-deleted)
CREATE VIEW IF NOT EXISTS active_items AS
SELECT * FROM items WHERE deleted_at IS NULL;

-- View: Item hierarchy with depth
CREATE VIEW IF NOT EXISTS item_hierarchy AS
SELECT
    i.id,
    i.type,
    i.title,
    i.parent_id,
    ip.ancestor_id,
    ip.depth
FROM items i
JOIN item_paths ip ON i.id = ip.descendant_id
WHERE i.deleted_at IS NULL;

-- Sprints table
CREATE TABLE IF NOT EXISTS sprints (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    
    -- Timeline
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    
    -- Capacity
    capacity_points INTEGER NOT NULL DEFAULT 0,
    
    -- Status
    status TEXT NOT NULL DEFAULT 'planning' CHECK (status IN ('planning', 'active', 'completed', 'cancelled')),
    
    -- Computed metrics
    committed_points INTEGER DEFAULT 0,
    completed_points INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    created_by TEXT NOT NULL REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_sprints_status ON sprints(status);
CREATE INDEX IF NOT EXISTS idx_sprints_dates ON sprints(start_date, end_date);

-- Sprint assignments
CREATE TABLE IF NOT EXISTS sprint_assignments (
    id TEXT PRIMARY KEY,
    item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    sprint_id TEXT NOT NULL REFERENCES sprints(id) ON DELETE CASCADE,
    
    assigned_at TEXT NOT NULL DEFAULT (datetime('now')),
    removed_at TEXT,
    assigned_by TEXT REFERENCES users(id),
    removed_by TEXT REFERENCES users(id),
    removal_reason TEXT,
    
    UNIQUE (item_id, assigned_at)
);

CREATE INDEX IF NOT EXISTS idx_sprint_assignments_item ON sprint_assignments(item_id) WHERE removed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sprint_assignments_sprint ON sprint_assignments(sprint_id);

-- Trigger: Auto-update sprint updated_at
CREATE TRIGGER IF NOT EXISTS update_sprints_timestamp
AFTER UPDATE ON sprints
FOR EACH ROW
BEGIN
    UPDATE sprints SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- View: Current sprint assignments
CREATE VIEW IF NOT EXISTS current_sprint_assignments AS
SELECT 
    sa.item_id,
    sa.sprint_id,
    s.name AS sprint_name,
    s.status AS sprint_status
FROM sprint_assignments sa
JOIN sprints s ON s.id = sa.sprint_id
WHERE sa.removed_at IS NULL;
