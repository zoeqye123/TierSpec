//
//  ContentView.swift
//  TierSpec
//
//  Created by z on 2026/4/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItem: TierItem?
    @State private var searchText: String = ""
    @State private var searchResults: [TierItem] = []
    @State private var isSearching: Bool = false
    @State private var navigationPath = NavigationPath()
    
    enum Destination: Hashable {
        case sprints
        case kanban
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                searchField
                
                Divider()
                
                List {
                    Section("Hierarchy") {
                        HierarchyTreeView(selectedItem: $selectedItem)
                    }
                    
                    Section {
                        NavigationLink(value: Destination.sprints) {
                            Label("Sprints", systemImage: "calendar.badge.clock")
                        }
                        NavigationLink(value: Destination.kanban) {
                            Label("Kanban Board", systemImage: "square.grid.3x3")
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle("TierSpec")
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .sprints:
                        SprintListView()
                    case .kanban:
                        KanbanView()
                    }
                }
                .toolbar {
                    ToolbarItem {
                        Button(action: addCapability) {
                            Label("Add Capability", systemImage: "plus")
                        }
                    }
                }
            }
        } detail: {
            if let selectedItem {
                ItemDetailView(item: selectedItem)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a capability, feature, epic, story, or test case to inspect and edit it.")
                )
            }
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
    }
    
    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search items...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let descriptor = FetchDescriptor<TierItem>(
            predicate: #Predicate { item in
                item.deletedAt == nil &&
                (item.title.localizedStandardContains(query) ||
                 (item.itemDescription != nil && item.itemDescription!.localizedStandardContains(query)))
            },
            sortBy: [SortDescriptor(\TierItem.updatedAt, order: .reverse)]
        )
        
        do {
            searchResults = try modelContext.fetch(descriptor)
        } catch {
            searchResults = []
        }
    }
    
    private func addCapability() {
        withAnimation {
            let nextPosition = Double(Date().timeIntervalSince1970)
            let capability = TierItem(
                type: .capability,
                title: "New Capability",
                description: "Describe the business or technical capability.",
                status: .requirement_input,
                position: nextPosition
            )
            modelContext.insert(capability)
            selectedItem = capability
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TierItem.self, inMemory: true)
}
