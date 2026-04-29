//
//  KanbanView.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/26.
//

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

struct KanbanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TierItem> { $0.deletedAt == nil }, sort: \TierItem.priority, order: .reverse) 
    private var allItems: [TierItem]
    @Query(sort: \Sprint.startDate) 
    private var sprints: [Sprint]
    
    @State private var selectedItem: TierItem?
    @State private var selectedSprint: Sprint?
    @State private var validationError: StateMachineError?
    @State private var showErrorAlert = false
    
    private var userStories: [TierItem] {
        if let sprint = selectedSprint {
            return allItems.filter { 
                $0.type == .user_story && $0.sprint?.id == sprint.id 
            }
        } else {
            return allItems.filter { 
                $0.type == .user_story && $0.sprint == nil 
            }
        }
    }
    
    private let columns: [ItemStatus] = [
        .todo,
        .in_progress,
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
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
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
                Text("Unassigned Stories").tag(nil as Sprint?)
                ForEach(sprints) { sprint in
                    Text("\(sprint.name) (\(sprint.status.displayName))")
                        .tag(sprint as Sprint?)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 200)
            
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
                ForEach(columns, id: \.self) { status in
                    KanbanColumn(
                        status: status,
                        items: userStories.filter { $0.status == status },
                        selectedItem: $selectedItem,
                        resolveItemByID: resolveDraggedItem,
                        onStatusChange: changeStatus
                    )
                }
            }
            .padding()
        }
    }
    
    private func changeStatus(_ item: TierItem, to newStatus: ItemStatus) {
        guard item.status != newStatus else { return }
        
        do {
            try StateMachine.assertValidTransition(from: item.status, to: newStatus, actorType: .human)
        } catch let error as StateMachineError {
            validationError = error
            showErrorAlert = true
            return
        } catch {
            validationError = nil
            showErrorAlert = true
            return
        }

        withAnimation {
            item.status = newStatus
            item.touch()
            
            if let sprint = item.sprint {
                recalculateSprintPoints(sprint)
            }

            do {
                try modelContext.save()
            } catch {
                assertionFailure("Failed to save drag-drop status change: \(error)")
            }
        }
    }

    private func resolveDraggedItem(id: String) -> TierItem? {
        userStories.first { $0.id.uuidString == id }
    }
    
    private func recalculateSprintPoints(_ sprint: Sprint) {
        let sprintItems = allItems.filter { $0.sprint?.id == sprint.id }
        sprint.committedPoints = sprintItems.compactMap { $0.storyPoints }.reduce(0, +)
        sprint.completedPoints = sprintItems.filter { $0.status == .done }.compactMap { $0.storyPoints }.reduce(0, +)
        sprint.touch()
    }
}

struct KanbanColumn: View {
    let status: ItemStatus
    let items: [TierItem]
    @Binding var selectedItem: TierItem?
    let resolveItemByID: (String) -> TierItem?
    let onStatusChange: (TierItem, ItemStatus) -> Void

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
                guard item.status != status else { continue }

                onStatusChange(item, status)
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
                .fill(status.color)
                .frame(width: 12, height: 12)
            
            Text(status.displayName)
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
    let item: TierItem
    
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

#Preview {
    KanbanView()
        .modelContainer(for: [TierItem.self, Sprint.self], inMemory: true)
}
