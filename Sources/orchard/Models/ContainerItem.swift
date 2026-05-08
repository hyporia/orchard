import Foundation

struct ContainerItem: Identifiable, Equatable {
    var id: String
    var image: String
    var state: String
    var status: String
    var names: String
}

extension ContainerItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case configuration
        case status
    }
    
    struct Configuration: Decodable {
        let id: String
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
        self.names = config.id
        self.image = config.image?.reference ?? "unknown"
        
        self.state = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        self.status = self.state.capitalized
    }
}
