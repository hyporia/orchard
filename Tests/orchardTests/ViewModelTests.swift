import Foundation
import Testing

@testable import orchard

// MARK: - Configurable service stub

private final class ConfigurableService: ContainerServiceProtocol, @unchecked Sendable {
    var fetchContainersHandler: @Sendable () async throws -> [ContainerItem] = { [] }
    var fetchStatsHandler: @Sendable () async throws -> [ContainerStat] = { [] }
    var getSystemStatusHandler: @Sendable () async throws -> SystemStatus = {
        SystemStatus(status: "running", apiServerVersion: nil)
    }
    var fetchImagesHandler: @Sendable () async throws -> [ImageItem] = { [] }
    var fetchVolumesHandler: @Sendable () async throws -> [VolumeItem] = { [] }

    func fetchContainers() async throws -> [ContainerItem] { try await fetchContainersHandler() }
    func fetchStats() async throws -> [ContainerStat] { try await fetchStatsHandler() }
    func startContainer(id: String) async throws {}
    func stopContainer(id: String) async throws {}
    func deleteContainer(id: String) async throws {}
    func getSystemStatus() async throws -> SystemStatus { try await getSystemStatusHandler() }
    func getSystemDiskUsage() async throws -> SystemDiskUsage {
        let stat = SystemDiskUsage.UsageStat(active: 0, reclaimable: 0, sizeInBytes: 0, total: 0)
        return SystemDiskUsage(containers: stat, images: stat, volumes: stat)
    }
    func getCliVersion() async throws -> String { "" }
    func startSystem() async throws {}
    func stopSystem() async throws {}
    func fetchImages() async throws -> [ImageItem] { try await fetchImagesHandler() }
    func deleteImage(reference: String) async throws {}
    func pullImage(reference: String) async throws {}
    func fetchVolumes() async throws -> [VolumeItem] { try await fetchVolumesHandler() }
    func deleteVolume(name: String) async throws {}
    func runContainer(image: String, name: String?, options: RunContainerOptions) async throws {}
    func streamLogs(containerId: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private enum VMTestError: Error { case boom }

private func makeStat(id: String, cpu: Int64) -> ContainerStat {
    ContainerStat(
        id: id, cpuUsageUsec: cpu, memoryUsageBytes: nil, memoryLimitBytes: nil,
        blockReadBytes: nil, blockWriteBytes: nil, networkRxBytes: nil,
        networkTxBytes: nil, numProcesses: nil)
}

// MARK: - ContainerViewModel

@MainActor
@Suite("ContainerViewModel")
struct ContainerViewModelTests {

    @Test func notRunningClearsContainers() async {
        let service = ConfigurableService()
        service.getSystemStatusHandler = { SystemStatus(status: "stopped", apiServerVersion: nil) }
        let vm = ContainerViewModel(service: service)
        vm.containers = [ContainerItem(id: "old", image: "x", state: "running", status: "Running", names: "old")]

        await vm.fetchContainers()

        #expect(vm.containers.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test func runningPopulatesContainers() async {
        let service = ConfigurableService()
        service.fetchContainersHandler = {
            [ContainerItem(id: "c1", image: "alpine", state: "running", status: "Running", names: "c1")]
        }
        let vm = ContainerViewModel(service: service)

        await vm.fetchContainers()

        #expect(vm.containers.count == 1)
        #expect(vm.containers[0].id == "c1")
    }

    @Test func fetchContainersErrorSetsErrorMessage() async {
        let service = ConfigurableService()
        service.fetchContainersHandler = { throw VMTestError.boom }
        let vm = ContainerViewModel(service: service)

        await vm.fetchContainers()

        #expect(vm.errorMessage != nil)
    }

    @Test func fetchStatsOnceComputesCpuPercent() async {
        let service = ConfigurableService()
        let vm = ContainerViewModel(service: service)

        service.fetchStatsHandler = { [makeStat(id: "c1", cpu: 1_000)] }
        await vm.fetchStatsOnce()

        service.fetchStatsHandler = { [makeStat(id: "c1", cpu: 2_000)] }
        await vm.fetchStatsOnce()

        #expect(vm.cpuPercent["c1"] != nil)
        #expect((vm.cpuPercent["c1"] ?? -1) >= 0)
    }
}

// MARK: - ImageViewModel

@MainActor
@Suite("ImageViewModel")
struct ImageViewModelTests {

    @Test func notRunningClearsImages() async {
        let service = ConfigurableService()
        service.getSystemStatusHandler = { SystemStatus(status: "stopped", apiServerVersion: nil) }
        let vm = ImageViewModel(service: service)
        vm.images = [ImageItem(reference: "old", fullSize: nil, createdAt: nil, descriptor: nil)]

        await vm.fetchImages()

        #expect(vm.images.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test func runningPopulatesImages() async {
        let service = ConfigurableService()
        service.fetchImagesHandler = {
            [ImageItem(reference: "nginx:latest", fullSize: "100MB", createdAt: nil, descriptor: nil)]
        }
        let vm = ImageViewModel(service: service)

        await vm.fetchImages()

        #expect(vm.images.count == 1)
        #expect(vm.images[0].reference == "nginx:latest")
    }

    @Test func fetchImagesErrorSetsErrorMessage() async {
        let service = ConfigurableService()
        service.fetchImagesHandler = { throw VMTestError.boom }
        let vm = ImageViewModel(service: service)

        await vm.fetchImages()

        #expect(vm.errorMessage != nil)
    }
}

// MARK: - VolumeViewModel

@MainActor
@Suite("VolumeViewModel")
struct VolumeViewModelTests {

    @Test func notRunningClearsVolumes() async {
        let service = ConfigurableService()
        service.getSystemStatusHandler = { SystemStatus(status: "stopped", apiServerVersion: nil) }
        let vm = VolumeViewModel(service: service)
        vm.volumes = [
            VolumeItem(
                name: "old", format: nil, driver: nil, source: nil,
                sizeInBytes: nil, actualSizeInBytes: nil)
        ]

        await vm.fetchVolumes()

        #expect(vm.volumes.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test func runningPopulatesVolumes() async {
        let service = ConfigurableService()
        service.fetchVolumesHandler = {
            [VolumeItem(name: "data", format: "ext4", driver: "local", source: nil,
                        sizeInBytes: 1024, actualSizeInBytes: nil)]
        }
        let vm = VolumeViewModel(service: service)

        await vm.fetchVolumes()

        #expect(vm.volumes.count == 1)
        #expect(vm.volumes[0].name == "data")
    }

    @Test func fetchVolumesErrorSetsErrorMessage() async {
        let service = ConfigurableService()
        service.fetchVolumesHandler = { throw VMTestError.boom }
        let vm = VolumeViewModel(service: service)

        await vm.fetchVolumes()

        #expect(vm.errorMessage != nil)
    }
}
