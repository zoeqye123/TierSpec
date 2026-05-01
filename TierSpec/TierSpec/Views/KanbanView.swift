//
//  KanbanView.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/26.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum KanbanColumn: String, CaseIterable {
    case todo = "To Do"
    case inProgress = "In Progress"
    case test = "Test"
    case done = "Done"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .todo: return .secondary
        case .inProgress: return .blue
        case .test: return .indigo
        case .done: return .green
        }
    }
    
    func contains(status: ItemStatusDTO) -> Bool {
        switch self {
        case .todo:
            return [.requirementInput, .requirementReview, .needsInfo, .backlog].contains(status)
        case .inProgress:
            return [.inProgress, .aiDecomposing].contains(status)
        case .test:
            return [.waitingForTest, .testing, .acceptance].contains(status)
        case .done:
            return [.completed, .published].contains(status)
        }
    }
    
    func toItemStatus() -> ItemStatusDTO {
        switch self {
        case .todo: return .backlog
        case .inProgress: return .inProgress
        case .test: return .testing
        case .done: return .completed
        }
    }
}

struct KanbanView: View {
    @ObservedObject var treeStore: TreeStore
    @StateObject private var sprintStore: SprintStore
    
    @State private var selectedItem: TierItemDTO?
    @State private var selectedSprint: SprintDTO?
    @State private var validationError: StateMachineDTOError?
    @State private var showErrorAlert = false
    @State private var showingCreateSprint = false
    
    init(treeStore: TreeStore) {
        self._treeStore = ObservedObject(wrappedValue: treeStore)
        _sprintStore = StateObject(wrappedValue: SprintStore(mcpClient: treeStore.repository.mcpClient))
    }
    
    private var allItems: [TierItemDTO] {
        treeStore.rootItems.flatMap { flattenItems($0) }
    }
    
    private var userStories: [TierItemDTO] {
        let stories = allItems.filter { $0.type == .userStory && $0.deletedAt == nil }
        
        if let sprint = selectedSprint {
            return stories.filter { $0.sprintId == sprint.id }
        } else {
            return stories.filter { $0.sprintId == nil }
        }
    }
    
    private let columns: [KanbanColumn] = [
        .todo,
        .inProgress,
        .test,
        .done,
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            sprintPicker
            Divider()
            kanbanBoard
        }
        .navigationTitle("Kanban Board")
        .task {
            await sprintStore.loadSprints()
            selectDefaultSprint()
        }
        .sheet(isPresented: $showingCreateSprint) {
            SprintFormView(sprintStore: sprintStore)
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item, treeStore: treeStore)
        }
        .alert("Invalid Status Transition", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationError?.errorDescription ?? "An unknown error occurred")
        }
    }
    
    @ViewBuilder
    private var sprintPicker: some View {
        HStack {
            Picker("Sprint", selection: $selectedSprint) {
                Text("Unassigned Stories").tag(nil as SprintDTO?)
                ForEach(sprintStore.sprints) { sprint in
                    Text("\(sprint.name) (\(sprint.status.displayName))")
                        .tag(sprint as SprintDTO?)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 200)
            
            Button {
                showingCreateSprint = true
            } label: {
                Label("New Sprint", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            if let sprint = selectedSprint {
                HStack(spacing: 8) {
                    Text("\(sprint.completedPoints)/\(sprint.committedPoints) pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ProgressView(value: sprint.progress)
                        .frame(width: 60)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05))
    }
    
    @ViewBuilder
    private var kanbanBoard: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns, id: \.self) { column in
                    KanbanColumnView(
                        column: column,
                        items: userStories.filter { column.contains(status: $0.status) },
                        selectedItem: $selectedItem,
                        resolveItemByID: resolveDraggedItem,
                        onStatusChange: changeStatus
                    )
                }
            }
            .padding()
        }
    }
    
    private func changeStatus(_ item: TierItemDTO, to column: KanbanColumn) {
        let newStatus = column.toItemStatus()
        
        guard item.status != newStatus else { return }
        
do {
            try StateMachineDTO.assertValidTransition(from: item.status, to: newDTOStatus, actorType: .human)
        } catch let error as StateMachineDTOError {
            validationError = error
            showErrorAlert = true
            return
        } catch {
            validationError = nil
            showErrorAlert = true
            return
        }

        Task {
            var updatedItem = item
            updatedItem.status = newStatus
            updatedItem.updatedAt = Date()
            await treeStore.updateItem(updatedItem)
        }
    }
    
    private func resolveDraggedItem(id: String) -> TierItemDTO? {
        userStories.first { $0.id.uuidString == id }
    }
    
    private func selectDefaultSprint() {
        guard selectedSprint == nil else { return }
        
        if let activeSprint = sprintStore.sprints.first(where: { $0.status == .active }) {
            selectedSprint = activeSprint
        } else if let firstSprint = sprintStore.sprints.first {
            selectedSprint = firstSprint
        }
    }
    
    private func flattenItems(_ item: TierItemDTO) -> [TierItemDTO] {
        var result = [item]
        for child in item.children {
            result.append(contentsOf: flattenItems(child))
        }
        return result
    }
}

struct KanbanColumnView: View {
    let column: KanbanColumn
    let items: [TierItemDTO]
    @Binding var selectedItem: TierItemDTO?
    let resolveItemByID: (String) -> TierItemDTO?
    let onStatusChange: (TierItemDTO, KanbanColumn) -> Void
    
    @State private var isDropTargeted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        KanbanCard(item: item)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                selectedItem = item
                            }
                            .draggable(item.id.uuidString)
                    }
                    
                    if items.isEmpty {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 280)
        .background(
            (isDropTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.05)),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDropTargeted ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .dropDestination(for: String.self) { droppedIDs, _ in
            var handledDrop = false
            
            for droppedID in droppedIDs {
                guard let item = resolveItemByID(droppedID) else { continue }
                guard !column.contains(status: item.status) else { continue }
                
                onStatusChange(item, column)
                handledDrop = true
            }
            
            return handledDrop
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.12)) {
                isDropTargeted = targeted
            }
        }
    }
    
    @ViewBuilder
    private var header: some View {
        HStack {
            Circle()
                .fill(column.color)
                .frame(width: 12, height: 12)
            
            Text(column.displayName)
                .font(.headline)
            
            Spacer()
            
            Text("\(items.count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1), in: Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

struct KanbanCard: View {
    let item: TierItemDTO
    
    private var cardBackgroundColor: Color {
        #if canImport(AppKit)
        return Color(nsColor: NSColor.controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
    
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
                    .font(.caption)
                    .foregroundStyle(item.status.color)
                
                Text(item.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if item.aiGenerated {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            }
            
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            HStack {
                if let points = item.storyPoints {
                    Text("\(points) pts")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                }
                
                if let complexity = item.complexity {
                    Text(complexity.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(complexity.color.opacity(0.1), in: Capsule())
                }
                
                Spacer()
                
                Text("\(item.priority)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}