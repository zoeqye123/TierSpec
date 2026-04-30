# Draft: TierSpec 重构需求

## 用户核心诉求

### 定位
- 一个项目 = 一个 Spec
- 以 Business User Story 为核心
- 层级：Capability → Feature → User Story → Test Case
- 看板只展示 User Story
- 界面像 Paper 一样干净、窗口独立、不串数据

---

## 必须修复的问题

### 1. 项目 & 窗口数据隔离（最高优先级）
- New Window = 全新空项目
- 每个窗口独立对应一个 Spec 项目
- 切换项目 = 切换整套数据，不会互相污染
- 顶部菜单：New Project / New Window

### 2. 层级结构完全重做（最高优先级）
- 当前问题：加不了、删不了、编不了、层级关系不生效
- 固定结构：Capability → Feature → User Story → Test Case
- 每个节点支持：新增子节点、编辑、删除、拖拽、展开/折叠
- 点击节点 → 右侧显示详情

### 3. Hierarchy 面板高度
- 左侧层级面板高度拉满
- 支持滚动

### 4. Sprint ↔ 看板联动
- Sprint 对应一批 User Story
- Story 加入 Sprint → 自动出现在看板
- 看板列：待办 / 进行中 / 测试中 / 已完成
- 拖拽卡片 → 状态同步

### 5. 新建 Feature 自动关联上级
- 新建 Feature → 自动归属当前选中的 Capability
- 显示路径：Capability X > Feature Y

---

## 功能优先级

1. **最高**：项目隔离 + 层级增删改查
2. **其次**：Sprint ↔ 看板联动
3. **再次**：Business Test Case 绑定在 Story 下
4. **延后**：Technical User Story / Technical Details

---

## UI 布局规范

```
┌─────────────────┬─────────────────────┬──────────────────┐
│   层级树         │    Sprint 看板       │    详情面板      │
│   (全高)        │    (User Story卡片)  │                  │
│                 │                     │                  │
│  Capability     │  待办 | 进行中 | ...  │  选中节点信息    │
│    Feature      │                     │  编辑            │
│      Story      │                     │  Test Case 列表  │
│        TC       │                     │                  │
└─────────────────┴─────────────────────┴──────────────────┘
```

---

## 代码库现状分析

### 架构概览
```
TierSpec/
├── TierSpec/TierSpec/          # Swift Mac Client
│   ├── Models/
│   │   ├── TierItem.swift      # SwiftData @Model - 层级关系已定义
│   │   ├── ItemType.swift      # 层级规则已正确 (Cap→Feat→Epic→Story→TC)
│   │   ├── Sprint.swift        # Sprint 模型存在
│   │   └── ItemStatus.swift    # 状态枚举
│   ├── Views/
│   │   ├── HierarchyTreeView.swift  # 层级树视图
│   │   ├── TreeNodeView.swift       # 节点组件
│   │   ├── KanbanView.swift         # 看板视图
│   │   └── ItemDetailView.swift     # 详情面板
│   ├── Stores/TreeStore.swift       # 状态管理
│   └── Repositories/ItemRepository.swift
└── mcp-server/                 # TypeScript MCP Server (暂不涉及)
```

### 已实现的功能 ✅
1. **数据模型完整**: TierItem 有 parent/children 关系、ItemType.allowedChildTypes 层级规则正确
2. **Repository 完整**: CRUD、move、reorder、search 都已实现
3. **TreeStore**: 状态管理、展开/折叠、选择逻辑
4. **TreeNodeView**: DisclosureGroup、contextMenu (Add Child / Delete)
5. **KanbanView**: 基本看板布局，按状态分列

### 问题诊断 ❌

#### 问题1: 项目数据隔离
- **现状**: 单一全局数据库 `/Users/z/.tierspec/tierspec.db`
- **问题**: 所有窗口共享同一个 ModelContainer，无法隔离
- **根因**: TierSpecApp.swift 第18行硬编码了单一数据库路径

#### 问题2: 层级结构"不能用"
- **代码分析**: HierarchyTreeView 和 TreeNodeView 的实现看起来是正确的
- **可能原因**:
  1. UI 交互问题：contextMenu 可能不够明显
  2. 数据库状态问题：可能有脏数据
  3. SwiftData 关系同步问题：parent/children 双向绑定可能有延迟
- **需要验证**: 实际运行看具体什么不工作

#### 问题3: Hierarchy 面板太小
- **现状**: ContentView 用 NavigationSplitView，HierarchyTreeView 在 List 的 Section 里
- **问题**: Section 占用空间有限，没有占满左侧高度

#### 问题4: Sprint ↔ 看板脱节
- **现状**: KanbanView 显示所有 TierItem，不区分 Sprint
- **问题**: 
  1. 看板没有 Sprint 选择器
  2. 没有按 Sprint 过滤 Story
  3. Sprint.items 关系存在但未在 UI 使用

#### 问题5: 新建 Feature 无默认上级
- **现状**: addChild 函数需要用户在 contextMenu 选择
- **问题**: 没有自动关联当前选中的 Capability

---

## 用户确认的决策

- **重建策略**: UI 层重做（保留模型，重建 UI）
- **数据隔离**: 每项目独立文件（像 Paper 一样）
- **测试策略**: TDD
- **层级结构**: 去掉 Epic，简化为 4 层
  - Capability → Feature → (Business/Technical) Story → Test Case
- **层级问题**: 所有操作都不工作（加/删/编/拖拽/展开折叠）
- **看板列数**: 4 列（待办/进行中/测试中/已完成）
- **看板内容**: Business + Technical Story 都显示

---

## 技术方案设计

### 1. 项目数据隔离方案

**目标**: 每个项目一个 .tierspec 文件，像 Paper 一样

**实现方案**:
```
文件结构:
~/Documents/
  ├── MyProject.tierspec/      # 项目目录（类似 .paper）
  │   ├── project.json         # 项目元数据
  │   └── data.db              # SwiftData 数据库
  └── AnotherProject.tierspec/
      ├── project.json
      └── data.db
```

**Swift 实现**:
1. `TierSpecApp` 改为支持多窗口，每个窗口独立 `ModelContainer`
2. `FileDocument` + `DocumentGroup` 或自定义 `WindowGroup`
3. 新建窗口 → 创建临时内存数据库 → 保存时选路径
4. 打开项目 → 加载对应的 .db 文件

**关键改动**:
- `TierSpecApp.swift`: 从单一 `ModelContainer` 改为动态创建
- 新增 `ProjectDocument.swift`: 管理项目文件
- 新增 `ProjectManager.swift`: 窗口和项目生命周期

### 2. 层级结构简化（去掉 Epic）

**模型改动**:
```swift
// ItemType.swift - allowedChildTypes 改为:
case .feature:
    return [.business_story, .technical_story]  // 直接到 Story
case .business_story, .technical_story:
    return [.test_case]
```

**数据迁移**:
- 现有 Epic 需要处理
- 方案：迁移脚本将 Epic 下的 Story 移到 Feature 下

### 3. 层级 UI 重做

**问题诊断**:
- 当前 `TreeNodeView` 使用 `DisclosureGroup`，可能 SwiftData 关系未正确触发更新
- `@Query` 获取的数据可能没有正确反映 parent-child 关系

**重做方案**:
1. 使用 `OutlineGroup` 替代手动递归
2. 或者使用 `LazyVStack` + 手动管理展开状态
3. 确保增删改操作后 `modelContext.save()` 被调用
4. 添加编辑功能（当前只有添加和删除）

**新增功能**:
- 行内编辑（双击标题直接编辑）
- 拖拽排序（使用 `.onMove`）
- 工具栏按钮（不用 contextMenu）

### 4. Hierarchy 面板全高

**方案**: 
- 移除 `Section` 包装，让 `HierarchyTreeView` 直接占据整个左侧
- 或使用自定义布局

### 5. Sprint ↔ 看板联动

**方案**:
1. Sprint 选择器（顶部或侧边）
2. KanbanView 过滤：只显示选中 Sprint 的 Story
3. 拖拽卡片 → 更新 Story.status → 同步 Sprint 进度

**状态映射**:
```swift
// 看板 4 列映射到 ItemStatus
enum KanbanColumn {
    case todo         → .backlog
    case inProgress   → .in_progress
    case testing      → .testing
    case done         → .completed
}
```

### 6. 新建自动关联上级

**方案**:
- 工具栏按钮根据当前选中节点类型自动决定
- 选中 Capability → "+ Feature" 按钮
- 选中 Feature → "+ Story" 按钮
- 选中 Story → "+ Test Case" 按钮
