//
//  ReasoningPanel.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/2.
//

import SwiftUI

/// Expandable panel displaying AI reasoning and confidence score
/// Used to explain why AI made a particular suggestion
struct ReasoningPanel: View {
    let reasoning: String
    let confidence: Double?
    
    // MARK: - State
    
    @State private var isExpanded: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    
                    // AI indicator
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    
                    // Title
                    Text("AI Reasoning")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    // Confidence badge (if available)
                    if let confidence = confidence {
                        ConfidenceBadge.Compact(confidence: confidence)
                    }
                    
                    Spacer()
                    
                    // Expand hint
                    Text(isExpanded ? "Click to collapse" : "Click to expand")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text(reasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
                .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Compact Variant

extension ReasoningPanel {
    /// Inline variant that shows reasoning directly without expand/collapse
    struct Inline: View {
        let reasoning: String
        let confidence: Double?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    
                    Text("AI Reasoning")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if let confidence = confidence {
                        ConfidenceBadge.Compact(confidence: confidence)
                    }
                }
                
                Text(reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Previews

#Preview("ReasoningPanel - Collapsed") {
    ReasoningPanel(
        reasoning: "This user story was identified as a core authentication feature because it involves third-party OAuth integration, which is typically a fundamental capability for modern applications.",
        confidence: 0.85
    )
    .padding()
}

#Preview("ReasoningPanel - Expanded") {
    struct PreviewWrapper: View {
        @State var isExpanded = true
        
        var body: some View {
            ReasoningPanel(
                reasoning: "This user story was identified as a core authentication feature because it involves third-party OAuth integration, which is typically a fundamental capability for modern applications. The complexity estimate of 5 story points accounts for: (1) OAuth 2.0 flow implementation, (2) Error handling for network failures, (3) Token refresh logic, and (4) UI for login button and loading states.",
                confidence: 0.85
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}

#Preview("ReasoningPanel - No Confidence") {
    ReasoningPanel(
        reasoning: "This feature was grouped under the 'Authentication' capability based on keyword analysis.",
        confidence: nil
    )
    .padding()
}

#Preview("ReasoningPanel.Inline") {
    ReasoningPanel.Inline(
        reasoning: "Estimated 5 story points based on OAuth integration complexity.",
        confidence: 0.72
    )
    .padding()
}

#Preview("ReasoningPanel - All Variants") {
    VStack(spacing: 16) {
        Text("Expandable Panel")
            .font(.headline)
        
        ReasoningPanel(
            reasoning: "This user story was identified as a core authentication feature because it involves third-party OAuth integration.",
            confidence: 0.85
        )
        
        Divider()
        
        Text("Inline Variant")
            .font(.headline)
        
        ReasoningPanel.Inline(
            reasoning: "Estimated 5 story points based on OAuth integration complexity.",
            confidence: 0.72
        )
    }
    .padding()
    .frame(width: 400)
}
