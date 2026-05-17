import Foundation

struct ContainerItem: Identifiable, Equatable, Sendable {
    let id: String
    let image: String
    let state: String
    let status: String
    let names: String
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

        struct ImageInfo: Decodable {
            let reference: String?
        }

        struct InitProcess: Decodable {
            let executable: String?
            let arguments: [String]?
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let config = try container.decode(Configuration.self, forKey: .configuration)

        self.id = config.id
        self.names = config.name ?? config.id
        self.image = config.image?.reference ?? "unknown"

        self.state = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        self.status = self.state.capitalized
    }
}
