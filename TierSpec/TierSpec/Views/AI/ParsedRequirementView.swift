//
//  ParsedRequirementView.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/2.
//

import SwiftUI

/// View displaying the full parsed requirement hierarchy
/// Shows nested structure of suggested items with bulk actions
struct ParsedRequirementView: View {
    let suggestions: [HierarchySuggestion]
    let onAcceptAll: () -> Void
    let onRejectAll: () -> Void
    
    @State private var expandedItems: Set<UUID> = []
    @State private var selectedItems: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if suggestions.isEmpty {
                        emptyStateView
                    } else {
                        summaryCard
                        
                        Divider()
                        
                        ForEach(suggestions) { suggestion in
                            HierarchyNodeView(
                                suggestion: suggestion,
                                expandedItems: $expandedItems,
                                selectedItems: $selectedItems,
                                depth: 0
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Parsed Requirements")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                if !suggestions.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Reject All", role: .destructive) {
                            onRejectAll()
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Accept All") {
                            onAcceptAll()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Suggestions")
                .font(.headline)
            
            Text("Enter a requirement description to generate AI suggestions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var summaryCard: some View {
        HStack(spacing: 16) {
            StatBadge(
                icon: "cube.box",
                label: "Capabilities",
                count: countItems(ofType: .capability)
            )
            
            StatBadge(
                icon: "square.grid.2x2",
                label: "Features",
                count: countItems(ofType: .feature)
            )
            
            StatBadge(
                icon: "person.text.rectangle",
                label: "Stories",
                count: countItems(ofType: .userStory)
            )
            
            StatBadge(
                icon: "checkmark.shield",
                label: "Tests",
                count: countItems(ofType: .testCase)
            )
        }
        .padding(12)
        .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func countItems(ofType type: ItemTypeDTO) -> Int {
        var count = 0
        func traverse(_ items: [HierarchySuggestion]) {
            for item in items {
                if item.itemType == type { count += 1 }
                traverse(item.children)
            }
        }
        traverse(suggestions)
        return count
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let icon: String
    let label: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hierarchy Node View

struct HierarchyNodeView: View {
    let suggestion: HierarchySuggestion
    @Binding var expandedItems: Set<UUID>
    @Binding var selectedItems: Set<UUID>
    let depth: Int
    
    @State private var showReasoning: Bool = false
    
    private var isExpanded: Bool { expandedItems.contains(suggestion.id) }
    private var isSelected: Bool { selectedItems.contains(suggestion.id) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nodeRow
            
            if isExpanded {
                childrenView
            }
        }
    }
    
    private var nodeRow: some View {
        HStack(spacing: 8) {
            expandButton
            
            typeIcon
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    ConfidenceBadge.Compact(confidence: suggestion.confidence)
                }
                
                Text(suggestion.itemType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            reasoningToggle
            
            if let description = suggestion.description, !description.isEmpty {
                Button(action: { showReasoning.toggle() }) {
                    Image(systemName: showReasoning ? "info.circle.fill" : "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("View details")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { toggleSelect() }
    }
    
    private var expandButton: some View {
        Group {
            if suggestion.children.isEmpty {
                Spacer().frame(width: 16)
            } else {
                Button(action: toggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.borderless)
            }
        }
    }
    
    private var typeIcon: some View {
        Image(systemName: suggestion.itemType.icon)
            .font(.body)
            .foregroundStyle(suggestion.itemType.color)
            .frame(width: 20)
    }
    
    private var reasoningToggle: some View {
        Button(action: { showReasoning.toggle() }) {
            Image(systemName: showReasoning ? "eye.slash" : "eye")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .opacity(suggestion.reasoning.isEmpty ? 0 : 1)
    }
    
    @ViewBuilder
    private var childrenView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showReasoning && !suggestion.reasoning.isEmpty {
                Text(suggestion.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.leading, CGFloat(depth + 1) * 20 + 12)
            }
            
            ForEach(suggestion.children) { child in
                HierarchyNodeView(
                    suggestion: child,
                    expandedItems: $expandedItems,
                    selectedItems: $selectedItems,
                    depth: depth + 1
                )
                .padding(.leading, 20)
            }
        }
    }
    
    private func toggleExpand() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedItems.contains(suggestion.id) {
                expandedItems.remove(suggestion.id)
            } else {
                expandedItems.insert(suggestion.id)
            }
        }
    }
    
    private func toggleSelect() {
        if selectedItems.contains(suggestion.id) {
            selectedItems.remove(suggestion.id)
        } else {
            selectedItems.insert(suggestion.id)
        }
    }
}

// MARK: - Previews

#Preview("ParsedRequirementView - Empty") {
    ParsedRequirementView(
        suggestions: [],
        onAcceptAll: { print("Accept All") },
        onRejectAll: { print("Reject All") }
    )
}

#Preview("ParsedRequirementView - With Suggestions") {
    let suggestions = [
        HierarchySuggestion(
            title: "User Authentication",
            description: "Core authentication capability for the application",
            itemType: .capability,
            confidence: 0.92,
            reasoning: "Identified as a core capability based on multiple authentication-related requirements.",
            children: [
                HierarchySuggestion(
                    title: "Social Login",
                    description: "Third-party OAuth integration",
                    itemType: .feature,
                    confidence: 0.88,
                    reasoning: "Feature extracted from requirement mentioning Google and Apple sign-in.",
                    children: [
                        HierarchySuggestion(
                            title: "As a user, I want to login with my Google account",
                            description: "User story for Google OAuth login",
                            itemType: .userStory,
                            confidence: 0.85,
                            reasoning: "Standard user story format detected.",
                            children: [
                                HierarchySuggestion(
                                    title: "Verify Google OAuth token is valid",
                                    description: nil,
                                    itemType: .testCase,
                                    confidence: 0.75,
                                    reasoning: "Test case to validate authentication flow."
                                )
                            ]
                        )
                    ]
                ),
                HierarchySuggestion(
                    title: "Email/Password Login",
                    description: "Traditional email and password authentication",
                    itemType: .feature,
                    confidence: 0.82,
                    reasoning: "Standard authentication method for most applications.",
                    children: [
                        HierarchySuggestion(
                            title: "As a user, I want to login with my email and password",
                            description: nil,
                            itemType: .userStory,
                            confidence: 0.80,
                            reasoning: "Basic authentication user story."
                        )
                    ]
                )
            ]
        )
    ]
    
    return ParsedRequirementView(
        suggestions: suggestions,
        onAcceptAll: { print("Accept All") },
        onRejectAll: { print("Reject All") }
    )
}
