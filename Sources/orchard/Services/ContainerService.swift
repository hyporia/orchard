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
    func pullImage(reference: String) async throws

    // Volumes
    func fetchVolumes() async throws -> [VolumeItem]
    func deleteVolume(name: String) async throws

    // Container lifecycle
    func runContainer(image: String, name: String?, options: RunContainerOptions) async throws
}

struct RunContainerOptions {
    var memory: String = ""  // e.g. "512M", "1G"
    var cpus: String = ""  // e.g. "2"
    var ports: [String] = []  // e.g. ["8080:80"]
    var envVars: [String] = []  // e.g. ["FOO=bar"]
    var volumes: [String] = []  // e.g. ["/host:/container"]
    var removeOnStop: Bool = false
    var entrypoint: String = ""
}

enum ContainerServiceError: Error, LocalizedError {
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .decodingFailed: return "Failed to decode CLI response"
        }
    }
}

struct CLIContainerService: ContainerServiceProtocol {
    private let processService: ContainerProcessServiceProtocol

    init(processService: ContainerProcessServiceProtocol = ContainerProcessService.shared) {
        self.processService = processService
    }

    private func runCommand(arguments: [String]) async throws -> String {
        try await processService.run(arguments: arguments)
    }

    func fetchContainers() async throws -> [ContainerItem] {
        let output = try await runCommand(arguments: ["ls", "-a", "--format", "json"])
        guard let data = output.data(using: .utf8) else {
            throw ContainerServiceError.decodingFailed
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode([ContainerItem].self, from: data)
        } catch {
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

    func runContainer(image: String, name: String?, options: RunContainerOptions) async throws {
        var args = ["run", "-d"]
        if let name = name, !name.isEmpty {
            args += ["--name", name]
        }
        if !options.memory.isEmpty {
            args += ["--memory", options.memory]
        }
        if !options.cpus.isEmpty {
            args += ["--cpus", options.cpus]
        }
        for port in options.ports where !port.isEmpty {
            args += ["--publish", port]
        }
        for env in options.envVars where !env.isEmpty {
            args += ["--env", env]
        }
        for vol in options.volumes where !vol.isEmpty {
            args += ["--volume", vol]
        }
        if options.removeOnStop {
            args.append("--rm")
        }
        if !options.entrypoint.isEmpty {
            args += ["--entrypoint", options.entrypoint]
        }
        args.append(image)
        _ = try await runCommand(arguments: args)
    }

    func getSystemStatus() async throws -> SystemStatus {
        do {
            let output = try await runCommand(arguments: ["system", "status", "--format", "json"])
            guard let data = output.data(using: .utf8) else {
                throw ContainerServiceError.decodingFailed
            }
            return try JSONDecoder().decode(SystemStatus.self, from: data)
        } catch {
            return SystemStatus(status: "stopped", apiServerVersion: nil)
        }
    }

    func getSystemDiskUsage() async throws -> SystemDiskUsage {
        let output = try await runCommand(arguments: ["system", "df", "--format", "json"])
        guard let data = output.data(using: .utf8) else {
            throw ContainerServiceError.decodingFailed
        }
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

    func fetchImages() async throws -> [ImageItem] {
        let output = try await runCommand(arguments: ["image", "ls", "--format", "json"])
        guard let data = output.data(using: .utf8) else { return [] }
        return try JSONDecoder().decode([ImageItem].self, from: data)
    }

    func deleteImage(reference: String) async throws {
        _ = try await runCommand(arguments: ["image", "rm", reference])
    }

    func pullImage(reference: String) async throws {
        _ = try await runCommand(arguments: ["image", "pull", reference])
    }

    func fetchVolumes() async throws -> [VolumeItem] {
        let output = try await runCommand(arguments: ["volume", "ls", "--format", "json"])
        guard let data = output.data(using: .utf8) else { return [] }
        var volumes = try JSONDecoder().decode([VolumeItem].self, from: data)

        for i in volumes.indices {
            if let source = volumes[i].source {
                let url = URL(fileURLWithPath: source)
                if let resourceValues = try? url.resourceValues(forKeys: [
                    .totalFileAllocatedSizeKey
                ]),
                    let allocatedSize = resourceValues.totalFileAllocatedSize
                {
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
    func fetchContainers() async throws -> [ContainerItem] { [] }
    func fetchStats() async throws -> [ContainerStat] { [] }
    func startContainer(id: String) async throws {}
    func stopContainer(id: String) async throws {}
    func deleteContainer(id: String) async throws {}
    func runContainer(image: String, name: String?, options: RunContainerOptions) async throws {}

    func getSystemStatus() async throws -> SystemStatus {
        SystemStatus(status: "running", apiServerVersion: "mock")
    }
    func getSystemDiskUsage() async throws -> SystemDiskUsage {
        let stat = SystemDiskUsage.UsageStat(active: 1, reclaimable: 1, sizeInBytes: 1, total: 1)
        return SystemDiskUsage(containers: stat, images: stat, volumes: stat)
    }
    func getCliVersion() async throws -> String { "mock" }
    func startSystem() async throws {}
    func stopSystem() async throws {}

    func fetchImages() async throws -> [ImageItem] { [] }
    func deleteImage(reference: String) async throws {}
    func pullImage(reference: String) async throws {}

    func fetchVolumes() async throws -> [VolumeItem] { [] }
    func deleteVolume(name: String) async throws {}
}
