import Foundation
import SwiftUI

@MainActor
class SystemViewModel: ObservableObject {
    @Published var systemInfo: SystemInfo?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let service: ContainerServiceProtocol
    
    init(service: ContainerServiceProtocol = CLIContainerService()) {
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
                diskUsage: resolvedDf
            )
        } catch {
            self.systemInfo = SystemInfo(isRunning: false, status: "stopped", version: "Unknown", diskUsage: nil)
        }
        isLoading = false
    }
    
    private func extractVersionNumber(from string: String) -> String {
        if let range = string.range(of: #"(\d+\.\d+\.\d+)"#, options: .regularExpression) {
            return String(string[range])
        }
        return string
    }

    func startSystem() async {
        isLoading = true
        do {
            try await service.startSystem()
            // Add a small delay to allow the daemon to start before fetching status
            try await Task.sleep(nanoseconds: 1_000_000_000)
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
            try await Task.sleep(nanoseconds: 1_000_000_000)
            await fetchSystemInfo()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
