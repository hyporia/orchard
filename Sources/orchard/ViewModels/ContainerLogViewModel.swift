import Foundation
import OSLog

@MainActor
@Observable
class ContainerLogViewModel {
    var logs: String = ""
    let containerId: String
    let containerName: String?
    private let service: ContainerServiceProtocol
    private(set) var streamTask: Task<Void, Never>?

    init(
        containerId: String,
        containerName: String? = nil,
        service: ContainerServiceProtocol = ContainerService()
    ) {
        self.containerId = containerId
        self.containerName = containerName
        self.service = service
    }

    func startStreaming() {
        let displayName = containerName ?? containerId
        Logger.logs.info("Starting log stream for container \(self.containerId, privacy: .public)")
        logs = "Starting log stream for \(displayName)...\n"

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await chunk in self.service.streamLogs(
                    containerId: self.containerId)
                {
                    self.appendLog(chunk)
                }
            } catch {
                Logger.logs.error("Log stream error for container \(self.containerId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                self.appendLog("\nError starting process: \(error.localizedDescription)\n")
            }
        }
    }

    private var approxLength = 0
    private static let maxLength = 50_000
    private static let keepLength = 40_000

    private func appendLog(_ string: String) {
        logs.append(string)
        approxLength += string.utf16.count
        if approxLength > Self.maxLength {
            logs = String(logs.suffix(Self.keepLength))
            approxLength = logs.utf16.count
        }
    }

    func stopStreaming() {
        Logger.logs.debug("Stopping log stream for container \(self.containerId, privacy: .public)")
        streamTask?.cancel()
        streamTask = nil
    }
}
