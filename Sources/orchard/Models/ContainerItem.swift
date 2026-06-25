import Foundation

struct ContainerItem: Identifiable, Equatable, Sendable {
    let id: String
    let image: String
    let state: String
    let status: String
    let names: String
    var publishedPorts: [PublishedPort] = []
    var startedDate: Date? = nil

    struct PublishedPort: Decodable, Equatable, Hashable, Sendable {
        let containerPort: Int
        let hostPort: Int
        let proto: String?
        let hostAddress: String?
    }
}

extension ContainerItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case configuration
        case status
    }

    struct Configuration: Decodable {
        let id: String
        let name: String?
        let image: ImageInfo?
        let initProcess: InitProcess?
        let publishedPorts: [PublishedPort]?

        struct ImageInfo: Decodable {
            let reference: String?
        }

        struct InitProcess: Decodable {
            let executable: String?
            let arguments: [String]?
        }
    }

    struct RuntimeStatus: Decodable {
        let state: String?
        let startedDate: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let config = try container.decode(Configuration.self, forKey: .configuration)

        self.id = config.id
        self.names = config.name ?? config.id
        self.image = config.image?.reference ?? "unknown"
        self.publishedPorts = config.publishedPorts ?? []

        let runtimeStatus = try container.decodeIfPresent(RuntimeStatus.self, forKey: .status)
        self.state = runtimeStatus?.state ?? "unknown"
        self.status = self.state.capitalized
        self.startedDate = runtimeStatus?.startedDate.flatMap {
            ISO8601DateFormatter().date(from: $0)
        }
    }
}
