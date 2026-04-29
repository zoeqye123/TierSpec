-- Rollback Migration: 002-simplify-hierarchy
-- Description: Rollback simplified hierarchy types and status values
-- Date: 2026-04-27
--
-- WARNING: This rollback assumes the original data was:
--   - Types: epic, business_story, technical_story, capability, feature, test_case
--   - Statuses: requirement_input, requirement_review, backlog, ai_decomposing, 
--               in_progress, waiting_for_test, testing, acceptance, completed, 
--               published, blocked, cancelled, needs_info
--
-- IMPORTANT: Rollback cannot perfectly restore original data because:
--   1. Multiple old statuses map to single new statuses (lossy conversion)
--   2. business_story vs technical_story distinction is lost after migration
--   3. This script assumes all user_story items were originally business_story
--
-- TYPE ROLLBACK:
--   feature → epic (if it has children)
--   feature → feature (if no children - remains feature)
--   user_story → business_story (assumption - cannot distinguish original type)
--
-- STATUS ROLLBACK:
--   todo → backlog (assumption - cannot distinguish original status)
--   in_progress → in_progress (unchanged)
--   test → testing (assumption - cannot distinguish waiting_for_test vs testing)
--   done → completed (assumption - cannot distinguish acceptance/completed/published)
--   blocked, cancelled, needs_info → unchanged

-- ============================================================================
-- STEP 1: Rollback type values (new → old)
-- ============================================================================

-- Rollback user_story to business_story
-- Note: We cannot distinguish between business_story and technical_story after migration
-- This assumes all user_story items were originally business_story
UPDATE items SET type = 'business_story' 
WHERE type = 'user_story';

-- Rollback feature to epic (only if it has children)
-- Features without children remain as features (they were likely original features)
UPDATE items SET type = 'epic' 
WHERE type = 'feature' 
  AND id IN (SELECT parent_id FROM items WHERE parent_id IS NOT NULL);

-- ============================================================================
-- STEP 2: Rollback status values (new → old)
-- ============================================================================

-- Rollback todo to backlog
-- Note: Cannot distinguish between requirement_input, requirement_review, backlog, ai_decomposing
UPDATE items SET status = 'backlog' 
WHERE status = 'todo';

-- Rollback test to testing
-- Note: Cannot distinguish between waiting_for_test and testing
UPDATE items SET status = 'testing' 
WHERE status = 'test';

-- Rollback done to completed
-- Note: Cannot distinguish between acceptance, completed, published
UPDATE items SET status = 'completed' 
WHERE status = 'done';

-- ============================================================================
-- STEP 3: Update audit_events to reflect rolled-back values
-- ============================================================================

-- Rollback status values in audit_events changes JSON
UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"todo"', '"status":"backlog"')
WHERE changes LIKE '%"status":"todo"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"test"', '"status":"testing"')
WHERE changes LIKE '%"status":"test"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"status":"done"', '"status":"completed"')
WHERE changes LIKE '%"status":"done"%';

-- Rollback type values in audit_events changes JSON
UPDATE audit_events 
SET changes = REPLACE(changes, '"type":"user_story"', '"type":"business_story"')
WHERE changes LIKE '%"type":"user_story"%';

UPDATE audit_events 
SET changes = REPLACE(changes, '"type":"feature"', '"type":"epic"')
WHERE changes LIKE '%"type":"feature"%';

-- ============================================================================
-- STEP 4: Rebuild indexes for performance
-- ============================================================================

REINDEX;

-- ============================================================================
-- STEP 5: Remove actor_type columns (SQLite 3.35.0+)
-- ============================================================================

-- Note: SQLite versions before 3.35.0 do not support DROP COLUMN
-- For older SQLite, you would need to:
-- 1. Create new tables without actor_type
-- 2. Copy data
-- 3. Drop old tables
-- 4. Rename new tables

-- For SQLite 3.35.0+:
-- ALTER TABLE items DROP COLUMN actor_type;
-- ALTER TABLE audit_events DROP COLUMN actor_type;

-- For compatibility, we leave the columns in place but set to NULL
UPDATE items SET actor_type = NULL;
UPDATE audit_events SET actor_type = NULL;

-- ============================================================================
-- ROLLBACK COMPLETE
-- ============================================================================
--
-- Summary of changes:
-- 1. Rolled back user_story → business_story
-- 2. Rolled back feature → epic (for items with children)
-- 3. Rolled back todo → backlog
-- 4. Rolled back test → testing
-- 5. Rolled back done → completed
-- 6. Updated audit_events to reflect rolled-back values
-- 7. Cleared actor_type columns (left in place for SQLite compatibility)
-- 8. Rebuilt indexes
--
-- DATA LOSS WARNINGS:
-- - business_story vs technical_story distinction is lost
-- - Original status within each group cannot be determined
-- - actor_type data is cleared but column remains