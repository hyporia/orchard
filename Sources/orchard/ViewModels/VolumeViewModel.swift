import Foundation
import SwiftUI

@MainActor
class VolumeViewModel: ObservableObject {
    @Published var volumes: [VolumeItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let service: ContainerServiceProtocol
    
    init(service: ContainerServiceProtocol = CLIContainerService()) {
        self.service = service
    }
    
    func fetchVolumes() async {
        isLoading = true
        errorMessage = nil
        do {
            let status = try await service.getSystemStatus()
            guard status.status == "running" else {
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
        do {
            try await service.deleteVolume(name: name)
            await fetchVolumes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
