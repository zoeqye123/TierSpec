//
//  AIInputBar.swift
//  TierSpec
//
//  Created by Sisyphus on 2026/5/2.
//

import SwiftUI

/// Natural language input bar for AI-powered requirement parsing
/// Supports ⌘K keyboard shortcut for focus
struct AIInputBar: View {
    // MARK: - Bindings
    
    @Binding var text: String
    @Binding var isProcessing: Bool
    @FocusState.Binding var isFocused: Bool
    
    // MARK: - Callbacks
    
    let onSubmit: () async -> Void
    
    // MARK: - State
    
    @State private var mode: AIMode = .parseRequirement
    
    // MARK: - Modes
    
    enum AIMode: String, CaseIterable {
        case parseRequirement = "Parse"
        case estimateComplexity = "Estimate"
        case detectDependencies = "Detect"
        
        var icon: String {
            switch self {
            case .parseRequirement: return "doc.text.magnifyingglass"
            case .estimateComplexity: return "chart.bar"
            case .detectDependencies: return "arrow.triangle.2.circlepath"
            }
        }
        
        var placeholder: String {
            switch self {
            case .parseRequirement: return "Describe a requirement..."
            case .estimateComplexity: return "Describe a user story..."
            case .detectDependencies: return "Describe a user story..."
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Mode picker
            Picker("Mode", selection: $mode) {
                ForEach(AIMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            
            Divider()
                .frame(height: 20)
            
            // Text field
            TextField(mode.placeholder, text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit {
                    Task {
                        await submit()
                    }
                }
            
            // Keyboard shortcut hint
            Text("⌘K")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            Divider()
                .frame(height: 20)
            
            // Submit button
            Button(action: {
                Task {
                    await submit()
                }
            }) {
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.body)
                }
            }
            .buttonStyle(.borderless)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            .help("Submit (Enter)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
    
    // MARK: - Actions
    
    private func submit() async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await onSubmit()
    }
}

// MARK: - Previews

#Preview("AIInputBar - Empty") {
    struct PreviewWrapper: View {
        @State var text = ""
        @State var isProcessing = false
        @FocusState var isFocused: Bool
        
        var body: some View {
            VStack {
                AIInputBar(
                    text: $text,
                    isProcessing: $isProcessing,
                    isFocused: $isFocused
                ) {
                    print("Submit: \(text)")
                }
                Spacer()
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}

#Preview("AIInputBar - With Text") {
    struct PreviewWrapper: View {
        @State var text = "As a user, I want to login with my Google account"
        @State var isProcessing = false
        @FocusState var isFocused: Bool
        
        var body: some View {
            VStack {
                AIInputBar(
                    text: $text,
                    isProcessing: $isProcessing,
                    isFocused: $isFocused
                ) {
                    print("Submit: \(text)")
                }
                Spacer()
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}

#Preview("AIInputBar - Processing") {
    struct PreviewWrapper: View {
        @State var text = "As a user, I want to login with my Google account"
        @State var isProcessing = true
        @FocusState var isFocused: Bool
        
        var body: some View {
            VStack {
                AIInputBar(
                    text: $text,
                    isProcessing: $isProcessing,
                    isFocused: $isFocused
                ) {
                    print("Submit: \(text)")
                }
                Spacer()
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
