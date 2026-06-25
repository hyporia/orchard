import Foundation

struct ContainerStat: Decodable, Identifiable, Sendable, Equatable {
    var id: String
    let cpuUsageUsec: Int64?
    let memoryUsageBytes: Int64?
    let memoryLimitBytes: Int64?
    let blockReadBytes: Int64?
    let blockWriteBytes: Int64?
    let networkRxBytes: Int64?
    let networkTxBytes: Int64?
    let numProcesses: Int?
}

struct ImageItem: Identifiable, Sendable, Equatable {
    var id: String { reference }
    let reference: String
    let fullSize: String?
    let createdAt: String?

    struct Descriptor: Decodable, Sendable, Equatable {
        let size: Int64?
        let digest: String?
    }
    let descriptor: Descriptor?
}

extension ImageItem: Decodable {
    private enum CodingKeys: String, CodingKey {
        case configuration, variants
    }

    private struct Configuration: Decodable {
        let name: String
        let creationDate: String?
        let descriptor: Descriptor?
    }

    private struct Variant: Decodable {
        let size: Int64?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let config = try c.decode(Configuration.self, forKey: .configuration)
        self.reference = config.name
        self.createdAt = config.creationDate
        self.descriptor = config.descriptor
        // The CLI provides no pre-formatted size; derive it from the
        // per-platform variant sizes.
        let variantSizes =
            try c.decodeIfPresent([Variant].self, forKey: .variants)?
            .compactMap(\.size) ?? []
        self.fullSize = variantSizes.isEmpty ? nil : formatBytes(variantSizes.reduce(0, +))
    }
}

struct VolumeItem: Identifiable, Sendable, Equatable {
    var id: String { name }
    let name: String
    let format: String?
    let driver: String?
    let source: String?
    let sizeInBytes: Int64?
    /// Actual on-disk usage (for sparse volume images)
    var actualSizeInBytes: Int64?
}

extension VolumeItem: Decodable {
    private enum CodingKeys: String, CodingKey {
        case configuration
    }

    private struct Configuration: Decodable {
        let name: String
        let format: String?
        let driver: String?
        let source: String?
        let sizeInBytes: Int64?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let config = try c.decode(Configuration.self, forKey: .configuration)
        self.name = config.name
        self.format = config.format
        self.driver = config.driver
        self.source = config.source
        self.sizeInBytes = config.sizeInBytes
        self.actualSizeInBytes = nil
    }
}
