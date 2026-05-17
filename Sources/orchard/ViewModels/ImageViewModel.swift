import Foundation

@MainActor
@Observable
class ImageViewModel {
    var images: [ImageItem] = []
    var activeImages: Set<String> = []
    var isLoading: Bool = false
    var isPulling: Bool = false
    var errorMessage: String?

    private let service: ContainerServiceProtocol

    init(service: ContainerServiceProtocol = CLIContainerService()) {
        self.service = service
    }

    func fetchImages() async {
        isLoading = true
        errorMessage = nil
        do {
            let status = try await service.getSystemStatus()
            guard status.status == "running" else {
                self.images = []
                self.activeImages = []
                self.isLoading = false
                return
            }

            async let fetchedImages = service.fetchImages()
            async let fetchedContainers = try? service.fetchContainers()

            self.images = try await fetchedImages

            var newActive: Set<String> = []
            if let containers = await fetchedContainers {
                for container in containers {
                    newActive.insert(container.image)
                }
            }
            self.activeImages = newActive

        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func delete(reference: String) async {
        do {
            try await service.deleteImage(reference: reference)
            await fetchImages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pull(reference: String) async {
        isPulling = true
        errorMessage = nil
        do {
            try await service.pullImage(reference: reference)
            await fetchImages()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPulling = false
    }
}
