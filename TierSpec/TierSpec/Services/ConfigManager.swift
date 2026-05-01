import Foundation

actor ConfigManager {
    private let configURL: URL
    private var config: Config?
    
    struct Config: Codable {
        var openaiApiKey: String?
        var defaultModel: String?
        var maxRequestsPerDay: Int?
        
        init() {
            self.openaiApiKey = nil
            self.defaultModel = "gpt-4o-mini"
            self.maxRequestsPerDay = 100
        }
    }
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let tierspecDir = homeDir.appendingPathComponent(".tierspec")
        self.configURL = tierspecDir.appendingPathComponent("config.json")
        
        try? FileManager.default.createDirectory(at: tierspecDir, withIntermediateDirectories: true)
    }
    
    func loadConfig() async throws -> Config {
        if let cached = config {
            return cached
        }
        
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            let newConfig = Config()
            self.config = newConfig
            return newConfig
        }
        
        let data = try Data(contentsOf: configURL)
        let decoder = JSONDecoder()
        let loadedConfig = try decoder.decode(Config.self, from: data)
        self.config = loadedConfig
        return loadedConfig
    }
    
    func saveConfig(_ config: Config) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
        self.config = config
    }
    
    func getApiKey() async -> String? {
        do {
            let config = try await loadConfig()
            return config.openaiApiKey
        } catch {
            return nil
        }
    }
    
    func setApiKey(_ key: String?) async throws {
        var config = try await loadConfig()
        config.openaiApiKey = key
        try await saveConfig(config)
    }
    
    func getDefaultModel() async -> String {
        do {
            let config = try await loadConfig()
            return config.defaultModel ?? "gpt-4o-mini"
        } catch {
            return "gpt-4o-mini"
        }
    }
    
    func setDefaultModel(_ model: String) async throws {
        var config = try await loadConfig()
        config.defaultModel = model
        try await saveConfig(config)
    }
}
