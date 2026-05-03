//
//  ConfidenceBadge.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/2.
//

import SwiftUI

/// Badge displaying AI confidence score with color coding
/// Confidence levels:
/// - 0.8-1.0: Green (High)
/// - 0.6-0.8: Yellow (Medium)
/// - 0.4-0.6: Orange (Low)
/// - 0.0-0.4: Red (Very Low)
struct ConfidenceBadge: View {
    let confidence: Double // 0.0 to 1.0
    
    // MARK: - Computed Properties
    
    private var level: ConfidenceLevel {
        ConfidenceLevel(confidence: confidence)
    }
    
    private var percentageText: String {
        String(format: "%.0f%%", confidence * 100)
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
                .font(.caption2)
            
            Text(percentageText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(level.foregroundStyle)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(level.background, in: Capsule())
    }
}

// MARK: - Confidence Level

enum ConfidenceLevel {
    case high      // 0.8 - 1.0
    case medium    // 0.6 - 0.8
    case low       // 0.4 - 0.6
    case veryLow   // 0.0 - 0.4
    
    init(confidence: Double) {
        switch confidence {
        case 0.8...1.0:
            self = .high
        case 0.6..<0.8:
            self = .medium
        case 0.4..<0.6:
            self = .low
        default:
            self = .veryLow
        }
    }
    
    var icon: String {
        switch self {
        case .high: return "checkmark.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .veryLow: return "xmark.circle.fill"
        }
    }
    
    var label: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .veryLow: return "Very Low"
        }
    }
    
    var foregroundStyle: Color {
        switch self {
        case .high: return .white
        case .medium: return .black
        case .low: return .white
        case .veryLow: return .white
        }
    }
    
    var background: Color {
        switch self {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        case .veryLow: return .red
        }
    }
}

// MARK: - Compact Variant

extension ConfidenceBadge {
    /// Compact inline variant for use in headers and lists
    struct Compact: View {
        let confidence: Double
        
        private var level: ConfidenceLevel {
            ConfidenceLevel(confidence: confidence)
        }
        
        var body: some View {
            HStack(spacing: 3) {
                Circle()
                    .fill(level.background)
                    .frame(width: 6, height: 6)
                
                Text(String(format: "%.0f%%", confidence * 100))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Detailed Variant

extension ConfidenceBadge {
    /// Detailed badge with label text
    struct Detailed: View {
        let confidence: Double
        
        private var level: ConfidenceLevel {
            ConfidenceLevel(confidence: confidence)
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: level.icon)
                        .font(.caption)
                    
                    Text("AI Confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 8) {
                    Text(String(format: "%.0f%%", confidence * 100))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(level.background)
                    
                    Text(level.label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(level.background)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level.background)
                            .frame(width: geometry.size.width * CGFloat(confidence))
                    }
                }
                .frame(height: 4)
            }
            .padding(12)
            .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Previews

#Preview("ConfidenceBadge - All Levels") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            ConfidenceBadge(confidence: 0.95)
            Text("High (0.8-1.0)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        
        HStack(spacing: 12) {
            ConfidenceBadge(confidence: 0.72)
            Text("Medium (0.6-0.8)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        
        HStack(spacing: 12) {
            ConfidenceBadge(confidence: 0.48)
            Text("Low (0.4-0.6)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        
        HStack(spacing: 12) {
            ConfidenceBadge(confidence: 0.25)
            Text("Very Low (0.0-0.4)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}

#Preview("ConfidenceBadge.Compact") {
    VStack(spacing: 12) {
        HStack {
            Text("Story 1")
            Spacer()
            ConfidenceBadge.Compact(confidence: 0.92)
        }
        
        HStack {
            Text("Story 2")
            Spacer()
            ConfidenceBadge.Compact(confidence: 0.65)
        }
        
        HStack {
            Text("Story 3")
            Spacer()
            ConfidenceBadge.Compact(confidence: 0.38)
        }
    }
    .padding()
    .frame(width: 300)
}

#Preview("ConfidenceBadge.Detailed") {
    VStack(spacing: 16) {
        ConfidenceBadge.Detailed(confidence: 0.92)
        ConfidenceBadge.Detailed(confidence: 0.68)
        ConfidenceBadge.Detailed(confidence: 0.35)
    }
    .padding()
    .frame(width: 300)
}
