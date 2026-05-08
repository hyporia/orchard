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

struct ImageItem: Decodable, Identifiable, Sendable, Equatable {
    var id: String { reference }
    let reference: String
    let fullSize: String?
    
    // Optional descriptor info
    struct Descriptor: Decodable, Sendable, Equatable {
        let size: Int64?
        let digest: String?
    }
    let descriptor: Descriptor?
}

struct VolumeItem: Decodable, Identifiable, Sendable, Equatable {
    var id: String { name }
    let name: String
    let format: String?
    let driver: String?
    let source: String?
    let sizeInBytes: Int64?
}
