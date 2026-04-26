//
//  KanbanView.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/26.
//

import SwiftUI
import SwiftData

struct KanbanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TierItem> { $0.deletedAt == nil }, sort: \TierItem.priority, order: .reverse) private var items: [TierItem]
    
    @State private var selectedItem: TierItem?
    
    private let columns = [
        ItemStatus.backlog,
        .in_progress,
        .waiting_for_test,
        .testing,
        .completed,
        .blocked,
    ]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns, id: \.self) { status in
                    KanbanColumn(
                        status: status,
                        items: items.filter { $0.status == status },
                        selectedItem: $selectedItem
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Kanban Board")
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
        }
    }
}

struct KanbanColumn: View {
    let status: ItemStatus
    let items: [TierItem]
    @Binding var selectedItem: TierItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        KanbanCard(item: item)
                            .onTapGesture {
                                selectedItem = item
                            }
                    }
                }
            }
        }
        .frame(width: 260)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
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
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    KanbanView()
        .modelContainer(for: TierItem.self, inMemory: true)
}
