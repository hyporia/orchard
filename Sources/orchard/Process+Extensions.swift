import Foundation

enum ContainerProcessError: Error, LocalizedError {
    case executableNotFound
    
    var errorDescription: String? {
        switch self {
        case .executableNotFound: return "Could not find the 'container' executable. Please ensure it is installed and in your PATH."
        }
    }
}

extension Process {
    static func findExecutablePath() -> URL? {
        // Test overrides (no-op in production unless env vars are set)
        let env = ProcessInfo.processInfo.environment
        if env["ORCHARD_FORCE_NO_CONTAINER"] == "1" {
            return nil
        }
        if let overridePath = env["ORCHARD_CONTAINER_PATH"], !overridePath.isEmpty {
            if FileManager.default.isExecutableFile(atPath: overridePath) {
                return URL(fileURLWithPath: overridePath)
            }
        }
        
        let commonPaths = [
            "/opt/homebrew/bin/container",
            "/usr/local/bin/container",
            "/usr/bin/container",
            "\(NSHomeDirectory())/.rd/bin/container",
            "\(NSHomeDirectory())/.orbstack/bin/container",
            "\(NSHomeDirectory())/.local/bin/container"
        ]
        
        var searchPaths = commonPaths
        
        // Also check PATH environment variable
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let paths = pathEnv.components(separatedBy: ":")
            for path in paths {
                let url = URL(fileURLWithPath: path).appendingPathComponent("container")
                if !searchPaths.contains(url.path) {
                    searchPaths.append(url.path)
                }
            }
        }
        
        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        // As a fallback, try using 'which' command dynamically
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
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {
            // Ignore
        }
        
        return nil
    }

    static func containerProcess(arguments: [String]) throws -> Process {
        guard let executableURL = findExecutablePath() else {
            throw ContainerProcessError.executableNotFound
        }
        
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        
        // Pass standard environment but make sure typical paths are there
        var env = ProcessInfo.processInfo.environment
        if env["PATH"] == nil {
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        } else {
            env["PATH"] = "\(env["PATH"] ?? ""):/opt/homebrew/bin:/usr/local/bin"
        }
        process.environment = env
        
        return process
    }
}

