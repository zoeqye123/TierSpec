-- Migration: 002-simplify-hierarchy
-- Description: Simplify hierarchy types and status values, add actor_type columns
-- Date: 2026-04-27
--
-- TYPE MIGRATION:
--   epic          → feature
--   business_story → user_story
--   technical_story → user_story
--
-- STATUS MIGRATION:
--   requirement_input, requirement_review, backlog, ai_decomposing → todo
--   in_progress → in_progress (unchanged)
--   waiting_for_test, testing → test
--   acceptance, completed, published → done
--   blocked, cancelled, needs_info → unchanged (global states)

-- ============================================================================
-- STEP 1: Add actor_type columns
-- ============================================================================

-- Add actor_type column to items table
ALTER TABLE items ADD COLUMN actor_type TEXT CHECK (actor_type IN ('human', 'ai', 'system'));

-- Add actor_type column to audit_events table
ALTER TABLE audit_events ADD COLUMN actor_type TEXT CHECK (actor_type IN ('human', 'ai', 'system'));

-- Set default actor_type for existing items (assume human for existing data)
UPDATE items SET actor_type = 'human' WHERE actor_type IS NULL;

-- Set default actor_type for existing audit_events (assume human for existing data)
UPDATE audit_events SET actor_type = 'human' WHERE actor_type IS NULL;

-- ============================================================================
-- STEP 2: Migrate status values (old → new)
-- ============================================================================

-- Migrate early-stage statuses to 'todo'
UPDATE items SET status = 'todo' 
WHERE status IN ('requirement_input', 'requirement_review', 'backlog', 'ai_decomposing');

-- Migrate testing-related statuses to 'test'
UPDATE items SET status = 'test' 
WHERE status IN ('waiting_for_test', 'testing');

-- Migrate completion statuses to 'done'
UPDATE items SET status = 'done' 
WHERE status IN ('acceptance', 'completed', 'published');

-- Note: 'in_progress', 'blocked', 'cancelled', 'needs_info' remain unchanged

-- ============================================================================
-- STEP 3: Migrate type values (old → new)
-- ============================================================================

-- Before migrating types, we need to handle the hierarchy implications:
-- When 'epic' becomes 'feature', its children (business_story/technical_story) 
-- become 'user_story' which is valid under 'feature'.
-- 
-- The order matters: migrate children first, then parents

-- Step 3a: Migrate business_story and technical_story to user_story
-- These items' parent_id remains the same (pointing to what was an 'epic')
UPDATE items SET type = 'user_story' 
WHERE type IN ('business_story', 'technical_story');

-- Step 3b: Migrate epic to feature
-- After children are migrated, we can safely change epic → feature
UPDATE items SET type = 'feature' 
WHERE type = 'epic';

-- ============================================================================
-- STEP 4: Update closure table for hierarchy changes
-- ============================================================================

-- The closure table (item_paths) should be automatically maintained by triggers
-- when we UPDATE items. However, the triggers check parent-child type validity.
--
-- Since we're changing types in a specific order (children first, then parents),
-- and the new hierarchy is valid (feature → user_story), the triggers should
-- handle the closure table updates correctly.
--
-- If any orphaned paths exist due to the type changes, clean them up:
DELETE FROM item_paths 
WHERE ancestor_id NOT IN (SELECT id FROM items WHERE deleted_at IS NULL)
   OR descendant_id NOT IN (SELECT id FROM items WHERE deleted_at IS NULL);

-- ============================================================================
-- STEP 5: Update audit_events to reflect new status/type values
-- ============================================================================

-- Update status values in audit_events changes JSON
-- Note: SQLite doesn't have great JSON manipulation, so we do string replacement
-- This is a best-effort update for the changes field

-- Update status changes in audit_events
UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"requirement_input"', '"status":"todo"')
WHERE changes LIKE '%"status":"requirement_input"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"requirement_review"', '"status":"todo"')
WHERE changes LIKE '%"status":"requirement_review"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"backlog"', '"status":"todo"')
WHERE changes LIKE '%"status":"backlog"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"ai_decomposing"', '"status":"todo"')
WHERE changes LIKE '%"status":"ai_decomposing"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"waiting_for_test"', '"status":"test"')
WHERE changes LIKE '%"status":"waiting_for_test"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"testing"', '"status":"test"')
WHERE changes LIKE '%"status":"testing"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"acceptance"', '"status":"done"')
WHERE changes LIKE '%"status":"acceptance"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"completed"', '"status":"done"')
WHERE changes LIKE '%"status":"completed"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"published"', '"status":"done"')
WHERE changes LIKE '%"status":"published"%';

-- Update type values in audit_events changes JSON
UPDATE audit_events 
SET changes = REPLACE(changes, '"type":"epic"', '"type":"feature"')
WHERE changes LIKE '%"type":"epic"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"type":"business_story"', '"type":"user_story"')
WHERE changes LIKE '%"type":"business_story"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"type":"technical_story"', '"type":"user_story"')
WHERE changes LIKE '%"type":"technical_story"%';

-- ============================================================================
-- STEP 6: Rebuild indexes for performance
-- ============================================================================

-- Rebuild indexes to reflect the migrated data
REINDEX;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- 
-- Summary of changes:
-- 1. Added actor_type column to items and audit_events tables
-- 2. Migrated old status values to new simplified status values
-- 3. Migrated old type values to new simplified type values
-- 4. Cleaned up orphaned closure table entries
-- 5. Updated audit_events to reflect new values
-- 6. Rebuilt indexes
--
-- To rollback this migration, run: 002-simplify-hierarchy-rollback.sql
