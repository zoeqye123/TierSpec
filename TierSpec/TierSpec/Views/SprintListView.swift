//
//  SprintListView.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/26.
//

import SwiftUI
import SwiftData

struct SprintListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Sprint.startDate) private var sprints: [Sprint]
    @State private var showingCreateSprint = false
    @State private var selectedSprint: Sprint?
    
    var body: some View {
        NavigationStack {
            List {
                if sprints.isEmpty {
                    emptyStateView
                } else {
                    ForEach(sprints) { sprint in
                        SprintRowView(sprint: sprint)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSprint = sprint
                            }
                    }
                    .onDelete(perform: deleteSprints)
                }
            }
            .navigationTitle("Sprints")
            .toolbar {
                ToolbarItem {
                    Button {
                        showingCreateSprint = true
                    } label: {
                        Label("Add Sprint", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSprint) {
                CreateSprintView()
            }
            .sheet(item: $selectedSprint) { sprint in
                SprintDetailView(sprint: sprint)
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Sprints")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Create a sprint to start planning your iterations")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func deleteSprints(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sprints[index])
        }
    }
}

struct SprintRowView: View {
    let sprint: Sprint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(sprint.name)
                    .font(.headline)
                
                Spacer()
                
                Text(sprint.status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sprint.status.color, in: Capsule())
            }
            
            HStack(spacing: 16) {
                Label {
                    Text("\(sprint.startDate.formatted(.dateTime.day().month())) - \(sprint.endDate.formatted(.dateTime.day().month()))")
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                
                if sprint.isActive, let days = sprint.daysRemaining {
                    Label {
                        Text("\(days) days left")
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                }
            }
            
            ProgressView(value: sprint.progress)
                .tint(sprint.status.color)
            
            HStack {
                Text("\(sprint.completedPoints)/\(sprint.committedPoints) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(Int(sprint.capacityUsedPercent))% capacity")
                    .font(.caption)
                    .foregroundStyle(sprint.capacityUsedPercent > 100 ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateSprintView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(14 * 24 * 60 * 60)
    @State private var capacityPoints = 40
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sprint Details") {
                    TextField("Sprint Name", text: $name)
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
                
                Section("Capacity") {
                    Stepper("Capacity: \(capacityPoints) points", value: $capacityPoints, in: 0...200, step: 5)
                }
            }
            .navigationTitle("New Sprint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSprint()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createSprint() {
        let sprint = Sprint(
            name: name,
            startDate: startDate,
            endDate: endDate,
            capacityPoints: capacityPoints
        )
        modelContext.insert(sprint)
        dismiss()
    }
}

struct SprintDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var sprint: Sprint
    
    @Query(sort: \TierItem.position) private var allItems: [TierItem]
    
    var sprintItems: [TierItem] {
        allItems.filter { $0.sprint?.id == sprint.id && $0.deletedAt == nil }
    }
    
    var availableItems: [TierItem] {
        allItems.filter { $0.sprint == nil && $0.deletedAt == nil && $0.type.isStoryType }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Sprint Info") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Picker("", selection: $sprint.status) {
                            ForEach(SprintStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Text("Capacity")
                        Spacer()
                        Text("\(sprint.capacityPoints) pts")
                    }
                    
                    HStack {
                        Text("Committed")
                        Spacer()
                        Text("\(sprint.committedPoints) pts")
                    }
                    
                    HStack {
                        Text("Completed")
                        Spacer()
                        Text("\(sprint.completedPoints) pts")
                    }
                }
                
                Section("Assigned Items (\(sprintItems.count))") {
                    if sprintItems.isEmpty {
                        Text("No items assigned")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sprintItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.subheadline)
                                    Text(item.type.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let points = item.storyPoints {
                                    Text("\(points) pts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button {
                                    item.sprint = nil
                                    recalculatePoints()
                                } label: {
                                    Label("Remove", systemImage: "xmark")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
                
                if sprint.status == .planning {
                    Section("Available Stories") {
                        if availableItems.isEmpty {
                            Text("No unassigned stories")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(availableItems) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.subheadline)
                                        Text(item.type.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let points = item.storyPoints {
                                        Text("\(points) pts")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions {
                                    Button {
                                        item.sprint = sprint
                                        recalculatePoints()
                                    } label: {
                                        Label("Assign", systemImage: "plus")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(sprint.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func recalculatePoints() {
        let items = sprintItems
        sprint.committedPoints = items.compactMap { $0.storyPoints }.reduce(0, +)
        sprint.completedPoints = items.filter { $0.status == .completed }.compactMap { $0.storyPoints }.reduce(0, +)
        sprint.touch()
    }
}

#Preview {
    SprintListView()
        .modelContainer(for: Sprint.self, inMemory: true)
}
