import Foundation
import OSLog

@MainActor
@Observable
class ImageViewModel {
    var images: [ImageItem] = []
    var activeImages: Set<String> = []
    var isLoading: Bool = false
    var isPulling: Bool = false
    var errorMessage: String?

    private let service: ContainerServiceProtocol

    init(service: ContainerServiceProtocol = ContainerService()) {
        self.service = service
    }

    func fetchImages() async {
        isLoading = true
        errorMessage = nil
        do {
            guard try await checkSystemRunning(service) == .proceed else {
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
        Logger.images.info("Deleting image \(reference, privacy: .public)")
        do {
            try await service.deleteImage(reference: reference)
            await fetchImages()
        } catch {
            Logger.images.error("Failed to delete image \(reference, privacy: .public): \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func pull(reference: String) async {
        Logger.images.info("Pulling image \(reference, privacy: .public)")
        isPulling = true
        errorMessage = nil
        defer { isPulling = false }
        do {
            try await service.pullImage(reference: reference)
            await fetchImages()
        } catch {
            if !Task.isCancelled {
                Logger.images.error("Failed to pull image \(reference, privacy: .public): \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
            }
        }
    }
}
