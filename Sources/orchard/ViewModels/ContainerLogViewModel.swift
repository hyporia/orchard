import Foundation

@MainActor
@Observable
class ContainerLogViewModel {
    var logs: String = ""
    private var process: Process?
    private var logPipe: Pipe?
    let containerId: String

    init(containerId: String) {
        self.containerId = containerId
    }

    func startStreaming() {
        logs = "Starting log stream for \(containerId)...\n"
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process?.arguments = ["container", "logs", "-f", containerId]

        logPipe = Pipe()
        process?.standardOutput = logPipe
        process?.standardError = logPipe // Merge stdout and stderr

        logPipe?.fileHandleForReading.readabilityHandler = { @Sendable [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            if let string = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.appendLog(string)
                }
            }
        }

        do {
            try process?.run()
        } catch {
            logs.append("\nError starting process: \(error.localizedDescription)\n")
        }
    }

    private func appendLog(_ string: String) {
        logs.append(string)
        // Keep memory footprint small by truncating if too large
        if logs.count > 50000 {
            logs = String(logs.suffix(40000))
        }
    }

    func stopStreaming() {
        logPipe?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        logPipe = nil
    }
}
