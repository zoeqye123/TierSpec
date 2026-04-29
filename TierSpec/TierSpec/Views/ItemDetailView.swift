//
//  ItemDetailView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let item: TierItem
    
    @State private var isEditing: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftDescription: String = ""
    @State private var draftStatus: ItemStatus = .todo
    @State private var draftPriority: Int = 0
    @State private var draftStoryPoints: Int?
    @State private var draftComplexity: Complexity?
    @State private var validationError: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                
                Divider()
                
                if isEditing {
                    ItemDetailForm(
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
            breadcrumbView
            
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
    
    @ViewBuilder
    private var breadcrumbView: some View {
        if item.depth > 0 {
            HStack(spacing: 4) {
                ForEach(Array(item.path.dropLast().enumerated()), id: \.element.id) { index, pathItem in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(pathItem.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private var readOnlyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailRow(label: "Title", value: item.title)
            
            if let description = item.itemDescription, !description.isEmpty {
                DetailRow(label: "Description", value: description, isMultiline: true)
            }
            
            DetailRow(label: "Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 10, height: 10)
                    Text(item.status.displayName)
                }
            }
            
            DetailRow(label: "Priority", value: "\(item.priority)")
            
            if let storyPoints = item.storyPoints {
                DetailRow(label: "Story Points", value: "\(storyPoints)")
            }
            
            if let complexity = item.complexity {
                DetailRow(label: "Complexity") {
                    Text(complexity.displayName)
                        .foregroundStyle(complexity.color)
                }
            }
            
            if !item.labels.isEmpty {
                DetailRow(label: "Labels") {
                    FlowLayout(spacing: 4) {
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
            
            if item.type == .user_story {
                testCasesSection
            }
        }
    }
    
    @ViewBuilder
    private var testCasesSection: some View {
        let testCases = (item.children ?? []).filter { $0.deletedAt == nil }
        
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
                    TestCaseRow(testCase: tc)
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
        draftDescription = item.itemDescription ?? ""
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
                try StateMachine.assertValidTransition(
                    from: item.status,
                    to: draftStatus,
                    actorType: item.aiGenerated ? .ai : .human
                )
            } catch {
                validationError = error.localizedDescription
                return
            }
        }
        
        item.title = draftTitle
        item.itemDescription = draftDescription.isEmpty ? nil : draftDescription
        item.status = draftStatus
        item.priority = draftPriority
        item.storyPoints = draftStoryPoints
        item.complexity = draftComplexity
        item.touch()
        
        isEditing = false
        validationError = nil
    }
    
    private func addTestCase() {
        let nextPosition = Double((item.children ?? []).filter({ $0.deletedAt == nil }).count)
        let testCase = TierItem(
            type: .test_case,
            title: "New Test Case",
            description: nil,
            status: .todo,
            position: nextPosition
        )
        testCase.parent = item
        if item.children == nil {
            item.children = []
        }
        item.children?.append(testCase)
        modelContext.insert(testCase)
    }
}

struct TestCaseRow: View {
    let testCase: TierItem
    
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

struct DetailRow<Content: View>: View {
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
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
