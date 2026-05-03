import SwiftUI

struct MainView: View {
    let mcpToolClient: MCPToolClient
    let projectName: String
    
    var body: some View {
        MainViewWithStore(mcpToolClient: mcpToolClient, projectName: projectName)
    }
}

private struct MainViewWithStore: View {
    @StateObject private var treeStore: TreeStore
    @State private var aiViewModel: AIWorkflowViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingAISuggestions = false
    @FocusState private var aiInputFocused: Bool
    
    let projectName: String
    
    init(mcpToolClient: MCPToolClient, projectName: String) {
        _treeStore = StateObject(wrappedValue: TreeStore(mcpClient: mcpToolClient))
        _aiViewModel = State(wrappedValue: AIWorkflowViewModel(mcpClient: mcpToolClient))
        self.projectName = projectName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            AIInputBar(
                text: $aiViewModel.inputText,
                isProcessing: $aiViewModel.isProcessing,
                isFocused: $aiInputFocused
            ) {
                await aiViewModel.parseRequirement()
                if !aiViewModel.currentSuggestions.isEmpty {
                    showingAISuggestions = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if let error = aiViewModel.error {
                ErrorBanner(message: error) {
                    aiViewModel.error = nil
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            Divider()
            
            NavigationSplitView(columnVisibility: $columnVisibility) {
                HierarchyTreeView(
                    treeStore: treeStore,
                    selectedItem: selectedItemBinding,
                    onAddChild: addChild,
                    onDelete: deleteItem,
                    onUpdateTitle: updateTitle
                )
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
                .navigationTitle(projectName)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: addCapability) {
                            Label("Add Capability", systemImage: "plus")
                        }
                    }
                }
                
            } content: {
                if let item = treeStore.selectedItem {
                    ItemDetailView(item: item, treeStore: treeStore)
                } else {
                    ContentUnavailableView(
                        "Select an Item",
                        systemImage: "sidebar.left",
                        description: Text("Choose a capability, feature, user story, or test case from the hierarchy")
                    )
                }
                
            } detail: {
                if let item = treeStore.selectedItem {
                    ItemPropertiesPanel(item: item, treeStore: treeStore)
                        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 500)
                } else {
                    ContentUnavailableView(
                        "No Details",
                        systemImage: "info.circle",
                        description: Text("Select an item to view its properties and metadata")
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: { columnVisibility = .all }) {
                        Label("Show All Columns", systemImage: "sidebar.left")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { aiInputFocused = true }) {
                        Label("AI Input", systemImage: "sparkles")
                    }
                    .keyboardShortcut("k", modifiers: .command)
                }
            }
            .task {
                await treeStore.loadTree()
            }
        }
        .sheet(isPresented: $showingAISuggestions) {
            AISuggestionsSheet(
                suggestions: aiViewModel.currentSuggestions,
                complexityEstimates: aiViewModel.complexityEstimates,
                dependencyDetections: aiViewModel.dependencyDetections,
                onAccept: { suggestion in
                    await aiViewModel.acceptSuggestion(suggestion)
                    await treeStore.loadTree()
                },
                onAcceptAll: {
                    await aiViewModel.acceptAllSuggestions()
                    await treeStore.loadTree()
                },
                onReject: { suggestion in
                    aiViewModel.rejectSuggestion(suggestion)
                },
                onDismiss: {
                    aiViewModel.clearSuggestions()
                }
            )
        }
    }
    
    private var selectedItemBinding: Binding<TierItemDTO?> {
        Binding(
            get: { treeStore.selectedItem },
            set: { treeStore.selectedItem = $0 }
        )
    }
    
    private func addCapability() {
        let nextPosition = Double(Date().timeIntervalSince1970)
        let capability = TierItemDTO(
            id: UUID(),
            type: .capability,
            parentId: nil,
            sprintId: nil,
            title: "New Capability",
            description: "Describe the business or technical capability.",
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
            await treeStore.createItem(capability)
            withAnimation {
                treeStore.selectedItem = capability
            }
        }
    }
    
    private func addChild(to parent: TierItemDTO, type: ItemTypeDTO) {
        let nextPosition = Double(parent.children.count)
        let child = TierItemDTO(
            id: UUID(),
            type: type,
            parentId: parent.id,
            sprintId: nil,
            title: "New \(type.displayName)",
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
            await treeStore.createItem(child, parent: parent)
            withAnimation {
                treeStore.selectedItem = child
            }
        }
    }
    
    private func deleteItem(_ item: TierItemDTO) {
        Task {
            await treeStore.deleteItem(item)
            withAnimation {
                if treeStore.selectedItem?.id == item.id {
                    treeStore.selectedItem = nil
                }
            }
        }
    }
    
    private func updateTitle(_ item: TierItemDTO, _ newTitle: String) {
        var updatedItem = item
        updatedItem.title = newTitle
        updatedItem.updatedAt = Date()
        Task {
            await treeStore.updateItem(updatedItem)
        }
    }
}

struct AISuggestionsSheet: View {
    let suggestions: [HierarchySuggestion]
    let complexityEstimates: [UUID: ComplexityEstimateDTO]
    let dependencyDetections: [UUID: DependencyDetectionDTO]
    let onAccept: (HierarchySuggestion) async -> Void
    let onAcceptAll: () async -> Void
    let onReject: (HierarchySuggestion) -> Void
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if suggestions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Suggestions")
                            .font(.headline)
                        Text("Enter a requirement to generate AI suggestions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(suggestions) { suggestion in
                                SuggestionCardWithDetails(
                                    suggestion: suggestion,
                                    complexityEstimate: complexityEstimates[suggestion.id],
                                    dependencyDetection: dependencyDetections[suggestion.id],
                                    onAccept: {
                                        await onAccept(suggestion)
                                        if suggestions.count == 1 {
                                            dismiss()
                                            onDismiss()
                                        }
                                    },
                                    onReject: {
                                        onReject(suggestion)
                                        if suggestions.isEmpty {
                                            dismiss()
                                            onDismiss()
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("AI Suggestions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
                
                if !suggestions.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Accept All") {
                            Task {
                                await onAcceptAll()
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct SuggestionCardWithDetails: View {
    let suggestion: HierarchySuggestion
    let complexityEstimate: ComplexityEstimateDTO?
    let dependencyDetection: DependencyDetectionDTO?
    let onAccept: () async -> Void
    let onReject: () -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.itemType.icon)
                    .foregroundStyle(suggestion.itemType.color)
                Text(suggestion.title)
                    .font(.headline)
                Spacer()
                ConfidenceBadge(confidence: suggestion.confidence)
            }
            
            if let description = suggestion.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            ReasoningPanel(reasoning: suggestion.reasoning, confidence: suggestion.confidence)
            
            if let estimate = complexityEstimate {
                HStack {
                    Image(systemName: "chart.bar")
                    Text("Estimated: \(estimate.storyPoints) pts (\(estimate.complexity))")
                        .font(.caption)
                    Spacer()
                    ConfidenceBadge.Compact(confidence: estimate.confidence)
                }
                .padding(.vertical, 4)
            }
            
            if let deps = dependencyDetection, !deps.dependencies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Dependencies: \(deps.dependencies.count)")
                            .font(.caption)
                    }
                    ForEach(deps.dependencies, id: \.storyId) { dep in
                        Text("• \(dep.storyTitle) (\(dep.dependencyType))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if !suggestion.children.isEmpty {
                DisclosureGroup("Children (\(suggestion.children.count))", isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(suggestion.children) { child in
                            HStack {
                                Image(systemName: child.itemType.icon)
                                    .foregroundStyle(child.itemType.color)
                                    .font(.caption)
                                Text(child.title)
                                    .font(.subheadline)
                                Spacer()
                                ConfidenceBadge.Compact(confidence: child.confidence)
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
                .font(.subheadline)
            }
            
            HStack {
                Button("Reject", role: .destructive) {
                    onReject()
                }
                
                Spacer()
                
                Button("Accept") {
                    Task {
                        await onAccept()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.red.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    MainView(
        mcpToolClient: MCPToolClient(clientManager: MCPClientManager()),
        projectName: "TierSpec Project"
    )
}
