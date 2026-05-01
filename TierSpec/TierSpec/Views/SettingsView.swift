import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var defaultModel: String = "gpt-4o-mini"
    @State private var maxRequestsPerDay: Int = 100
    @State private var isLoading = false
    @State private var saveMessage: String?
    @State private var showApiKey = false
    
    private let configManager = ConfigManager()
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(.title)
                .padding()
            
            Form {
                Section("OpenAI Configuration") {
                    HStack {
                        if showApiKey {
                            TextField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button(action: { showApiKey.toggle() }) {
                            Image(systemName: showApiKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    Text("Get your API key from platform.openai.com")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Picker("Default Model", selection: $defaultModel) {
                        Text("GPT-4o Mini (Recommended)").tag("gpt-4o-mini")
                        Text("GPT-4o").tag("gpt-4o")
                        Text("GPT-4 Turbo").tag("gpt-4-turbo")
                    }
                    
                    Stepper("Max Requests/Day: \(maxRequestsPerDay)", value: $maxRequestsPerDay, in: 10...1000, step: 10)
                    
                    Text("Limit AI requests to control costs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("MCP Server", value: "Bundled")
                    LabeledContent("Node.js", value: "Bundled")
                }
            }
            .formStyle(.grouped)
            
            if let message = saveMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(message.contains("Error") ? .red : .green)
                    .padding(.horizontal)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await saveSettings()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isLoading)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .task {
            await loadSettings()
        }
    }
    
    private func loadSettings() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let config = try await configManager.loadConfig()
            apiKey = config.openaiApiKey ?? ""
            defaultModel = config.defaultModel ?? "gpt-4o-mini"
            maxRequestsPerDay = config.maxRequestsPerDay ?? 100
        } catch {
            saveMessage = "Error loading settings: \(error.localizedDescription)"
        }
    }
    
    private func saveSettings() async {
        isLoading = true
        saveMessage = nil
        
        do {
            var config = ConfigManager.Config()
            config.openaiApiKey = apiKey.isEmpty ? nil : apiKey
            config.defaultModel = defaultModel
            config.maxRequestsPerDay = maxRequestsPerDay
            
            try await configManager.saveConfig(config)
            saveMessage = "Settings saved successfully"
            
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            saveMessage = "Error saving settings: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

#Preview {
    SettingsView()
}
