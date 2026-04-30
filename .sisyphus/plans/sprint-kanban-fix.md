# Work Plan: TierSpec Sprint 看板修复 + 项目管理增强

## 概述

本计划修复 Sprint 看板 UI 问题，实现 User Story ID 生成，增强项目管理功能，并添加 AI Sprint 分配建议功能。

**预计工作量**: 10-15 小时
**技术栈**: Swift 5.9, SwiftUI, SwiftData, Swift Testing
**方法**: TDD（测试驱动开发）

**主要功能**:
1. Sprint 看板 UI 修复（4列看板、工具栏修复）
2. User Story ID 生成（US-001 格式）
3. 项目管理增强（命名对话框、自动创建 Sprint 1）
4. AI Sprint 分配建议（智能分配未分配的 Stories）

---

## 任务分解

### Phase 1: 数据模型增强 (TDD)

#### Task 1.1: Project 模型添加 User Story 计数器 ✅
**文件**: `TierSpec/TierSpec/Models/Project.swift`
**状态**: 已完成

**变更**:
```swift
@Model
final class Project {
    // ... existing fields ...
    var lastUserStoryNumber: Int = 0  // 新增
}
```

**测试**:
```swift
// Tests/ProjectTests.swift
@Test func projectHasUserStoryCounter() async throws {
    let project = Project(name: "Test", databasePath: "/tmp/test.db")
    #expect(project.lastUserStoryNumber == 0)
}
```

**验证**: `xcodebuild test -scheme TierSpec -destination 'platform=macOS'`

---

#### Task 1.2: TierItem 模型添加 displayId 字段 ✅
**文件**: `TierSpec/TierSpec/Models/TierItem.swift`
**状态**: 已完成

**变更**:
```swift
@Model
final class TierItem {
    // ... existing fields ...
    var displayId: String?  // 新增: US-001, US-002...
}
```

**测试**:
```swift
// Tests/TierItemTests.swift
@Test func tierItemHasDisplayId() async throws {
    let item = TierItem(type: .user_story, title: "Test Story")
    #expect(item.displayId == nil)  // 默认为 nil，创建时生成
}
```

---

#### Task 1.3: 实现 User Story ID 生成逻辑 ✅
**文件**: `TierSpec/TierSpec/Services/UserStoryIDGenerator.swift` (新建)
**状态**: 已完成

**职责**:
- 接收 Project 和 TierItem
- 生成格式: `US-001`, `US-002`, ...
- 原子递增 Project.lastUserStoryNumber
- 仅对 type == .user_story 的项生成

**测试**:
```swift
// Tests/UserStoryIDGeneratorTests.swift
@Test func generatesSequentialIDs() async throws {
    let project = Project(name: "Test", databasePath: "/tmp/test.db")
    let gen = UserStoryIDGenerator()
    
    let id1 = gen.generate(for: project)
    let id2 = gen.generate(for: project)
    
    #expect(id1 == "US-001")
    #expect(id2 == "US-002")
    #expect(project.lastUserStoryNumber == 2)
}

@Test func skipsNonUserStoryTypes() async throws {
    let project = Project(name: "Test", databasePath: "/tmp/test.db")
    let gen = UserStoryIDGenerator()
    
    let item = TierItem(type: .capability, title: "Cap")
    let id = gen.generateIfNeeded(for: item, in: project)
    
    #expect(id == nil)
    #expect(project.lastUserStoryNumber == 0)
}

@Test func handlesLargeNumbers() async throws {
    let project = Project(name: "Test", databasePath: "/tmp/test.db")
    project.lastUserStoryNumber = 999
    let gen = UserStoryIDGenerator()
    
    let id = gen.generate(for: project)
    
    #expect(id == "US-1000")  // 不再补零
}
```

---

### Phase 2: Sprint 看板 UI 修复

#### Task 2.1: 修复 ContentView 工具栏按钮 ✅
**文件**: `TierSpec/TierSpec/ContentView.swift`
**状态**: 已完成

**问题**: 当前工具栏只有一个 "Add Capability" 按钮，在 Sprints tab 也显示

**变更**:
```swift
.toolbar {
    ToolbarItem {
        switch sidebarTab {
        case .hierarchy:
            Button(action: addCapability) {
                Label("Add Capability", systemImage: "plus")
            }
        case .sprints:
            Button(action: addSprint) {
                Label("New Sprint", systemImage: "plus")
            }
        }
    }
}

private func addSprint() {
    showingCreateSprint = true
}
```

**测试**: 手动验证 - 切换 tab 时按钮文字变化

---

#### Task 2.2: 替换 SprintListView 为 KanbanView ✅
**文件**: `TierSpec/TierSpec/ContentView.swift`
**状态**: 已完成

**变更**:
```swift
case .sprints:
    KanbanView()  // 替换 SprintListView()
```

**注意**: KanbanView 已正确实现，无需修改其内部逻辑

---

#### Task 2.3: KanbanView 添加 New Sprint 按钮 ✅
**文件**: `TierSpec/TierSpec/Views/KanbanView.swift`
**状态**: 已完成

**变更**: 在 sprintPicker 区域添加 "New Sprint" 按钮

```swift
@ViewBuilder
private var sprintPicker: some View {
    HStack {
        Picker("Sprint", selection: $selectedSprint) { ... }
        
        Spacer()
        
        Button {
            showingCreateSprint = true
        } label: {
            Image(systemName: "plus.circle")
        }
        .help("Create new Sprint")
        
        // ... existing progress view ...
    }
    .sheet(isPresented: $showingCreateSprint) {
        SprintFormView()  // 复用现有表单
    }
}
```

---

#### Task 2.4: KanbanView 默认选择最近的活跃 Sprint ✅
**文件**: `TierSpec/TierSpec/Views/KanbanView.swift`
**状态**: 已完成

**变更**:
```swift
var body: some View {
    VStack(spacing: 0) { ... }
    .onAppear {
        if selectedSprint == nil {
            selectDefaultSprint()
        }
    }
}

private func selectDefaultSprint() {
    // 优先选择活跃 Sprint
    if let activeSprint = sprints.first(where: { $0.status == .active }) {
        selectedSprint = activeSprint
    } else if let firstSprint = sprints.first {
        selectedSprint = firstSprint
    }
    // 如果没有 Sprint，显示未分配的 Stories（当前行为已正确）
}
```

---

#### Task 2.5: KanbanCard 显示 displayId ✅
**文件**: `TierSpec/TierSpec/Views/KanbanView.swift`
**状态**: 已完成

**变更**:
```swift
struct KanbanCard: View {
    let item: TierItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let displayId = item.displayId {
                    Text(displayId)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                
                Image(systemName: item.type.icon)
                // ... rest of header ...
            }
            // ... rest of card ...
        }
    }
}
```

---

### Phase 3: 项目管理增强

#### Task 3.1: 新建项目时弹出名称输入对话框 ✅
**文件**: `TierSpec/TierSpec/TierSpecApp.swift`
**状态**: 已完成

---

#### Task 3.2: 窗口标题显示项目名称 ✅
**文件**: `TierSpec/TierSpec/TierSpecApp.swift`
**状态**: 已完成

---

#### Task 3.3: 确保多窗口数据隔离 ✅
**文件**: `TierSpec/TierSpec/TierSpecApp.swift`
**状态**: 已完成

---

### Phase 4: AI Sprint 分配功能

#### Task 4.1: 实现 AI Sprint 分配建议服务
**文件**: `TierSpec/TierSpec/Services/AISprintAssigner.swift` (新建)

**职责**:
- 分析未分配的 User Stories
- 根据优先级、故事点、Sprint 容量等因素建议分配
- 返回建议列表供用户确认

**接口设计**:
```swift
struct SprintAssignmentSuggestion {
    let story: TierItem
    let suggestedSprint: Sprint
    let reason: String  // AI 推理说明
}

@Observable
class AISprintAssigner {
    /// 分析未分配的 Stories 并生成分配建议
    func suggestAssignments(
        unassignedStories: [TierItem],
        sprints: [Sprint]
    ) async -> [SprintAssignmentSuggestion]
    
    /// 应用建议（需要用户确认）
    func applySuggestion(_ suggestion: SprintAssignmentSuggestion)
}
```

**分配策略**:
1. 优先级高的 Story 优先分配
2. 考虑 Sprint 剩余容量
3. 避免单个 Sprint 过载
4. 生成可读的推理说明

**测试**:
```swift
// Tests/AISprintAssignerTests.swift
@Test func suggestsAssignmentBasedOnPriority() async throws {
    let assigner = AISprintAssigner()
    let sprint = Sprint(name: "Sprint 1", startDate: Date(), endDate: Date().addingTimeInterval(14*24*60*60))
    sprint.capacityPoints = 20
    
    let highPriorityStory = TierItem(type: .user_story, title: "Important", priority: 100, storyPoints: 5)
    let lowPriorityStory = TierItem(type: .user_story, title: "Less Important", priority: 10, storyPoints: 5)
    
    let suggestions = await assigner.suggestAssignments(
        unassignedStories: [highPriorityStory, lowPriorityStory],
        sprints: [sprint]
    )
    
    #expect(suggestions.first?.story.id == highPriorityStory.id)
}

@Test func respectsSprintCapacity() async throws {
    let assigner = AISprintAssigner()
    let sprint = Sprint(name: "Sprint 1", startDate: Date(), endDate: Date().addingTimeInterval(14*24*60*60))
    sprint.capacityPoints = 10
    sprint.committedPoints = 8  // 只剩 2 点
    
    let bigStory = TierItem(type: .user_story, title: "Big Story", storyPoints: 5)
    
    let suggestions = await assigner.suggestAssignments(
        unassignedStories: [bigStory],
        sprints: [sprint]
    )
    
    // 容量不足，不应建议分配
    #expect(suggestions.isEmpty)
}
```

---

#### Task 4.2: KanbanView 添加 AI 分配按钮
**文件**: `TierSpec/TierSpec/Views/KanbanView.swift`

**变更**: 在 sprintPicker 区域添加 "AI Assign" 按钮

```swift
@State private var showingAISuggestions = false
@State private var aiSuggestions: [SprintAssignmentSuggestion] = []

@ViewBuilder
private var sprintPicker: some View {
    HStack {
        Picker("Sprint", selection: $selectedSprint) { ... }
        
        Spacer()
        
        // AI 分配按钮
        Button {
            Task {
                await generateAISuggestions()
            }
        } label: {
            Label("AI Assign", systemImage: "sparkles")
        }
        .help("Let AI suggest sprint assignments")
        .disabled(unassignedStories.isEmpty)
        
        // New Sprint 按钮
        Button { ... } label: {
            Image(systemName: "plus.circle")
        }
        
        // ... progress view ...
    }
    .sheet(isPresented: $showingAISuggestions) {
        AISuggestionsView(suggestions: aiSuggestions, onApply: applySuggestion)
    }
}

private var unassignedStories: [TierItem] {
    allItems.filter { $0.type == .user_story && $0.sprint == nil }
}

private func generateAISuggestions() async {
    let assigner = AISprintAssigner()
    aiSuggestions = await assigner.suggestAssignments(
        unassignedStories: unassignedStories,
        sprints: sprints
    )
    showingAISuggestions = !aiSuggestions.isEmpty
}
```

---

#### Task 4.3: 创建 AI 建议确认视图
**文件**: `TierSpec/TierSpec/Views/AISuggestionsView.swift` (新建)

**UI 设计**:
```swift
struct AISuggestionsView: View {
    let suggestions: [SprintAssignmentSuggestion]
    let onApply: (SprintAssignmentSuggestion) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(suggestions) { suggestion in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(suggestion.story.displayId ?? "US-???")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        
                        Text(suggestion.story.title)
                            .font(.headline)
                        
                        Spacer()
                        
                        if let points = suggestion.story.storyPoints {
                            Text("\(points) pts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        
                        Text(suggestion.suggestedSprint.name)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button("Apply") {
                        onApply(suggestion)
                    }
                    .tint(.blue)
                }
            }
            .navigationTitle("AI Suggestions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply All") {
                        for suggestion in suggestions {
                            onApply(suggestion)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
```

---

#### Task 4.4: 应用 AI 建议并更新数据
**文件**: `TierSpec/TierSpec/Views/KanbanView.swift`

```swift
private func applySuggestion(_ suggestion: SprintAssignmentSuggestion) {
    suggestion.story.sprint = suggestion.suggestedSprint
    suggestion.story.touch()
    recalculateSprintPoints(suggestion.suggestedSprint)
    
    do {
        try modelContext.save()
    } catch {
        // Handle error
    }
    
    // 从建议列表中移除已应用的
    aiSuggestions.removeAll { $0.story.id == suggestion.story.id }
}
```

---

### Phase 5: 集成与验证

#### Task 5.1: 集成 ID 生成到创建流程
**文件**: `TierSpec/TierSpec/ContentView.swift` 或 `TreeStore.swift`

**变更**: 在创建 User Story 时调用 ID 生成器

```swift
private func addChild(to parent: TierItem, type: ItemType) {
    let child = TierItem(type: type, title: "New \(type.displayName)")
    
    // 如果是 User Story，生成 displayId
    if type == .user_story, let project = currentProject {
        child.displayId = UserStoryIDGenerator().generate(for: project)
    }
    
    Task {
        await treeStore.createItem(child, parent: parent)
        // ...
    }
}
```

---

#### Task 5.2: 端到端测试
**文件**: `Tests/EndToEndTests.swift`

```swift
@Test func newUserStoryGetsDisplayId() async throws {
    // 1. 创建项目
    // 2. 创建 User Story
    // 3. 验证 displayId == "US-001"
}

@Test func sprintKanbanShowsUserStories() async throws {
    // 1. 创建项目（自动创建 Sprint 1）
    // 2. 创建 User Story
    // 3. 将 Story 分配到 Sprint
    // 4. 打开 KanbanView
    // 5. 验证 Story 显示在 To Do 列
}

@Test func toolbarChangesOnTabSwitch() async throws {
    // 1. 选择 Hierarchy tab
    // 2. 验证工具栏显示 "Add Capability"
    // 3. 选择 Sprints tab
    // 4. 验证工具栏显示 "New Sprint"
}
```

---

#### Task 5.3: 手动验收清单

- [ ] 新建项目时弹出名称输入对话框
- [ ] 项目名称不能为空
- [ ] 新项目自动创建 Sprint 1（2周时间范围）
- [ ] 切换到 Sprints tab 显示看板（4列）
- [ ] 看板顶部有 Sprint 选择器
- [ ] 没有重复的加号按钮
- [ ] 新建 User Story 自动生成 US-XXX ID
- [ ] ID 显示在卡片左上角
- [ ] 拖拽卡片在列间移动正常
- [ ] 只有用户能拖到 Done（AI 不能）
- [ ] 多窗口打开不同项目，数据隔离
- [ ] AI Assign 按钮显示在看板顶部
- [ ] 点击 AI Assign 显示建议列表
- [ ] 可以单独应用或批量应用建议
- [ ] 建议显示推理说明

---

## 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| 数据迁移 | SwiftData 轻量迁移会自动添加新字段，默认值为 nil/0 |
| 多窗口状态同步 | 每个窗口有独立的 ProjectContext 和 ModelContainer |
| ID 生成竞态 | 使用 SwiftData 事务或 actor 隔离 |

---

## 不在范围内

- Sprint 状态转换 UI（保持现有行为）
- User Story 从 KanbanView 创建（从 Hierarchy 创建）

---

## 执行顺序

1. **Phase 1** (模型) → 2-3 小时
2. **Phase 2** (UI) → 3-4 小时
3. **Phase 3** (项目管理) → 2-3 小时
4. **Phase 4** (AI Sprint 分配) → 2-3 小时
5. **Phase 5** (集成测试) → 1-2 小时

**总计**: 10-15 小时

---

## 依赖关系

```
Task 1.1 ─┬─→ Task 1.3 ─→ Task 5.1
Task 1.2 ─┘
          
Task 2.1 ─→ Task 2.2 ─→ Task 2.5
Task 2.3
Task 2.4

Task 3.1 ─→ Task 3.2
Task 3.3 (独立)

Task 4.1 ─→ Task 4.2 ─→ Task 4.3 ─→ Task 4.4
```

---

## 验证命令

```bash
# 构建
xcodebuild -project TierSpec/TierSpec.xcodeproj -scheme TierSpec -destination 'platform=macOS' build

# 测试
xcodebuild -project TierSpec/TierSpec.xcodeproj -scheme TierSpec -destination 'platform=macOS' test

# 类型检查
xcodebuild -project TierSpec/TierSpec.xcodeproj -scheme TierSpec -destination 'platform=macOS' -showBuildSettings | grep SWIFT_VERSION
```
