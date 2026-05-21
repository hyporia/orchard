import Foundation
import OSLog

enum ContainerCLIError: Error, LocalizedError {
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

protocol ContainerCLIProtocol: Sendable {
    func run(arguments: [String]) async throws -> String
    func streamLogs(containerId: String) -> AsyncThrowingStream<String, Error>
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

/// Typed gateway to the `container` CLI: resolves the binary and invokes it as a
/// subprocess, returning output one-shot (`run`) or streamed (`streamLogs`).
///
/// Discovery can shell out to `zsh -lc 'which container'`, so the resolved path is
/// cached for the lifetime of the instance. The env-var test override is evaluated
/// on every call and is never cached, so it stays authoritative across uses.
final class ContainerCLI: ContainerCLIProtocol, @unchecked Sendable {
    static let shared = ContainerCLI()

    private let lock = NSLock()
    private var cachedExecutableURL: URL?

    init() {}

    private func makeProcess(arguments: [String]) throws -> Process {
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
        Logger.cli.debug("container \(arguments.first ?? "", privacy: .public) (\(arguments.count - 1) args)")
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
                            Logger.cli.error(
                                "container \(arguments.first ?? "", privacy: .public) failed (exit \(process.terminationStatus)): \(errorMsg.trimmingCharacters(in: .whitespacesAndNewlines), privacy: .public)"
                            )
                            continuation.resume(
                                throwing: ContainerCLIError.processFailed(errorMsg))
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

    func streamLogs(containerId: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream<String, Error> { continuation in
            Logger.cli.debug("Starting log stream for container \(containerId, privacy: .public)")
            let process: Process
            do {
                process = try self.makeProcess(arguments: ["logs", "-f", containerId])
            } catch {
                Logger.cli.error(
                    "Failed to start log stream for \(containerId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                continuation.finish(throwing: error)
                return
            }

            let state = CommandState()

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    Logger.cli.debug("Log stream EOF for container \(containerId, privacy: .public)")
                    handle.readabilityHandler = nil
                    continuation.finish()
                    return
                }
                if let chunk = String(data: data, encoding: .utf8) {
                    continuation.yield(chunk)
                }
            }

            // Safety net: fires if the process dies without an EOF callback.
            process.terminationHandler = { _ in
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.finish()
            }

            // Consumer cancellation (or natural finish) tears the process down.
            continuation.onTermination = { @Sendable _ in state.cancel() }

            // Attach before run() so a cancel arriving during launch still
            // terminates the process (mirrors run(arguments:) ordering).
            state.attach(process)
            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.finish(throwing: error)
                return
            }
        }
    }

    private func resolveExecutableURL() throws -> URL {
        let env = ProcessInfo.processInfo.environment

        // Test override: evaluated every call, never cached.
        if let overridePath = env["ORCHARD_CONTAINER_PATH"], !overridePath.isEmpty,
            FileManager.default.isExecutableFile(atPath: overridePath)
        {
            Logger.cli.debug("Using ORCHARD_CONTAINER_PATH override: \(overridePath, privacy: .public)")
            return URL(fileURLWithPath: overridePath)
        }

        lock.lock()
        if let cached = cachedExecutableURL {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let discovered = Self.discoverExecutablePath(environment: env) else {
            throw ContainerCLIError.executableNotFound
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
            Logger.cli.info("Container executable discovered at \(path, privacy: .public)")
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
                    Logger.cli.info("Container executable found via 'which container': \(path, privacy: .public)")
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {
            // Ignore — treated as "not found".
        }

        Logger.cli.error("Container executable not found in any known location")
        return nil
    }
}
