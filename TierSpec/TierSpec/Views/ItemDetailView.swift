//
//  ItemDetailView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

/// Detail view for viewing and editing a TierItem
struct ItemDetailView: View {
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The item being viewed/edited
    let item: TierItem
    
    /// Whether we're in edit mode
    @State private var isEditing: Bool = false
    
    /// Draft values for editing (copied from item when editing starts)
    @State private var draftTitle: String = ""
    @State private var draftDescription: String = ""
    @State private var draftStatus: ItemStatus = .requirement_input
    @State private var draftPriority: Int = 0
    @State private var draftStoryPoints: Int?
    @State private var draftComplexity: Complexity?
    
    /// Validation state
    @State private var validationError: String?
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with type badge
                headerView
                
                Divider()
                
                // Content area
                if isEditing {
                    ItemDetailForm(
                        title: $draftTitle,
                        description: $draftDescription,
                        status: $draftStatus,
                        priority: $draftPriority,
                        storyPoints: $draftStoryPoints,
                        complexity: $draftComplexity,
                        validationError: $validationError,
                        originalStatus: item.status
                    )
                    
                    Divider()
                    
                    // Edit action buttons
                    editActionButtons
                } else {
                    // Read-only view
                    readOnlyContent
                    
                    Divider()
                    
                    // View action buttons
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
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: item.type.icon)
                .font(.title2)
                .foregroundStyle(item.status.color)
            
            VStack(alignment: .leading, spacing: 4) {
                // Type badge
                Text(item.type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                // Status badge
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
            
            // AI badge if applicable
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
    
    // MARK: - Read-Only Content
    
    private var readOnlyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            DetailRow(label: "Title", value: item.title)
            
            // Description
            if let description = item.itemDescription, !description.isEmpty {
                DetailRow(label: "Description", value: description, isMultiline: true)
            }
            
            // Status
            DetailRow(label: "Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 10, height: 10)
                    Text(item.status.displayName)
                }
            }
            
            // Priority
            DetailRow(label: "Priority", value: "\(item.priority)")
            
            // Story Points
            if let storyPoints = item.storyPoints {
                DetailRow(label: "Story Points", value: "\(storyPoints)")
            }
            
            // Complexity
            if let complexity = item.complexity {
                DetailRow(label: "Complexity") {
                    Text(complexity.displayName)
                        .foregroundStyle(complexity.color)
                }
            }
            
            // Labels
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
            
            // Timestamps
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
        }
    }
    
    // MARK: - View Action Buttons
    
    private var viewActionButtons: some View {
        HStack {
            Spacer()
            
            Button("Close", role: .cancel) {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Edit Action Buttons
    
    private var editActionButtons: some View {
        VStack(spacing: 8) {
            // Validation error
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
    
    // MARK: - Validation
    
    private var isValid: Bool {
        // Title must be at least 5 characters
        guard draftTitle.count >= 5 else { return false }
        return true
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        // Copy current values to draft
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
        // Discard changes
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
                try StateMachine.assertValidTransition(from: item.status, to: draftStatus)
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
}

// MARK: - Detail Row Component

private struct DetailRow<Content: View>: View {
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

// MARK: - Flow Layout Helper

private struct FlowLayout: Layout {
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
