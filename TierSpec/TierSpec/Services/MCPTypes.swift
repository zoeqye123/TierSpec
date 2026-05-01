import Foundation

enum MCPError: Error, LocalizedError {
    case processSpawnFailed(String)
    case processTerminated(Int32)
    case communicationFailed(String)
    case invalidResponse(String)
    case timeout
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .processSpawnFailed(let reason):
            return "Failed to spawn MCP server: \(reason)"
        case .processTerminated(let code):
            return "MCP server terminated with code \(code)"
        case .communicationFailed(let reason):
            return "Communication failed: \(reason)"
        case .invalidResponse(let reason):
            return "Invalid response: \(reason)"
        case .timeout:
            return "Request timed out"
        case .notConnected:
            return "MCP server not connected"
        }
    }
}

struct MCPRequest: Codable {
    let jsonrpc: String = "2.0"
    let id: String
    let method: String
    let params: [String: AnyCodable]?
    
    init(id: String, method: String, params: [String: AnyCodable]? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

struct MCPResponse: Codable {
    let jsonrpc: String
    let id: String
    let result: AnyCodable?
    let error: MCPErrorResponse?
}

struct MCPErrorResponse: Codable {
    let code: Int
    let message: String
    let data: AnyCodable?
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Cannot encode value of type \(type(of: value))"
                )
            )
        }
    }
}
