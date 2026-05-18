import Foundation

enum ContainerProcessError: Error, LocalizedError {
    case executableNotFound
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return
                "Could not find the 'container' executable. Please ensure it is installed and in your PATH."
        case .processFailed(let msg):
            return "Container process failed: \(msg)"
        }
    }
}

protocol ContainerProcessServiceProtocol: Sendable {
    func makeProcess(arguments: [String]) throws -> Process
    func run(arguments: [String]) async throws -> String
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}

private final class CommandState: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var resumed = false

    func attach(_ process: Process) {
        lock.lock()
        self.process = process
        let alreadyCancelled = cancelled
        lock.unlock()
        if alreadyCancelled { process.terminate() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let process = self.process
        lock.unlock()
        process?.terminate()
    }

    func claimCompletion() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if resumed { return false }
        resumed = true
        return true
    }
}

/// Resolves the `container` CLI binary and builds configured `Process` instances.
///
/// Discovery can shell out to `zsh -lc 'which container'`, so the resolved path is
/// cached for the lifetime of the service. The env-var test override is evaluated
/// on every call and is never cached, so it stays authoritative across uses.
final class ContainerProcessService: ContainerProcessServiceProtocol, @unchecked Sendable {
    static let shared = ContainerProcessService()

    private let lock = NSLock()
    private var cachedExecutableURL: URL?

    init() {}

    func makeProcess(arguments: [String]) throws -> Process {
        let executableURL = try resolveExecutableURL()

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        // Pass standard environment but make sure typical paths are there.
        var env = ProcessInfo.processInfo.environment
        if env["PATH"] == nil {
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        } else {
            env["PATH"] = "\(env["PATH"] ?? ""):/opt/homebrew/bin:/usr/local/bin"
        }
        process.environment = env

        return process
    }

    func run(arguments: [String]) async throws -> String {
        let state = CommandState()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<String, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let process: Process = try self.makeProcess(arguments: arguments)
                        state.attach(process)

                        let stdoutPipe = Pipe()
                        let stderrPipe = Pipe()
                        process.standardOutput = stdoutPipe
                        process.standardError = stderrPipe

                        try process.run()

                        let stdoutBox = DataBox()
                        let stderrBox = DataBox()
                        let ioQueue = DispatchQueue(
                            label: "orchard.process.io", attributes: .concurrent)
                        let ioGroup = DispatchGroup()

                        ioGroup.enter()
                        ioQueue.async {
                            stdoutBox.data =
                                stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                            ioGroup.leave()
                        }
                        ioGroup.enter()
                        ioQueue.async {
                            stderrBox.data =
                                stderrPipe.fileHandleForReading.readDataToEndOfFile()
                            ioGroup.leave()
                        }

                        process.waitUntilExit()
                        ioGroup.wait()

                        guard state.claimCompletion() else { return }

                        let stdoutData = stdoutBox.data
                        let stderrData = stderrBox.data

                        if process.terminationStatus != 0 {
                            let errorMsg =
                                String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                            continuation.resume(
                                throwing: ContainerProcessError.processFailed(errorMsg))
                            return
                        }

                        let output = String(data: stdoutData, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    } catch {
                        guard state.claimCompletion() else { return }
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            state.cancel()
        }
    }

    private func resolveExecutableURL() throws -> URL {
        let env = ProcessInfo.processInfo.environment

        // Test override: evaluated every call, never cached.
        if let overridePath = env["ORCHARD_CONTAINER_PATH"], !overridePath.isEmpty,
            FileManager.default.isExecutableFile(atPath: overridePath)
        {
            return URL(fileURLWithPath: overridePath)
        }

        lock.lock()
        if let cached = cachedExecutableURL {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let discovered = Self.discoverExecutablePath(environment: env) else {
            throw ContainerProcessError.executableNotFound
        }

        lock.lock()
        cachedExecutableURL = discovered
        lock.unlock()

        return discovered
    }

    private static func discoverExecutablePath(environment: [String: String]) -> URL? {
        let commonPaths = [
            "/opt/homebrew/bin/container",
            "/usr/local/bin/container",
            "/usr/bin/container",
            "\(NSHomeDirectory())/.rd/bin/container",
            "\(NSHomeDirectory())/.orbstack/bin/container",
            "\(NSHomeDirectory())/.local/bin/container",
        ]

        var searchPaths = commonPaths

        // Also check PATH environment variable.
        if let pathEnv = environment["PATH"] {
            for path in pathEnv.components(separatedBy: ":") {
                let candidate = URL(fileURLWithPath: path).appendingPathComponent("container")
                if !searchPaths.contains(candidate.path) {
                    searchPaths.append(candidate.path)
                }
            }
        }

        for path in searchPaths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        // As a fallback, try using 'which' command dynamically.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["zsh", "-lc", "which container"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !path.isEmpty,
                    FileManager.default.isExecutableFile(atPath: path)
                {
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {
            // Ignore — treated as "not found".
        }

        return nil
    }
}
