//
//  AISuggestionsView.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/4/30.
//

import SwiftUI

struct AISuggestionsView: View {
    @Binding var suggestions: [SprintAssignmentSuggestion]
    let onApply: (SprintAssignmentSuggestion) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if suggestions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No suggestions available")
                            .font(.headline)
                        Text("All items might be already assigned or capacity is full.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if let displayId = suggestion.story.displayId {
                                    Text(displayId)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)
                                }
                                
                                Text(suggestion.story.title)
                                    .font(.headline)
                                
                                Spacer()
                                
                                if let points = suggestion.story.storyPoints {
                                    Text("\(points) pts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack {
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                
                                Text(suggestion.suggestedSprint.name)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Button("Apply") {
                                    onApply(suggestion)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            
                            Text(suggestion.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("AI Sprint Suggestions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                if !suggestions.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply All") {
                            for suggestion in suggestions {
                                onApply(suggestion)
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}
