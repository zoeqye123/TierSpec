//
//  SprintListView.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/26.
//

import SwiftUI

struct SprintListView: View {
    let sprintStore: SprintStore?
    let treeStore: TreeStore?
    
    @State private var sprints: [SprintDTO] = []
    @State private var showingCreateSprint = false
    @State private var editingSprint: SprintDTO?
    @State private var selectedSprint: SprintDTO?
    @State private var sprintPendingDelete: SprintDTO?
    @State private var showingDeleteConfirmation = false
    
    init(sprintStore: SprintStore) {
        self.sprintStore = sprintStore
        self.treeStore = nil
    }
    
    init(treeStore: TreeStore) {
        self.sprintStore = nil
        self.treeStore = treeStore
    }
    
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
                            .contextMenu {
                                Button {
                                    editingSprint = sprint
                                } label: {
                                    Label("Edit Sprint", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    sprintPendingDelete = sprint
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete Sprint", systemImage: "trash")
                                }
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
                if let sprintStore {
                    SprintFormView(sprintStore: sprintStore)
                } else if let treeStore {
                    SprintFormView(treeStore: treeStore)
                }
            }
            .sheet(item: $editingSprint) { sprint in
                if let sprintStore {
                    SprintFormView(sprintStore: sprintStore, sprint: sprint)
                } else if let treeStore {
                    SprintFormView(treeStore: treeStore, sprint: sprint)
                }
            }
            .sheet(item: $selectedSprint) { sprint in
                SprintDetailView(sprint: sprint)
            }
            .alert(
                "Delete Sprint?",
                isPresented: $showingDeleteConfirmation,
                presenting: sprintPendingDelete
            ) { sprint in
                Button("Delete", role: .destructive) {
                    deleteSprint(sprint)
                }
                Button("Cancel", role: .cancel) {
                    sprintPendingDelete = nil
                }
            } message: { sprint in
                Text("\(sprint.name) and its sprint assignment links will be removed.")
            }
            .onAppear {
                Task {
                    await loadSprints()
                }
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
    
    private func loadSprints() async {
        // TODO: Implement sprint loading via MCP
        sprints = []
    }
    
    private func deleteSprints(at offsets: IndexSet) {
        for index in offsets {
            deleteSprint(sprints[index])
        }
    }

    private func deleteSprint(_ sprint: SprintDTO) {
        if selectedSprint?.id == sprint.id {
            selectedSprint = nil
        }
        if editingSprint?.id == sprint.id {
            editingSprint = nil
        }
        sprintPendingDelete = nil
        sprints.removeAll { $0.id == sprint.id }
        // TODO: Implement sprint deletion via MCP
    }
}

struct SprintRowView: View {
    let sprint: SprintDTO

    private var storyItems: [TierItemDTO] {
        sprint.items.filter { $0.deletedAt == nil && $0.type == .userStory }
    }

    private var totalStoryCount: Int {
        storyItems.count
    }

    private var completedStoryCount: Int {
        storyItems.filter { $0.status == .done }.count
    }

    private var storyProgress: Double {
        guard totalStoryCount > 0 else { return 0 }
        return Double(completedStoryCount) / Double(totalStoryCount)
    }
    
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
            
            ProgressView(value: storyProgress)
                .tint(sprint.status.color)

            HStack {
                Text("\(completedStoryCount)/\(totalStoryCount) stories")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(sprint.capacityUsedPercent))% capacity")
                    .font(.caption)
                    .foregroundStyle(sprint.capacityUsedPercent > 100 ? .red : .secondary)
            }

            HStack {
                Text("\(sprint.completedPoints)/\(sprint.committedPoints) pts")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

struct SprintFormView: View {
    @Environment(\.dismiss) private var dismiss

    private let sprint: SprintDTO?
    private let sprintStore: SprintStore?
    private let treeStore: TreeStore?

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(14 * 24 * 60 * 60)
    @State private var capacityPoints = 40
    @State private var status: SprintStatusDTO = .planning

    init(sprintStore: SprintStore, sprint: SprintDTO? = nil) {
        self.sprintStore = sprintStore
        self.treeStore = nil
        self.sprint = sprint
        if let sprint {
            _name = State(initialValue: sprint.name)
            _startDate = State(initialValue: sprint.startDate)
            _endDate = State(initialValue: sprint.endDate)
            _capacityPoints = State(initialValue: sprint.capacityPoints)
            _status = State(initialValue: sprint.status)
        }
    }
    
    init(treeStore: TreeStore, sprint: SprintDTO? = nil) {
        self.sprintStore = nil
        self.treeStore = treeStore
        self.sprint = sprint
        if let sprint {
            _name = State(initialValue: sprint.name)
            _startDate = State(initialValue: sprint.startDate)
            _endDate = State(initialValue: sprint.endDate)
            _capacityPoints = State(initialValue: sprint.capacityPoints)
            _status = State(initialValue: sprint.status)
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
    }

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

                Section("Status") {
                    Picker("Sprint Status", selection: $status) {
                        ForEach(SprintStatusDTO.allCases, id: \.self) { sprintStatus in
                            Text(sprintStatus.displayName).tag(sprintStatus)
                        }
                    }
                }
            }
            .navigationTitle(sprint == nil ? "New Sprint" : "Edit Sprint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(sprint == nil ? "Create" : "Save") {
                        saveSprint()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func saveSprint() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            if let sprintStore {
                if let sprint {
                    // TODO: Update sprint via sprintStore
                } else {
                    // TODO: Create sprint via sprintStore
                }
            } else if let treeStore {
                // TODO: Create/update sprint via treeStore's MCP client
            }
        }

        dismiss()
    }
}

struct SprintDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var sprint: SprintDTO
    
    @State private var allItems: [TierItemDTO] = []
    
    var sprintItems: [TierItemDTO] {
        allItems.filter { $0.sprintId == sprint.id && $0.deletedAt == nil }
    }
    
    var availableItems: [TierItemDTO] {
        allItems.filter { $0.sprintId == nil && $0.deletedAt == nil && $0.type == .userStory }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Sprint Info") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Picker("", selection: $sprint.status) {
                            ForEach(SprintStatusDTO.allCases, id: \.self) { status in
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
                                    removeItemFromSprint(item)
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
                                        assignItemToSprint(item)
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
            .onAppear {
                Task {
                    await loadItems()
                }
            }
        }
    }
    
    private func loadItems() async {
        // TODO: Load items via MCP
        allItems = []
    }
    
    private func removeItemFromSprint(_ item: TierItemDTO) {
        // TODO: Update item via MCP to remove sprint assignment
        recalculatePoints()
    }
    
    private func assignItemToSprint(_ item: TierItemDTO) {
        // TODO: Update item via MCP to assign to sprint
        recalculatePoints()
    }
    
    private func recalculatePoints() {
        // TODO: Recalculate sprint points via MCP
    }
}

#Preview {
    SprintListView(sprintStore: SprintStore(mcpClient: MockMCPToolClient()))
}
