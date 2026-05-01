import Foundation

actor MCPProcessManager {
    private var process: Process?
    private var isRunning = false
    private let nodePath: String
    private let serverPath: String
    
    init(nodePath: String, serverPath: String) {
        self.nodePath = nodePath
        self.serverPath = serverPath
    }
    
    func start() async throws -> (inputPipe: Pipe, outputPipe: Pipe) {
        guard !isRunning else {
            throw MCPError.processSpawnFailed("Process already running")
        }
        
        guard FileManager.default.fileExists(atPath: nodePath) else {
            throw MCPError.processSpawnFailed("Node.js binary not found at \(nodePath)")
        }
        
        guard FileManager.default.fileExists(atPath: serverPath) else {
            throw MCPError.processSpawnFailed("MCP server not found at \(serverPath)")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [serverPath]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        process.terminationHandler = { [weak self] process in
            Task {
                await self?.handleTermination(exitCode: process.terminationStatus)
            }
        }
        
        Task {
            for try await line in errorPipe.fileHandleForReading.bytes.lines {
                print("[MCP Server Error] \(line)")
            }
        }
        
        do {
            try process.run()
            self.process = process
            self.isRunning = true
            
            try await Task.sleep(nanoseconds: 500_000_000)
            
            guard process.isRunning else {
                throw MCPError.processSpawnFailed("Process terminated immediately")
            }
            
            return (inputPipe, outputPipe)
        } catch {
            throw MCPError.processSpawnFailed(error.localizedDescription)
        }
    }
    
    func stop() async {
        guard let process = process, isRunning else { return }
        
        process.terminate()
        
        let deadline = Date().addingTimeInterval(5.0)
        while process.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if process.isRunning {
            process.interrupt()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        
        self.process = nil
        self.isRunning = false
    }
    
    func isProcessRunning() -> Bool {
        return isRunning && process?.isRunning == true
    }
    
    private func handleTermination(exitCode: Int32) {
        isRunning = false
        if exitCode != 0 {
            print("[MCP Process] Terminated with exit code \(exitCode)")
        }
    }
}
