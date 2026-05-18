import Foundation

@MainActor
@Observable
class ContainerViewModel {
    var containers: [ContainerItem] = []
    var stats: [String: ContainerStat] = [:]
    var cpuPercent: [String: Double] = [:]
    var isLoading: Bool = false
    var errorMessage: String?
    var processingIds: Set<String> = []

    func isProcessing(_ id: String) -> Bool {
        processingIds.contains(id)
    }

    private let service: ContainerServiceProtocol
    private var pollingTask: Task<Void, Never>?
    private var previousStats: [String: ContainerStat] = [:]
    private var previousPollTime: Date?

    init(service: ContainerServiceProtocol = ContainerService()) {
        self.service = service
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchStatsOnce()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func fetchStatsOnce() async {
        do {
            let now = Date()
            let fetchedStats = try await service.fetchStats()
            var newStats: [String: ContainerStat] = [:]
            var newCpuPercent: [String: Double] = [:]

            for stat in fetchedStats {
                newStats[stat.id] = stat
                if let prev = previousStats[stat.id],
                    let prevCpu = prev.cpuUsageUsec,
                    let currCpu = stat.cpuUsageUsec,
                    let prevTime = previousPollTime
                {
                    let elapsedUsec = now.timeIntervalSince(prevTime) * 1_000_000
                    if elapsedUsec > 0 && currCpu >= prevCpu {
                        let delta = Double(currCpu - prevCpu)
                        newCpuPercent[stat.id] = min(100, delta / elapsedUsec * 100)
                    }
                }
            }

            previousStats = newStats
            previousPollTime = now
            self.stats = newStats
            self.cpuPercent = newCpuPercent
        } catch {
            // INTENTIONAL error-swallow (sanctioned exception to the
            // AGENTS.md "surface errors via errorMessage" rule): fetchStats
            // polls every 2s; a transient failure must not raise an alert or
            // clobber errorMessage set by a user-initiated action. The
            // previous stats simply remain on screen until the next poll.
        }
    }

    func fetchContainers() async {
        isLoading = true
        errorMessage = nil
        do {
            guard try await checkSystemRunning(service) == .proceed else {
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
        processingIds.insert(containerId)
        defer { processingIds.remove(containerId) }
        do {
            try await service.startContainer(id: containerId)
            await fetchContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop(containerId: String) async {
        processingIds.insert(containerId)
        defer { processingIds.remove(containerId) }
        do {
            try await service.stopContainer(id: containerId)
            await fetchContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restart(containerId: String) async {
        processingIds.insert(containerId)
        defer { processingIds.remove(containerId) }
        do {
            try await service.stopContainer(id: containerId)
            try await service.startContainer(id: containerId)
            await fetchContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(containerId: String) async {
        processingIds.insert(containerId)
        defer { processingIds.remove(containerId) }
        do {
            if let container = containers.first(where: { $0.id == containerId }),
                container.state == "running"
            {
                try await service.stopContainer(id: containerId)
            }
            try await service.deleteContainer(id: containerId)
            await fetchContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func run(image: String, name: String?, options: RunContainerOptions) async throws {
        try await service.runContainer(image: image, name: name, options: options)
        await fetchContainers()
    }
}
