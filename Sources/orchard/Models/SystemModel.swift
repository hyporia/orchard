import Foundation

struct SystemStatus: Decodable, Sendable {
    let status: String
    let apiServerVersion: String?
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
}
