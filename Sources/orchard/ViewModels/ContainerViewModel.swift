import Foundation
import SwiftUI

@MainActor
class ContainerViewModel: ObservableObject {
    @Published var containers: [ContainerItem] = []
    @Published var stats: [String: ContainerStat] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let service: ContainerServiceProtocol
    private var pollingTask: Task<Void, Never>?
    
    init(service: ContainerServiceProtocol = CLIContainerService()) {
        self.service = service
    }
    
    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchStats()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    private func fetchStats() async {
        do {
            let fetchedStats = try await service.fetchStats()
            var newStats: [String: ContainerStat] = [:]
            for stat in fetchedStats {
                newStats[stat.id] = stat
            }
            self.stats = newStats
        } catch {
            // Silently fail stats to avoid UI spam
        }
    }
    
    func fetchContainers() async {
        isLoading = true
        errorMessage = nil
        do {
            let status = try await service.getSystemStatus()
            guard status.status == "running" else {
                self.containers = []
                self.isLoading = false
                return
            }
            
            containers = try await service.fetchContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func start(containerId: String) async {
        do {
            try await service.startContainer(id: containerId)
            await fetchContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func stop(containerId: String) async {
        do {
            try await service.stopContainer(id: containerId)
            await fetchContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func delete(containerId: String) async {
        do {
            try await service.deleteContainer(id: containerId)
            await fetchContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
