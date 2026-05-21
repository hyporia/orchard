import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.orchard.app"

    /// App lifecycle events (launch, window management).
    static let app = Logger(subsystem: subsystem, category: "App")
    /// Raw CLI subprocess invocation and executable discovery.
    static let cli = Logger(subsystem: subsystem, category: "CLI")
    /// ContainerService — JSON decoding and intentionally-swallowed errors.
    static let service = Logger(subsystem: subsystem, category: "Service")
    /// Container lifecycle actions (start, stop, restart, delete, run).
    static let containers = Logger(subsystem: subsystem, category: "Containers")
    /// System daemon start / stop / status polling.
    static let system = Logger(subsystem: subsystem, category: "System")
    /// Image pull and delete operations.
    static let images = Logger(subsystem: subsystem, category: "Images")
    /// Volume delete operations.
    static let volumes = Logger(subsystem: subsystem, category: "Volumes")
    /// Container log streaming lifecycle.
    static let logs = Logger(subsystem: subsystem, category: "Logs")
}
