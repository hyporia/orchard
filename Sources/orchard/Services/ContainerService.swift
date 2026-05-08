import Foundation

protocol ContainerServiceProtocol: Sendable {
    func fetchContainers() async throws -> [ContainerItem]
    func fetchStats() async throws -> [ContainerStat]
    func startContainer(id: String) async throws
    func stopContainer(id: String) async throws
    func deleteContainer(id: String) async throws
    
    // System methods
    func getSystemStatus() async throws -> SystemStatus
    func getSystemDiskUsage() async throws -> SystemDiskUsage
    func getCliVersion() async throws -> String
    func startSystem() async throws
    func stopSystem() async throws
    
    // Images
    func fetchImages() async throws -> [ImageItem]
    func deleteImage(reference: String) async throws
    
    // Volumes
    func fetchVolumes() async throws -> [VolumeItem]
    func deleteVolume(name: String) async throws
}

enum ContainerServiceError: Error, LocalizedError {
    case processFailed(String)
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .processFailed(let msg): return "Container process failed: \(msg)"
        case .decodingFailed: return "Failed to decode CLI response"
        }
    }
}

struct CLIContainerService: ContainerServiceProtocol {
    private func runCommand(arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = ["container"] + arguments
                    
                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if process.terminationStatus != 0 {
                        let errorMsg = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: ContainerServiceError.processFailed(errorMsg))
                        return
                    }
                    
                    let output = String(data: stdoutData, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchContainers() async throws -> [ContainerItem] {
        let output = try await runCommand(arguments: ["ls", "-a", "--format", "json"])
        guard let data = output.data(using: .utf8) else {
            throw ContainerServiceError.decodingFailed
        }
        
        let decoder = JSONDecoder()
        // Try decoding as a JSON array first
        do {
            return try decoder.decode([ContainerItem].self, from: data)
        } catch {
            // Fallback: some CLI versions emit one JSON object per line
            let lines = output.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var items: [ContainerItem] = []
            for line in lines {
                guard let lineData = line.data(using: .utf8) else { continue }
                items.append(try decoder.decode(ContainerItem.self, from: lineData))
            }
            return items
        }
    }

    func fetchStats() async throws -> [ContainerStat] {
        let output = try await runCommand(arguments: ["stats", "--no-stream", "--format", "json"])
        guard let data = output.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([ContainerStat].self, from: data)
    }

    func startContainer(id: String) async throws {
        _ = try await runCommand(arguments: ["start", id])
    }

    func stopContainer(id: String) async throws {
        _ = try await runCommand(arguments: ["stop", id])
    }

    func deleteContainer(id: String) async throws {
        _ = try await runCommand(arguments: ["rm", id])
    }

    func getSystemStatus() async throws -> SystemStatus {
        do {
            let output = try await runCommand(arguments: ["system", "status", "--format", "json"])
            guard let data = output.data(using: .utf8) else { throw ContainerServiceError.decodingFailed }
            return try JSONDecoder().decode(SystemStatus.self, from: data)
        } catch {
            // If it fails, the daemon might not be running. Return a stopped status
            return SystemStatus(status: "stopped", apiServerVersion: nil)
        }
    }

    func getSystemDiskUsage() async throws -> SystemDiskUsage {
        let output = try await runCommand(arguments: ["system", "df", "--format", "json"])
        guard let data = output.data(using: .utf8) else { throw ContainerServiceError.decodingFailed }
        return try JSONDecoder().decode(SystemDiskUsage.self, from: data)
    }

    func getCliVersion() async throws -> String {
        let output = try await runCommand(arguments: ["--version"])
        return output.trimmingCharacters(in: .newlines)
    }

    func startSystem() async throws {
        _ = try await runCommand(arguments: ["system", "start"])
    }
    
    func stopSystem() async throws {
        _ = try await runCommand(arguments: ["system", "stop"])
    }
    
    // Images
    func fetchImages() async throws -> [ImageItem] {
        let output = try await runCommand(arguments: ["image", "ls", "--format", "json"])
        guard let data = output.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([ImageItem].self, from: data)
    }
    func deleteImage(reference: String) async throws {
        _ = try await runCommand(arguments: ["image", "rm", reference])
    }
    
    // Volumes
    func fetchVolumes() async throws -> [VolumeItem] {
        let output = try await runCommand(arguments: ["volume", "ls", "--format", "json"])
        guard let data = output.data(using: .utf8) else { return [] }
        var volumes = try JSONDecoder().decode([VolumeItem].self, from: data)
        
        // Compute actual on-disk size for sparse volume images
        for i in volumes.indices {
            if let source = volumes[i].source {
                let url = URL(fileURLWithPath: source)
                if let resourceValues = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
                   let allocatedSize = resourceValues.totalFileAllocatedSize {
                    volumes[i].actualSizeInBytes = Int64(allocatedSize)
                }
            }
        }
        
        return volumes
    }
    func deleteVolume(name: String) async throws {
        _ = try await runCommand(arguments: ["volume", "rm", name])
    }
}

struct MockContainerService: ContainerServiceProtocol {
    func fetchContainers() async throws -> [ContainerItem] { return [] }
    func fetchStats() async throws -> [ContainerStat] { return [] }
    func startContainer(id: String) async throws {}
    func stopContainer(id: String) async throws {}
    func deleteContainer(id: String) async throws {}
    
    func getSystemStatus() async throws -> SystemStatus { return SystemStatus(status: "running", apiServerVersion: "mock") }
    func getSystemDiskUsage() async throws -> SystemDiskUsage { 
        let stat = SystemDiskUsage.UsageStat(active: 1, reclaimable: 1, sizeInBytes: 1, total: 1)
        return SystemDiskUsage(containers: stat, images: stat, volumes: stat) 
    }
    func getCliVersion() async throws -> String { return "mock" }
    func startSystem() async throws {}
    func stopSystem() async throws {}
    
    func fetchImages() async throws -> [ImageItem] { return [] }
    func deleteImage(reference: String) async throws {}
    
    func fetchVolumes() async throws -> [VolumeItem] { return [] }
    func deleteVolume(name: String) async throws {}
}
