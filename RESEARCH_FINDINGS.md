# TierSpec Research Findings

## 1. Vitest Security Vulnerabilities

### GHSA-8gvc-j273-4wm5 (CVE-2025-24963) - Browser Mode Arbitrary File Access
**Severity**: Medium (CVSS 5.9)
**Affected Versions**: 
- vitest >=2.0.4, <=2.1.8
- vitest >=3.0.0, <=3.0.3

**Fixed in**: 
- vitest >=2.1.9
- vitest >=3.0.4

**Issue**: The `__screenshot-error` handler on the browser mode HTTP server responds with any file on the file system. If the server is exposed to the network via `browser.api.host: true`, attackers can retrieve arbitrary files.

**Fix**: Upgrade to vitest >=2.1.9 or >=3.0.4

### GHSA-9crc-q9x8-hgqq (CVE-2025-24964) - Remote Code Execution via CSWSH
**Severity**: Critical (CVSS 9.7)
**Affected Versions**:
- vitest <=1.6.0
- vitest >=2.0.0, <2.1.8
- vitest >=3.0.0, <3.0.4

**Fixed in**:
- vitest >=1.6.1
- vitest >=2.1.9
- vitest >=3.0.5

**Issue**: When the `api` option is enabled (Vitest UI enables it), the WebSocket server doesn't check Origin headers and lacks authorization. This allows Cross-site WebSocket Hijacking (CSWSH) attacks. Attackers can use `saveTestFile` and `rerun` APIs to inject and execute arbitrary code.

**Fix**: Upgrade to the latest patched version immediately.

### GHSA-4w7w-66w2-5vf9 (CVE-2026-39365) - Vite Path Traversal
**Severity**: Medium (CVSS 6.3)
**Affected Versions**:
- vite <=6.4.1
- vite >=7.0.0, <=7.3.1
- vite >=8.0.0, <=8.0.4

**Fixed in**:
- vite >=6.4.2
- vite >=7.3.2
- vite >=8.0.5

**Issue**: The dev server's handling of `.map` requests for optimized dependencies resolves file paths without restricting `../` segments, allowing retrieval of `.map` files outside the project root when the dev server is exposed to the network.

**Fix**: Upgrade to the latest patched version.

### GHSA-67mh-4wv8-2f99 - esbuild Vulnerability
**Status**: This appears to be related to esbuild dependency pinning issues in packages like vanilla-extract. The vulnerability is tracked in multiple dependency chains.

**Recommendation**: Update all dependencies that pin esbuild to older versions.

## Migration Strategy for TierSpec

Current version in package.json: vitest ^1.6.0

```json
{
  "devDependencies": {
    "vitest": "^3.0.5"  // Upgrade to latest secure version
  }
}
```

**Action Items**:
1. Update vitest to >=3.0.5 immediately
2. Run `npm audit` to check for other vulnerabilities
3. Update all transitive dependencies


## 2. SwiftData Performance Optimization

### N+1 Query Problem

**Current Issue in TierItem.swift**:
The `outlineChildren` computed property and `depth` property cause N+1 queries:

```swift
// PROBLEM: N+1 queries
var outlineChildren: [TierItem] {
    (children ?? [])
        .filter { $0.deletedAt == nil }  // Triggers lazy loading
        .sorted { $0.position < $1.position }
}

var depth: Int {
    var currentDepth = 0
    var currentParent = parent  // Each access triggers a query
    while currentParent != nil {
        currentDepth += 1
        currentParent = currentParent?.parent  // N queries for N levels
    }
    return currentDepth
}
```

**Solution 1: Eager Loading with @Query**

```swift
// In your View, use @Query with relationship prefetching
struct HierarchyView: View {
    @Query(
        filter: #Predicate<TierItem> { $0.parent == nil && $0.deletedAt == nil },
        sort: \TierItem.position,
        animation: .default
    ) 
    var rootItems: [TierItem]
    
    var body: some View {
        List(rootItems) { item in
            ItemRow(item: item)
        }
    }
}
```

**Solution 2: Batch Fetching with FetchDescriptor**

```swift
// In ItemRepository, add batch fetching methods
extension ItemRepository {
    /// Fetch items with prefetched relationships
    func fetchWithChildren(ids: [UUID]) throws -> [TierItem] {
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { ids.contains($0.id) && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.position)]
        )
        
        // SwiftData automatically prefetches relationships in some cases
        // But for explicit control, fetch all and organize in memory
        let items = try modelContext.fetch(descriptor)
        return items
    }
    
    /// Fetch entire subtree in one query (avoiding N+1)
    func fetchSubtree(rootId: UUID) throws -> [TierItem] {
        // Use a single query to get all descendants
        // This requires a closure table or recursive CTE
        // For SwiftData, we need to fetch iteratively but cache results
        var allItems: [TierItem] = []
        var queue: [UUID] = [rootId]
        var visited: Set<UUID> = []
        
        while !queue.isEmpty {
            let batchIds = queue
            queue = []
            
            let descriptor = FetchDescriptor<TierItem>(
                predicate: #Predicate { batchIds.contains($0.id) && $0.deletedAt == nil }
            )
            let items = try modelContext.fetch(descriptor)
            
            for item in items {
                if !visited.contains(item.id) {
                    visited.insert(item.id)
                    allItems.append(item)
                    if let children = item.children {
                        queue.append(contentsOf: children.map { $0.id })
                    }
                }
            }
        }
        
        return allItems
    }
}
```

### Proper Use of @Query Predicates

**Best Practices**:

1. **Use static predicates when possible**:
```swift
// GOOD: Static predicate (compile-time optimized)
@Query(filter: #Predicate<TierItem> { $0.status == .todo && $0.deletedAt == nil })
var todoItems: [TierItem]

// AVOID: Dynamic predicates in computed properties
var filteredItems: [TierItem] {
    let descriptor = FetchDescriptor<TierItem>(
        predicate: #Predicate { $0.status == currentStatus }  // Re-evaluated on every access
    )
    return try? modelContext.fetch(descriptor) ?? []
}
```

2. **Use #Predicate for type-safe queries**:
```swift
// GOOD: Type-safe with #Predicate
let descriptor = FetchDescriptor<TierItem>(
    predicate: #Predicate { item in
        item.deletedAt == nil &&
        (item.title.localizedStandardContains("search") ||
         (item.itemDescription != nil && item.itemDescription!.localizedStandardContains("search")))
    }
)

// AVOID: String-based predicates (not available in SwiftData anyway)
```

3. **Leverage sorting and pagination**:
```swift
// GOOD: Fetch with pagination
func fetchPaged(offset: Int, limit: Int) throws -> [TierItem] {
    var descriptor = FetchDescriptor<TierItem>(
        predicate: #Predicate { $0.deletedAt == nil },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    descriptor.fetchOffset = offset
    return try modelContext.fetch(descriptor)
}
```

### Batch Operations

**Current Issue**: TreeStore calls `loadTree()` after every operation, causing full reloads.

**Solution: Incremental Updates**

```swift
@MainActor
final class TreeStore: ObservableObject {
    @Published private(set) var rootItems: [TierItem] = []
    @Published private(set) var itemCache: [UUID: TierItem] = [:]  // Cache for O(1) lookups
    
    /// Update only the changed item (not full reload)
    func updateItemLocally(_ item: TierItem) {
        // Update cache
        itemCache[item.id] = item
        
        // Update rootItems if needed
        if item.isRoot {
            if let index = rootItems.firstIndex(where: { $0.id == item.id }) {
                rootItems[index] = item
            } else {
                rootItems.append(item)
            }
        }
        
        // No need to reload entire tree
    }
    
    /// Batch update multiple items
    func batchUpdate(_ updates: [TierItem]) async {
        for item in updates {
            itemCache[item.id] = item
        }
        
        // Single UI update
        objectWillChange.send()
    }
}
```

**Batch Insert Pattern**:

```swift
extension ItemRepository {
    /// Batch insert items in a single transaction
    func batchInsert(_ items: [TierItem]) throws {
        try modelContext.transaction {
            for item in items {
                modelContext.insert(item)
            }
            try modelContext.save()
        }
    }
    
    /// Batch update positions
    func batchUpdatePositions(_ updates: [(id: UUID, position: Double)]) throws {
        let ids = updates.map { $0.id }
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let items = try modelContext.fetch(descriptor)
        
        let positionMap = Dictionary(uniqueKeysWithValues: updates)
        for item in items {
            if let newPosition = positionMap[item.id] {
                item.position = newPosition
            }
        }
        
        try modelContext.save()
    }
}
```


## 3. Tree Structure Optimization

### Closure Table Pattern (Already Implemented)

**Current Implementation** (from schema.sql):
The MCP server already uses closure tables correctly:

```sql
-- Closure table for fast subtree queries
CREATE TABLE IF NOT EXISTS item_paths (
    ancestor_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    descendant_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    depth INTEGER NOT NULL CHECK (depth >= 0),
    PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE INDEX IF NOT EXISTS idx_item_paths_descendant ON item_paths(descendant_id);
CREATE INDEX IF NOT EXISTS idx_item_paths_ancestor ON item_paths(ancestor_id);
```

**Advantages**:
- O(1) depth queries: `SELECT depth FROM item_paths WHERE ancestor_id = ? AND descendant_id = ?`
- O(k) subtree queries: `SELECT descendant_id FROM item_paths WHERE ancestor_id = ?`
- O(k) ancestor queries: `SELECT ancestor_id FROM item_paths WHERE descendant_id = ?`

### Efficient Tree Reloading Strategies

**Strategy 1: Incremental Updates with Diff Detection**

```typescript
// In MCP server tools
export async function getIncrementalUpdate(
  db: Database,
  sinceTimestamp: string
): Promise<IncrementalUpdate> {
  // Get items changed since last sync
  const changedItems = db.prepare(`
    SELECT * FROM items 
    WHERE updated_at > ? AND deleted_at IS NULL
    ORDER BY updated_at ASC
  `).all(sinceTimestamp);
  
  // Get deleted items
  const deletedItems = db.prepare(`
    SELECT id FROM items 
    WHERE deleted_at > ?
  `).all(sinceTimestamp);
  
  // Get parent changes (for reparenting)
  const parentChanges = db.prepare(`
    SELECT item_id, old_parent_id, new_parent_id
    FROM item_parent_history
    WHERE changed_at > ?
  `).all(sinceTimestamp);
  
  return { changedItems, deletedItems, parentChanges };
}
```

**Strategy 2: Lazy Loading with Depth Limits**

```typescript
export function getItemTree(
  db: Database,
  rootId: string,
  maxDepth: number = 3
): ItemTreeNode[] {
  // Use closure table to get items within depth limit
  const items = db.prepare(`
    SELECT i.*, ip.depth
    FROM items i
    JOIN item_paths ip ON i.id = ip.descendant_id
    WHERE ip.ancestor_id = ?
      AND ip.depth <= ?
      AND i.deleted_at IS NULL
    ORDER BY ip.depth, i.position
  `).all(rootId, maxDepth);
  
  return buildTree(items);
}
```

**Strategy 3: Prefetch with Batching**

```typescript
export function prefetchTree(
  db: Database,
  rootIds: string[]
): Map<string, ItemTreeNode> {
  // Single query to fetch all trees at once
  const items = db.prepare(`
    SELECT i.*, ip.ancestor_id as root_id, ip.depth
    FROM items i
    JOIN item_paths ip ON i.id = ip.descendant_id
    WHERE ip.ancestor_id IN (${rootIds.map(() => '?').join(',')})
      AND i.deleted_at IS NULL
    ORDER BY ip.ancestor_id, ip.depth, i.position
  `).all(...rootIds);
  
  // Group by root and build trees
  const trees = new Map<string, ItemTreeNode>();
  // ... build tree logic
  
  return trees;
}
```

### Closure Table Maintenance Optimization

**Current Trigger-Based Approach** (from schema.sql):
The triggers automatically maintain the closure table:

```sql
-- Trigger: Maintain closure table on INSERT
CREATE TRIGGER IF NOT EXISTS maintain_item_paths_insert
AFTER INSERT ON items
FOR EACH ROW
BEGIN
    -- Self-reference (depth 0)
    INSERT INTO item_paths (ancestor_id, descendant_id, depth)
    VALUES (NEW.id, NEW.id, 0);

    -- Paths from ancestors
    INSERT INTO item_paths (ancestor_id, descendant_id, depth)
    SELECT ip.ancestor_id, NEW.id, ip.depth + 1
    FROM item_paths ip
    WHERE ip.descendant_id = NEW.parent_id;
END;
```

**Optimization: Batch Operations**

For bulk inserts, disable triggers temporarily:

```typescript
export function batchInsertWithClosure(
  db: Database,
  items: Item[]
): void {
  const transaction = db.transaction(() => {
    // Disable triggers for performance
    db.exec('PRAGMA recursive_triggers = OFF');
    
    try {
      // Insert all items
      const insertStmt = db.prepare(`
        INSERT INTO items (id, type, parent_id, title, ...)
        VALUES (?, ?, ?, ?, ...)
      `);
      
      for (const item of items) {
        insertStmt.run(item.id, item.type, item.parent_id, item.title, ...);
      }
      
      // Manually rebuild closure table for new items
      rebuildClosureTable(db, items.map(i => i.id));
    } finally {
      db.exec('PRAGMA recursive_triggers = ON');
    }
  });
  
  transaction();
}

function rebuildClosureTable(db: Database, itemIds: string[]): void {
  // Batch insert closure paths
  db.prepare(`
    INSERT INTO item_paths (ancestor_id, descendant_id, depth)
    SELECT 
      supertree.ancestor_id,
      subtree.descendant_id,
      supertree.depth + subtree.depth + 1
    FROM item_paths AS supertree
    CROSS JOIN item_paths AS subtree
    WHERE subtree.ancestor_id IN (${itemIds.map(() => '?').join(',')})
      AND supertree.descendant_id IN (
        SELECT parent_id FROM items WHERE id IN (${itemIds.map(() => '?').join(',')})
      )
  `).run(...itemIds, ...itemIds);
}
```


## 4. TypeScript MCP Server Performance

### SQLite Query Optimization

**Current Indexing Strategy** (from schema.sql):

The schema already has good indexes:

```sql
-- Core indexes
CREATE INDEX IF NOT EXISTS idx_items_parent ON items(parent_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_type ON items(type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_status ON items(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_position ON items(parent_id, position) WHERE deleted_at IS NULL;

-- Closure table indexes
CREATE INDEX IF NOT EXISTS idx_item_paths_descendant ON item_paths(descendant_id);
CREATE INDEX IF NOT EXISTS idx_item_paths_ancestor ON item_paths(ancestor_id);
```

**Additional Recommended Indexes**:

```sql
-- For audit trail queries
CREATE INDEX IF NOT EXISTS idx_items_created_by ON items(created_by);
CREATE INDEX IF NOT EXISTS idx_items_updated_by ON items(updated_by);

-- For timestamp-based queries (incremental sync)
CREATE INDEX IF NOT EXISTS idx_items_updated_at ON items(updated_at) WHERE deleted_at IS NULL;

-- For sprint queries
CREATE INDEX IF NOT EXISTS idx_sprint_assignments_active ON sprint_assignments(item_id, sprint_id) WHERE removed_at IS NULL;

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_items_type_status ON items(type, status) WHERE deleted_at IS NULL;
```

### Query Optimization Patterns

**Pattern 1: Use Prepared Statements**

```typescript
// GOOD: Reuse prepared statements
class ItemQueries {
  private stmtGetItem: Statement;
  private stmtGetChildren: Statement;
  
  constructor(private db: Database) {
    this.stmtGetItem = db.prepare('SELECT * FROM items WHERE id = ?');
    this.stmtGetChildren = db.prepare(`
      SELECT * FROM items 
      WHERE parent_id = ? AND deleted_at IS NULL 
      ORDER BY position
    `);
  }
  
  getItem(id: string): Item | undefined {
    return this.stmtGetItem.get(id) as Item | undefined;
  }
  
  getChildren(parentId: string): Item[] {
    return this.stmtGetChildren.all(parentId) as Item[];
  }
}
```

**Pattern 2: Use Transactions for Batch Operations**

```typescript
// GOOD: Single transaction for multiple operations
function batchUpdateItems(db: Database, updates: ItemUpdate[]): void {
  const updateStmt = db.prepare('UPDATE items SET title = ?, status = ? WHERE id = ?');
  
  const updateMany = db.transaction((updates: ItemUpdate[]) => {
    for (const update of updates) {
      updateStmt.run(update.title, update.status, update.id);
    }
  });
  
  updateMany(updates);
}
```

**Pattern 3: Use EXPLAIN QUERY PLAN for Analysis**

```typescript
function analyzeQuery(db: Database, query: string, params: any[]): void {
  const explain = db.prepare(`EXPLAIN QUERY PLAN ${query}`);
  const plan = explain.all(...params);
  console.log('Query Plan:', plan);
  
  // Look for:
  // - "SCAN TABLE" (full table scan - bad)
  // - "SEARCH TABLE USING INDEX" (index usage - good)
  // - "USING COVERING INDEX" (even better - no table access needed)
}

// Example: Analyze a slow query
analyzeQuery(db, `
  SELECT * FROM items 
  WHERE type = ? AND status = ? AND deleted_at IS NULL
`, ['feature', 'in_progress']);
```

### Connection Pooling and Caching

**Pattern: Singleton Database Connection**

```typescript
// In db/client.ts
let dbInstance: Database | null = null;

export function getDatabase(): Database {
  if (!dbInstance) {
    const dbPath = process.env.TSPEC_MCP_DB || path.join(os.homedir(), '.tierspec', 'tierspec.db');
    dbInstance = new Database(dbPath);
    
    // Enable performance optimizations
    dbInstance.pragma('journal_mode = WAL');  // Write-Ahead Logging
    dbInstance.pragma('synchronous = NORMAL');  // Faster writes
    dbInstance.pragma('cache_size = -64000');  // 64MB cache
    dbInstance.pragma('temp_store = MEMORY');  // In-memory temp tables
    
    // Enable foreign keys
    dbInstance.pragma('foreign_keys = ON');
  }
  
  return dbInstance;
}
```

### Query Caching Strategy

```typescript
class CachedQueries {
  private cache = new Map<string, { data: any; timestamp: number }>();
  private ttl: number;
  
  constructor(ttlMs: number = 5000) {
    this.ttl = ttlMs;
  }
  
  get<T>(key: string, queryFn: () => T): T {
    const cached = this.cache.get(key);
    const now = Date.now();
    
    if (cached && now - cached.timestamp < this.ttl) {
      return cached.data as T;
    }
    
    const data = queryFn();
    this.cache.set(key, { data, timestamp: now });
    return data;
  }
  
  invalidate(pattern?: RegExp): void {
    if (!pattern) {
      this.cache.clear();
      return;
    }
    
    for (const key of this.cache.keys()) {
      if (pattern.test(key)) {
        this.cache.delete(key);
      }
    }
  }
}

// Usage
const queryCache = new CachedQueries();

function getRootItems(db: Database): Item[] {
  return queryCache.get('root-items', () => {
    return db.prepare(`
      SELECT * FROM items 
      WHERE parent_id IS NULL AND deleted_at IS NULL 
      ORDER BY position
    `).all() as Item[];
  });
}
```


## 5. Swift Error Handling

### Proper Error Propagation vs Silent Failures

**Current Issue in TreeStore.swift**:
Errors are silently swallowed, leading to poor user experience:

```swift
// PROBLEM: Silent failure - user doesn't know what went wrong
func loadTree() async {
    isLoading = true
    error = nil
    
    do {
        rootItems = try await repository.fetchRoot()
    } catch {
        self.error = error  // Error is set but not shown to user
    }
    
    isLoading = false
}
```

**Solution 1: Explicit Error Types with LocalizedError**

```swift
// Define comprehensive error types
enum TreeError: LocalizedError {
    case itemNotFound(id: UUID)
    case invalidParent(parentId: UUID, childType: ItemType)
    case circularReference(itemId: UUID, targetId: UUID)
    case databaseError(underlying: Error)
    case permissionDenied(action: String)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let id):
            return "Item not found with ID: \(id)"
        case .invalidParent(let parentId, let childType):
            return "Cannot add \(childType.displayName) as child of item \(parentId)"
        case .circularReference(let itemId, let targetId):
            return "Cannot move item \(itemId) to \(targetId) - would create circular reference"
        case .databaseError(let underlying):
            return "Database error: \(underlying.localizedDescription)"
        case .permissionDenied(let action):
            return "Permission denied for action: \(action)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .itemNotFound:
            return "The item may have been deleted. Try refreshing the view."
        case .invalidParent:
            return "Check the hierarchy rules: Capabilities → Features → User Stories → Test Cases"
        case .circularReference:
            return "Choose a different parent that is not a descendant of this item."
        case .databaseError:
            return "Try again. If the problem persists, restart the application."
        case .permissionDenied:
            return "Contact your administrator for access."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .itemNotFound:
            return "The requested item does not exist in the database."
        case .invalidParent:
            return "Parent-child relationships must follow the hierarchy rules."
        case .circularReference:
            return "A tree structure cannot have circular references."
        case .databaseError:
            return "An unexpected database error occurred."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        }
    }
}
```

**Solution 2: Error Propagation with Context**

```swift
extension ItemRepository {
    /// Fetch item with detailed error context
    func fetchWithErrorContext(byId id: UUID) throws -> TierItem {
        do {
            guard let item = try fetch(byId: id) else {
                throw TreeError.itemNotFound(id: id)
            }
            return item
        } catch let error as TreeError {
            throw error  // Re-throw known errors
        } catch {
            throw TreeError.databaseError(underlying: error)
        }
    }
    
    /// Move item with validation and error context
    func moveWithErrorContext(_ item: TierItem, to newParent: TierItem?) throws {
        // Validate before attempting move
        if let newParent = newParent {
            guard newParent.canAddChild(ofType: item.type) else {
                throw TreeError.invalidParent(
                    parentId: newParent.id,
                    childType: item.type
                )
            }
            
            // Check for circular reference
            if wouldCreateCircularReference(item, newParent) {
                throw TreeError.circularReference(
                    itemId: item.id,
                    targetId: newParent.id
                )
            }
        } else {
            guard item.type == .capability else {
                throw TreeError.invalidParent(
                    parentId: UUID(),  // Root
                    childType: item.type
                )
            }
        }
        
        // Perform move
        do {
            try move(item, to: newParent)
        } catch {
            throw TreeError.databaseError(underlying: error)
        }
    }
    
    private func wouldCreateCircularReference(_ item: TierItem, _ newParent: TierItem) -> Bool {
        var current: TierItem? = newParent
        while let parent = current {
            if parent.id == item.id {
                return true
            }
            current = parent.parent
        }
        return false
    }
}
```

### User Notification Patterns

**Pattern 1: Alert-Based Notifications**

```swift
struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let recoverySuggestion: String?
    let severity: Severity
    
    enum Severity {
        case info, warning, error, critical
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.octagon"
            case .critical: return "bolt.horizontal.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .critical: return .purple
            }
        }
    }
}

// In your view
struct ContentView: View {
    @State private var errorAlert: ErrorAlert?
    
    var body: some View {
        // Your content
            .alert(item: $errorAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message + "\n\n" + (alert.recoverySuggestion ?? "")),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
    
    private func handleError(_ error: Error) {
        if let treeError = error as? TreeError {
            errorAlert = ErrorAlert(
                title: "Operation Failed",
                message: treeError.errorDescription ?? "Unknown error",
                recoverySuggestion: treeError.recoverySuggestion,
                severity: .error
            )
        } else {
            errorAlert = ErrorAlert(
                title: "Unexpected Error",
                message: error.localizedDescription,
                recoverySuggestion: "Please try again or contact support.",
                severity: .error
            )
        }
    }
}
```

**Pattern 2: Toast Notifications**

```swift
struct ToastView: View {
    let message: String
    let severity: ErrorAlert.Severity
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: severity.icon)
                .font(.title2)
                .foregroundColor(severity.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
                .shadow(radius: 8)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// Toast modifier
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastMessage?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastView(
                        message: toast.message,
                        severity: toast.severity,
                        isPresented: Binding(
                            get: { toast != nil },
                            set: { if !$0 { self.toast = nil } }
                        )
                    )
                    .padding()
                    .animation(.spring(), value: toast != nil)
                }
            }
    }
}

struct ToastMessage: Identifiable {
    let id = UUID()
    let message: String
    let severity: ErrorAlert.Severity
}
```

**Pattern 3: Inline Error Display**

```swift
struct InlineErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Error")
                    .font(.headline)
            }
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let recoverySuggestion = (error as? LocalizedError)?.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// Usage in forms
struct ItemDetailForm: View {
    @State private var error: Error?
    
    var body: some View {
        Form {
            // Form fields
            
            if let error = error {
                Section {
                    InlineErrorView(error: error)
                }
            }
        }
    }
}
```

### Logging and Debugging

```swift
import os

private let logger = Logger(subsystem: "com.tierspec.app", category: "Repository")

extension ItemRepository {
    func move(_ item: TierItem, to newParent: TierItem?) throws {
        logger.info("Moving item \(item.id) to parent \(newParent?.id ?? "root")")
        
        do {
            try moveWithErrorContext(item, to: newParent)
            logger.info("Successfully moved item \(item.id)")
        } catch {
            logger.error("Failed to move item \(item.id): \(error.localizedDescription)")
            throw error
        }
    }
}
```


## 6. Migration Recommendations

### Immediate Actions (Security Critical)

**1. Update Vitest (CRITICAL - RCE Vulnerability)**

```bash
cd mcp-server
npm install vitest@^3.0.5
npm audit
npm test  # Ensure tests still pass
```

**2. Update Vite (if used)**

```bash
npm install vite@latest
npm audit
```

**3. Check for esbuild vulnerabilities**

```bash
npm ls esbuild
# If pinned to old versions, update parent packages
```

### Short-Term Improvements (Performance)

**1. Add Missing Indexes to SQLite Schema**

Create a migration file: `mcp-server/src/db/migrations/003-performance-indexes.sql`

```sql
-- Performance indexes for common queries
CREATE INDEX IF NOT EXISTS idx_items_updated_at ON items(updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_items_type_status ON items(type, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sprint_assignments_active ON sprint_assignments(item_id, sprint_id) WHERE removed_at IS NULL;

-- Analyze tables for query planner
ANALYZE;
```

**2. Implement Query Caching in MCP Server**

Create `mcp-server/src/db/query-cache.ts`:

```typescript
export class QueryCache {
  private cache = new Map<string, { data: any; timestamp: number }>();
  private ttl: number;
  
  constructor(ttlMs: number = 5000) {
    this.ttl = ttlMs;
  }
  
  get<T>(key: string, queryFn: () => T): T {
    const cached = this.cache.get(key);
    const now = Date.now();
    
    if (cached && now - cached.timestamp < this.ttl) {
      return cached.data as T;
    }
    
    const data = queryFn();
    this.cache.set(key, { data, timestamp: now });
    return data;
  }
  
  invalidate(pattern?: RegExp): void {
    if (!pattern) {
      this.cache.clear();
      return;
    }
    
    for (const key of this.cache.keys()) {
      if (pattern.test(key)) {
        this.cache.delete(key);
      }
    }
  }
}
```

**3. Optimize SwiftData Queries in ItemRepository**

Add to `ItemRepository.swift`:

```swift
/// Fetch subtree with batch loading (avoid N+1)
func fetchSubtree(rootId: UUID) throws -> [TierItem] {
    var allItems: [TierItem] = []
    var queue: [UUID] = [rootId]
    var visited: Set<UUID> = []
    
    while !queue.isEmpty {
        let batchIds = queue
        queue = []
        
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { batchIds.contains($0.id) && $0.deletedAt == nil }
        )
        let items = try modelContext.fetch(descriptor)
        
        for item in items {
            if !visited.contains(item.id) {
                visited.insert(item.id)
                allItems.append(item)
                if let children = item.children {
                    queue.append(contentsOf: children.map { $0.id })
                }
            }
        }
    }
    
    return allItems
}

/// Batch insert items in a single transaction
func batchInsert(_ items: [TierItem]) throws {
    try modelContext.transaction {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
}
```

### Medium-Term Improvements (Architecture)

**1. Implement Incremental Updates in TreeStore**

Replace full reloads with targeted updates:

```swift
@MainActor
final class TreeStore: ObservableObject {
    @Published private(set) var rootItems: [TierItem] = []
    @Published private(set) var itemCache: [UUID: TierItem] = [:]
    
    /// Update only the changed item (not full reload)
    func updateItemLocally(_ item: TierItem) {
        itemCache[item.id] = item
        
        if item.isRoot {
            if let index = rootItems.firstIndex(where: { $0.id == item.id }) {
                rootItems[index] = item
            } else {
                rootItems.append(item)
            }
        }
    }
    
    /// Batch update multiple items
    func batchUpdate(_ updates: [TierItem]) async {
        for item in updates {
            itemCache[item.id] = item
        }
        objectWillChange.send()
    }
}
```

**2. Add Comprehensive Error Handling**

Create `TierSpec/Models/TreeError.swift`:

```swift
enum TreeError: LocalizedError {
    case itemNotFound(id: UUID)
    case invalidParent(parentId: UUID, childType: ItemType)
    case circularReference(itemId: UUID, targetId: UUID)
    case databaseError(underlying: Error)
    case permissionDenied(action: String)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let id):
            return "Item not found with ID: \(id)"
        case .invalidParent(let parentId, let childType):
            return "Cannot add \(childType.displayName) as child of item \(parentId)"
        case .circularReference(let itemId, let targetId):
            return "Cannot move item \(itemId) to \(targetId) - would create circular reference"
        case .databaseError(let underlying):
            return "Database error: \(underlying.localizedDescription)"
        case .permissionDenied(let action):
            return "Permission denied for action: \(action)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .itemNotFound:
            return "The item may have been deleted. Try refreshing the view."
        case .invalidParent:
            return "Check the hierarchy rules: Capabilities → Features → User Stories → Test Cases"
        case .circularReference:
            return "Choose a different parent that is not a descendant of this item."
        case .databaseError:
            return "Try again. If the problem persists, restart the application."
        case .permissionDenied:
            return "Contact your administrator for access."
        }
    }
}
```

**3. Implement User Notification System**

Create `TierSpec/Views/Components/ErrorHandling.swift`:

```swift
struct ErrorAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let recoverySuggestion: String?
    let severity: Severity
    
    enum Severity {
        case info, warning, error, critical
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.octagon"
            case .critical: return "bolt.horizontal.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .critical: return .purple
            }
        }
    }
}

// Toast notification view
struct ToastView: View {
    let message: String
    let severity: ErrorAlert.Severity
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: severity.icon)
                .font(.title2)
                .foregroundColor(severity.color)
            
            Text(message)
                .font(.body)
            
            Spacer()
            
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
                .shadow(radius: 8)
        )
    }
}
```

### Long-Term Improvements (Scalability)

**1. Implement Lazy Loading with Depth Limits**

For large trees, load only visible nodes:

```swift
struct LazyTreeView: View {
    @State private var expandedNodes: Set<UUID> = []
    @State private var loadedDepth: Int = 2
    
    var body: some View {
        // Load only first 2 levels initially
        // Load deeper levels on demand
    }
}
```

**2. Add Database Connection Pooling**

For MCP server with high concurrency:

```typescript
class ConnectionPool {
  private pool: Database[] = [];
  private maxConnections = 5;
  
  acquire(): Database {
    if (this.pool.length > 0) {
      return this.pool.pop()!;
    }
    return this.createConnection();
  }
  
  release(db: Database): void {
    if (this.pool.length < this.maxConnections) {
      this.pool.push(db);
    } else {
      db.close();
    }
  }
}
```

**3. Implement Optimistic UI Updates**

For better perceived performance:

```swift
func moveNode(_ item: TierItem, to newParent: TierItem?) async {
    // Optimistically update UI
    let oldParent = item.parent
    item.parent = newParent
    objectWillChange.send()
    
    // Perform actual operation
    do {
        try await repository.move(item, to: newParent)
    } catch {
        // Revert on failure
        item.parent = oldParent
        objectWillChange.send()
        handleError(error)
    }
}
```

## Summary

### Critical Security Issues
- **Vitest RCE vulnerability (CVE-2025-24964)**: Upgrade to >=3.0.5 immediately
- **Vite path traversal (CVE-2026-39365)**: Upgrade to latest version
- **esbuild vulnerabilities**: Update pinned dependencies

### Performance Bottlenecks
- **N+1 queries in SwiftData**: Implement batch fetching and caching
- **Full tree reloads**: Implement incremental updates
- **Missing SQLite indexes**: Add composite and timestamp indexes

### Error Handling Gaps
- **Silent failures**: Implement comprehensive error types with LocalizedError
- **Poor user feedback**: Add alert and toast notification systems
- **Missing error context**: Add error propagation with detailed context

### Recommended Priority
1. **Immediate**: Fix security vulnerabilities (Vitest upgrade)
2. **Short-term**: Add missing indexes and implement query caching
3. **Medium-term**: Refactor error handling and implement incremental updates
4. **Long-term**: Implement lazy loading and optimistic UI updates

