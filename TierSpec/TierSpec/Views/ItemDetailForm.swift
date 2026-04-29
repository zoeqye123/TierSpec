//
//  ItemDetailForm.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI

struct ItemDetailForm: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var status: ItemStatus
    @Binding var priority: Int
    @Binding var storyPoints: Int?
    @Binding var complexity: Complexity?
    @Binding var validationError: String?
    
    let originalStatus: ItemStatus
    let actorType: ActorType
    
    @FocusState private var focusedField: Field?
    
    @State private var hasStoryPoints: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleField
            descriptionField
            statusPicker
            priorityField
            storyPointsField
            complexityPicker
        }
        .onAppear {
            hasStoryPoints = storyPoints != nil
        }
    }
    
    // MARK: - Title Field
    
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Title")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("*")
                    .foregroundStyle(.red)
            }
            
            TextField("Enter title (min 5 characters)", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .title)
                .onChange(of: title) { _, newValue in
                    validateTitle(newValue)
                }
            
            if title.count < 5 {
                Text("Title must be at least 5 characters (\(title.count)/5)")
                    .font(.caption2)
                    .foregroundStyle(title.isEmpty ? Color.secondary : Color.orange)
            }
        }
    }
    
    // MARK: - Description Field
    
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Description")
                .font(.caption)
                .fontWeight(.medium)
            
            TextEditor(text: $description)
                .frame(minHeight: 80, maxHeight: 150)
                .padding(4)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                .focused($focusedField, equals: .description)
        }
    }
    
    // MARK: - Status Picker
    
    private var statusPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Status")
                .font(.caption)
                .fontWeight(.medium)
            
            Picker("Status", selection: $status) {
                ForEach(allowedStatuses, id: \.self) { s in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(s.color)
                            .frame(width: 8, height: 8)
                        Text(s.displayName)
                    }
                    .tag(s)
                }
            }
            .pickerStyle(.menu)
            
            if status != originalStatus {
                Text("Transition: \(originalStatus.displayName) → \(status.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var allowedStatuses: [ItemStatus] {
        let allowed = StateMachine.allowedTransitions(from: originalStatus, actorType: actorType)
        if !allowed.contains(originalStatus) {
            return [originalStatus] + allowed
        }
        return allowed
    }
    
    // MARK: - Priority Field
    
    private var priorityField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Priority")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(priority)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(priorityColor)
            }
            
            Slider(value: Binding(
                get: { Double(priority) },
                set: { priority = Int($0) }
            ), in: 0...100, step: 1)
            .accentColor(priorityColor)
            
            HStack {
                Text("Low")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("High")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var priorityColor: Color {
        if priority < 30 { return .green }
        if priority < 60 { return .yellow }
        if priority < 80 { return .orange }
        return .red
    }
    
    // MARK: - Story Points Field
    
    private var storyPointsField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Has Story Points", isOn: $hasStoryPoints)
                .font(.caption)
                .fontWeight(.medium)
                .onChange(of: hasStoryPoints) { _, newValue in
                    if !newValue {
                        storyPoints = nil
                    } else if storyPoints == nil {
                        storyPoints = complexity?.defaultStoryPoints ?? 3
                    }
                }
            
            if hasStoryPoints {
                HStack(spacing: 12) {
                    // Fibonacci-style story point buttons
                    ForEach([1, 2, 3, 5, 8, 13, 21], id: \.self) { points in
                        Button {
                            storyPoints = points
                        } label: {
                            Text("\(points)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 32, height: 28)
                                .background(storyPoints == points ? Color.accentColor : Color.secondary.opacity(0.2),
                                           in: RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(storyPoints == points ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Complexity Picker
    
    private var complexityPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Complexity")
                .font(.caption)
                .fontWeight(.medium)
            
            HStack(spacing: 8) {
                ForEach(Complexity.allCases, id: \.self) { c in
                    Button {
                        complexity = c
                        if hasStoryPoints {
                            storyPoints = c.defaultStoryPoints
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(c.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("\(c.defaultStoryPoints)pt")
                                .font(.caption2)
                        }
                        .frame(width: 44, height: 40)
                        .background(complexity == c ? c.color : Color.secondary.opacity(0.1),
                                   in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(complexity == c ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private func validateTitle(_ newValue: String) {
        if newValue.isEmpty {
            validationError = "Title is required"
        } else if newValue.count < 5 {
            validationError = "Title must be at least 5 characters"
        } else {
            validationError = nil
        }
    }
}

// MARK: - Focus Field Enum

private enum Field: Hashable {
    case title
    case description
}

// MARK: - Preview

#Preview("Item Detail Form") {
    ItemDetailFormPreview()
}

struct ItemDetailFormPreview: View {
    @State var title = "Sample Item"
    @State var description = "This is a sample description"
    @State var status: ItemStatus = .in_progress
    @State var priority = 50
    @State var storyPoints: Int? = 5
    @State var complexity: Complexity? = .m
    @State var validationError: String?
    
    var body: some View {
        Form {
            ItemDetailForm(
                title: $title,
                description: $description,
                status: $status,
                priority: $priority,
                storyPoints: $storyPoints,
                complexity: $complexity,
                validationError: $validationError,
                originalStatus: .in_progress,
                actorType: .human
            )
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 600)
    }
}
