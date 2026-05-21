import Foundation
import OSLog

@MainActor
@Observable
class VolumeViewModel {
    var volumes: [VolumeItem] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let service: ContainerServiceProtocol

    init(service: ContainerServiceProtocol = ContainerService()) {
        self.service = service
    }

    func fetchVolumes() async {
        isLoading = true
        errorMessage = nil
        do {
            guard try await checkSystemRunning(service) == .proceed else {
                self.volumes = []
                self.isLoading = false
                return
            }
            volumes = try await service.fetchVolumes()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func delete(name: String) async {
        Logger.volumes.info("Deleting volume \(name, privacy: .public)")
        do {
            try await service.deleteVolume(name: name)
            await fetchVolumes()
        } catch {
            Logger.volumes.error("Failed to delete volume \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
}
