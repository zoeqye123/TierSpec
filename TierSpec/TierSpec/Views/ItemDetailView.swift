//
//  ItemDetailView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let item: TierItemDTO
    @ObservedObject var treeStore: TreeStore
    
    @State private var isEditing: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftDescription: String = ""
    @State private var draftStatus: ItemStatusDTO = .todo
    @State private var draftPriority: Int = 0
    @State private var draftStoryPoints: Int?
    @State private var draftComplexity: ComplexityDTO?
    @State private var validationError: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                
                Divider()
                
                if isEditing {
                    ItemDetailFormDTO(
                        title: $draftTitle,
                        description: $draftDescription,
                        status: $draftStatus,
                        priority: $draftPriority,
                        storyPoints: $draftStoryPoints,
                        complexity: $draftComplexity,
                        validationError: $validationError,
                        originalStatus: item.status,
                        actorType: item.aiGenerated ? .ai : .human
                    )
                    
                    Divider()
                    
                    editActionButtons
                } else {
                    readOnlyContent
                    
                    Divider()
                    
                    viewActionButtons
                }
            }
            .padding()
        }
        .navigationTitle(item.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !isEditing {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: item.type.icon)
                    .font(.title2)
                    .foregroundStyle(item.status.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.status.color)
                            .frame(width: 8, height: 8)
                        Text(item.status.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if item.aiGenerated {
                    Label("AI", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.1), in: Capsule())
                }
            }
        }
    }
    
    private var readOnlyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailRowDTO(label: "Title", value: item.title)
            
            if let description = item.description, !description.isEmpty {
                DetailRowDTO(label: "Description", value: description, isMultiline: true)
            }
            
            DetailRowDTO(label: "Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 10, height: 10)
                    Text(item.status.displayName)
                }
            }
            
            DetailRowDTO(label: "Priority", value: "\(item.priority)")
            
            if let storyPoints = item.storyPoints {
                DetailRowDTO(label: "Story Points", value: "\(storyPoints)")
            }
            
            if let complexity = item.complexity {
                DetailRowDTO(label: "Complexity") {
                    Text(complexity.displayName)
                        .foregroundStyle(complexity.color)
                }
            }
            
            if !item.labels.isEmpty {
                DetailRowDTO(label: "Labels") {
                    FlowLayoutDTO(spacing: 4) {
                        ForEach(item.labels, id: \.self) { label in
                            Text(label)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.createdAt, style: .date)
                        .font(.caption2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Updated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.updatedAt, style: .date)
                        .font(.caption2)
                }
            }
            
            if item.type == .userStory {
                testCasesSection
            }
        }
    }
    
    @ViewBuilder
    private var testCasesSection: some View {
        let testCases = item.children.filter { $0.deletedAt == nil }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Test Cases")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    addTestCase()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            if testCases.isEmpty {
                Text("No test cases")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(testCases.sorted { $0.position < $1.position }) { tc in
                    TestCaseRowDTO(testCase: tc)
                }
            }
        }
    }
    
    private var viewActionButtons: some View {
        HStack {
            Spacer()
            
            Button("Close", role: .cancel) {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var editActionButtons: some View {
        VStack(spacing: 8) {
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                Button("Cancel", role: .cancel) {
                    cancelEditing()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
    }
    
    private var isValid: Bool {
        guard draftTitle.count >= 5 else { return false }
        return true
    }
    
    private func startEditing() {
        draftTitle = item.title
        draftDescription = item.description ?? ""
        draftStatus = item.status
        draftPriority = item.priority
        draftStoryPoints = item.storyPoints
        draftComplexity = item.complexity
        validationError = nil
        isEditing = true
    }
    
    private func cancelEditing() {
        isEditing = false
        validationError = nil
    }
    
    private func saveChanges() {
        guard draftTitle.count >= 5 else {
            validationError = "Title must be at least 5 characters"
            return
        }
        
        if draftStatus != item.status {
            do {
                try StateMachineDTO.assertValidTransition(
                    from: item.status,
                    to: draftStatus,
                    actorType: item.aiGenerated ? .ai : .human
                )
            } catch {
                validationError = error.localizedDescription
                return
            }
        }
        
        Task {
            let updatedItem = TierItemDTO(
                id: item.id,
                type: item.type,
                parentId: item.parentId,
                sprintId: item.sprintId,
                title: draftTitle,
                description: draftDescription.isEmpty ? nil : draftDescription,
                status: draftStatus,
                priority: draftPriority,
                position: item.position,
                storyPoints: draftStoryPoints,
                complexity: draftComplexity,
                aiGenerated: item.aiGenerated,
                aiConfidence: item.aiConfidence,
                aiReasoning: item.aiReasoning,
                labels: item.labels,
                createdAt: item.createdAt,
                updatedAt: Date(),
                deletedAt: item.deletedAt,
                children: item.children
            )
            await treeStore.updateItem(updatedItem)
        }
        
        isEditing = false
        validationError = nil
    }
    
    private func addTestCase() {
        let nextPosition = Double(item.children.filter({ $0.deletedAt == nil }).count)
        let testCase = TierItemDTO(
            id: UUID(),
            type: .testCase,
            parentId: item.id,
            sprintId: nil,
            title: "New Test Case",
            description: nil,
            status: .todo,
            priority: 0,
            position: nextPosition,
            storyPoints: nil,
            complexity: nil,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        )
        
        Task {
            await treeStore.createItem(testCase, parent: item)
        }
    }
}

struct TestCaseRowDTO: View {
    let testCase: TierItemDTO
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(testCase.status == .done ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(testCase.title)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(testCase.status.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct DetailRowDTO<Content: View>: View {
    let label: String
    let content: () -> Content
    
    init(label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }
    
    init(label: String, value: String, isMultiline: Bool = false) where Content == Text {
        self.label = label
        self.content = {
            Text(value)
                .foregroundStyle(isMultiline ? .primary : .secondary)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

struct FlowLayoutDTO: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResultDTO(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResultDTO(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResultDTO {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

struct ItemDetailFormDTO: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var status: ItemStatusDTO
    @Binding var priority: Int
    @Binding var storyPoints: Int?
    @Binding var complexity: ComplexityDTO?
    @Binding var validationError: String?
    
    let originalStatus: ItemStatusDTO
    let actorType: ActorTypeDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                TextEditor(text: $description)
                    .frame(minHeight: 80)
                    .border(Color.secondary.opacity(0.2))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Picker("Status", selection: $status) {
                    ForEach(ItemStatusDTO.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.menu)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Priority")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Stepper("Priority: \(priority)", value: $priority, in: 0...100)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Story Points")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                OptionalStepper(value: $storyPoints, in: 1...21, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Complexity")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Picker("Complexity", selection: $complexity) {
                    Text("None").tag(nil as ComplexityDTO?)
                    ForEach(ComplexityDTO.allCases, id: \.self) { c in
                        Text(c.displayName).tag(c as ComplexityDTO?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

struct OptionalStepper: View {
    @Binding var value: Int?
    let range: ClosedRange<Int>
    let step: Int
    
    init(value: Binding<Int?>, in range: ClosedRange<Int>, step: Int) {
        self._value = value
        self.range = range
        self.step = step
    }
    
    var body: some View {
        HStack {
            Toggle("Set", isOn: Binding(
                get: { value != nil },
                set: { if $0 { value = range.lowerBound } else { value = nil } }
            ))
            
            if let current = value {
                Stepper("\(current) pts", value: Binding(
                    get: { current },
                    set: { value = $0 }
                ), in: range, step: step)
            }
        }
    }
}

#Preview {
    ItemDetailView(
        item: TierItemDTO(
            id: UUID(),
            type: .userStory,
            parentId: nil,
            sprintId: nil,
            title: "Sample Story",
            description: "A sample story",
            status: .todo,
            priority: 50,
            position: 0,
            storyPoints: 5,
            complexity: .m,
            aiGenerated: false,
            aiConfidence: nil,
            aiReasoning: nil,
            labels: ["frontend"],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            children: []
        ),
        treeStore: TreeStore(mcpClient: MockMCPToolClient())
    )
}
