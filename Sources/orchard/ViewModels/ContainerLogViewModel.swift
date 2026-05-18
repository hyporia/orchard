import Foundation

@MainActor
@Observable
class ContainerLogViewModel {
    var logs: String = ""
    private var process: Process?
    private var logPipe: Pipe?
    let containerId: String
    let containerName: String?
    private let processService: ContainerProcessServiceProtocol

    init(
        containerId: String,
        containerName: String? = nil,
        processService: ContainerProcessServiceProtocol = ContainerProcessService.shared
    ) {
        self.containerId = containerId
        self.containerName = containerName
        self.processService = processService
    }

    func startStreaming() {
        let displayName = containerName ?? containerId
        logs = "Starting log stream for \(displayName)...\n"

        let newProcess: Process
        do {
            newProcess = try processService.makeProcess(arguments: ["logs", "-f", containerId])
        } catch {
            logs.append("\nError starting process: \(error.localizedDescription)\n")
            return
        }

        process = newProcess

        logPipe = Pipe()
        process?.standardOutput = logPipe
        process?.standardError = logPipe

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
