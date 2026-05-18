import Foundation

@MainActor
@Observable
class SystemViewModel {
    var systemInfo: SystemInfo?
    var isLoading: Bool = false
    var errorMessage: String?

    private let service: ContainerServiceProtocol
    private var pollingTask: Task<Void, Never>?

    init(service: ContainerServiceProtocol = ContainerService()) {
        self.service = service
    }

    func fetchSystemInfo() async {
        isLoading = true
        errorMessage = nil
        do {
            async let status = try service.getSystemStatus()
            async let df = try? service.getSystemDiskUsage()
            async let version = try? service.getCliVersion()

            let resolvedStatus = try await status
            let resolvedDf = await df
            let resolvedVersion = await version ?? "Unknown version"
            let rawVersion = resolvedStatus.apiServerVersion ?? resolvedVersion
            let finalVersion = extractVersionNumber(from: rawVersion)

            self.systemInfo = SystemInfo(
                isRunning: resolvedStatus.status == "running",
                status: resolvedStatus.status,
                version: finalVersion,
                diskUsage: resolvedDf,
                cliMissing: resolvedStatus.cliMissing
            )
        } catch {
            self.systemInfo = SystemInfo(
                isRunning: false, status: "stopped", version: "Unknown", diskUsage: nil)
        }
        isLoading = false
    }

    private func extractVersionNumber(from string: String) -> String {
        if let range = string.range(of: #"(\d+\.\d+\.\d+)"#, options: .regularExpression) {
            return String(string[range])
        }
        return string
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if !Task.isCancelled {
                    await fetchSystemInfo()
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func startSystem() async {
        isLoading = true
        do {
            try await service.startSystem()
            try await Task.sleep(for: .seconds(1))
            await fetchSystemInfo()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func stopSystem() async {
        isLoading = true
        do {
            try await service.stopSystem()
            try await Task.sleep(for: .seconds(1))
            await fetchSystemInfo()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
