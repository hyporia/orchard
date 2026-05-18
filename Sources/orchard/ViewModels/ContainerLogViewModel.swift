import Foundation

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
                self.appendLog("\nError starting process: \(error.localizedDescription)\n")
            }
        }
    }

    private func appendLog(_ string: String) {
        logs.append(string)
        if logs.count > 50000 {
            logs = String(logs.suffix(40000))
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
    }
}
