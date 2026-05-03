import Foundation
import Combine

@MainActor
class MCPClientManager: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var connectionError: String?
    
    private let processManager: MCPProcessManager
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var pendingRequests: [String: CheckedContinuation<MCPResponse, Error>] = [:]
    private var requestCounter = 0
    
    init() {
        let bundle = Bundle.main
        let nodePath = bundle.path(forResource: "node", ofType: nil, inDirectory: "MacOS") ?? "/opt/homebrew/bin/node"
        let serverPath = bundle.path(forResource: "dist/index.js", ofType: nil, inDirectory: "MacOS/tierspec-mcp-server") ?? ""
        
        self.processManager = MCPProcessManager(nodePath: nodePath, serverPath: serverPath)
    }
    
    func connect() async throws {
        guard !isConnected else { return }
        
        do {
            let (input, output) = try await processManager.start()
            self.inputPipe = input
            self.outputPipe = output
            
            startReadingResponses(from: output)
            
            self.isConnected = true
            self.connectionError = nil
        } catch {
            self.connectionError = error.localizedDescription
            throw error
        }
    }
    
    func disconnect() async {
        guard isConnected else { return }
        
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: MCPError.notConnected)
        }
        pendingRequests.removeAll()
        
        await processManager.stop()
        
        inputPipe = nil
        outputPipe = nil
        isConnected = false
    }
    
    func callTool(name: String, arguments: [String: Any] = [:]) async throws -> [String: Any] {
        guard isConnected else {
            throw MCPError.notConnected
        }
        
        let requestId = generateRequestId()
        let params = arguments.mapValues { AnyCodable($0) }
        
        let request = MCPRequest(
            id: requestId,
            method: "tools/call",
            params: [
                "name": AnyCodable(name),
                "arguments": AnyCodable(params)
            ]
        )
        
        let response = try await sendRequest(request)
        
        if let error = response.error {
            throw MCPError.communicationFailed("Tool call failed: \(error.message)")
        }
        
        guard let result = response.result?.value as? [String: Any] else {
            throw MCPError.invalidResponse("Invalid tool response")
        }
        
        return result
    }
    
    private func sendRequest(_ request: MCPRequest) async throws -> MCPResponse {
        guard let inputPipe = inputPipe else {
            throw MCPError.notConnected
        }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        
        var jsonString = String(data: data, encoding: .utf8) ?? ""
        jsonString += "\n"
        
        guard let requestData = jsonString.data(using: .utf8) else {
            throw MCPError.communicationFailed("Failed to encode request")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[request.id] = continuation
            
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                
                if let pending = await MainActor.run(body: { pendingRequests.removeValue(forKey: request.id) }) {
                    pending.resume(throwing: MCPError.timeout)
                }
            }
            
            do {
                try inputPipe.fileHandleForWriting.write(contentsOf: requestData)
            } catch {
                pendingRequests.removeValue(forKey: request.id)
                continuation.resume(throwing: MCPError.communicationFailed(error.localizedDescription))
            }
        }
    }
    
    private func startReadingResponses(from pipe: Pipe) {
        Task {
            let handle = pipe.fileHandleForReading
            
            for try await line in handle.bytes.lines {
                guard !line.isEmpty else { continue }
                
                do {
                    let data = Data(line.utf8)
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(MCPResponse.self, from: data)
                    
                    await handleResponse(response)
                } catch {
                    print("[MCP Client] Failed to decode response: \(error)")
                }
            }
        }
    }
    
    private func handleResponse(_ response: MCPResponse) async {
        guard let continuation = pendingRequests.removeValue(forKey: response.id) else {
            print("[MCP Client] Received response for unknown request: \(response.id)")
            return
        }
        
        continuation.resume(returning: response)
    }
    
    private func generateRequestId() -> String {
        requestCounter += 1
        return "req-\(requestCounter)-\(UUID().uuidString.prefix(8))"
    }
}
