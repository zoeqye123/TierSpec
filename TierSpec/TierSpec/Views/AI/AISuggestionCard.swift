//
//  AISuggestionCard.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/2.
//

import SwiftUI

/// Card displaying a parsed requirement suggestion from AI
/// Shows title, item type, confidence score, and reasoning
/// Provides Accept/Reject/Edit actions
struct AISuggestionCard: View {
    let title: String
    let itemType: ItemTypeDTO
    let confidence: Double
    let reasoning: String
    let onAccept: () -> Void
    let onReject: () -> Void
    let onEdit: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var showReasoning: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            
            Divider()
            
            actionButtons
            
            if showReasoning {
                ReasoningPanel.Inline(reasoning: reasoning, confidence: confidence)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(
                    color: isHovered ? .black.opacity(0.12) : .black.opacity(0.06),
                    radius: isHovered ? 8 : 4,
                    y: isHovered ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(itemType.color.opacity(isHovered ? 0.5 : 0.3), lineWidth: isHovered ? 2 : 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            itemTypeIcon
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(itemType.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(itemType.color)
                    
                    ConfidenceBadge.Compact(confidence: confidence)
                }
                
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    private var itemTypeIcon: some View {
        ZStack {
            Circle()
                .fill(itemType.color.opacity(0.15))
                .frame(width: 40, height: 40)
            
            Image(systemName: itemType.icon)
                .font(.system(size: 18))
                .foregroundStyle(itemType.color)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(role: .destructive, action: onReject) {
                Label("Reject", systemImage: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Spacer()
            
            Button(action: { showReasoning.toggle() }) {
                Image(systemName: showReasoning ? "eye.slash" : "eye")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(showReasoning ? "Hide reasoning" : "Show reasoning")
            
            Button(action: onAccept) {
                Label("Accept", systemImage: "checkmark")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

// MARK: - ItemType Extensions

extension ItemTypeDTO {
    var color: Color {
        switch self {
        case .capability: return .blue
        case .feature: return .purple
        case .userStory: return .orange
        case .testCase: return .green
        }
    }
}

// MARK: - Compact Variant

extension AISuggestionCard {
    /// Compact variant for use in lists with limited space
    struct Compact: View {
        let title: String
        let itemType: ItemTypeDTO
        let confidence: Double
        let onAccept: () -> Void
        let onReject: () -> Void
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: itemType.icon)
                    .font(.body)
                    .foregroundStyle(itemType.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(itemType.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        ConfidenceBadge.Compact(confidence: confidence)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Button(action: onReject) {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    
                    Button(action: onAccept) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Previews

#Preview("AISuggestionCard - All Types") {
    VStack(spacing: 16) {
        AISuggestionCard(
            title: "User Authentication",
            itemType: .capability,
            confidence: 0.92,
            reasoning: "This capability was identified as a core system requirement based on the mention of login, OAuth, and security features.",
            onAccept: { print("Accept") },
            onReject: { print("Reject") },
            onEdit: { print("Edit") }
        )
        
        AISuggestionCard(
            title: "Social Login Integration",
            itemType: .feature,
            confidence: 0.78,
            reasoning: "Feature extracted from requirement text mentioning Google and Apple sign-in options.",
            onAccept: { print("Accept") },
            onReject: { print("Reject") },
            onEdit: { print("Edit") }
        )
        
        AISuggestionCard(
            title: "As a user, I want to login with my Google account",
            itemType: .userStory,
            confidence: 0.85,
            reasoning: "User story format detected with clear actor, action, and benefit.",
            onAccept: { print("Accept") },
            onReject: { print("Reject") },
            onEdit: { print("Edit") }
        )
        
        AISuggestionCard(
            title: "Verify Google OAuth token is valid",
            itemType: .testCase,
            confidence: 0.65,
            reasoning: "Test case suggested to validate authentication flow.",
            onAccept: { print("Accept") },
            onReject: { print("Reject") },
            onEdit: { print("Edit") }
        )
    }
    .padding()
    .frame(width: 450)
}

#Preview("AISuggestionCard.Compact") {
    VStack(spacing: 8) {
        AISuggestionCard.Compact(
            title: "User Authentication",
            itemType: .capability,
            confidence: 0.92,
            onAccept: { print("Accept") },
            onReject: { print("Reject") }
        )
        
        AISuggestionCard.Compact(
            title: "Social Login Integration",
            itemType: .feature,
            confidence: 0.78,
            onAccept: { print("Accept") },
            onReject: { print("Reject") }
        )
        
        AISuggestionCard.Compact(
            title: "As a user, I want to login with Google",
            itemType: .userStory,
            confidence: 0.85,
            onAccept: { print("Accept") },
            onReject: { print("Reject") }
        )
    }
    .padding()
    .frame(width: 400)
}
