import Foundation

struct SystemStatus: Decodable, Sendable {
    let status: String
    let apiServerVersion: String?
    var cliMissing: Bool = false

    enum CodingKeys: String, CodingKey {
        case status, apiServerVersion
    }

    init(status: String, apiServerVersion: String?, cliMissing: Bool = false) {
        self.status = status
        self.apiServerVersion = apiServerVersion
        self.cliMissing = cliMissing
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decode(String.self, forKey: .status)
        self.apiServerVersion = try c.decodeIfPresent(String.self, forKey: .apiServerVersion)
        self.cliMissing = false
    }
}

struct SystemDiskUsage: Decodable, Sendable {
    struct UsageStat: Decodable, Sendable {
        let active: Int
        let reclaimable: Int64
        let sizeInBytes: Int64
        let total: Int
    }
    let containers: UsageStat
    let images: UsageStat
    let volumes: UsageStat
}

struct SystemInfo: Sendable {
    let isRunning: Bool
    let status: String
    let version: String
    let diskUsage: SystemDiskUsage?
    var cliMissing: Bool = false
}
