import Foundation

enum RunContainerValidationError: Error, LocalizedError, Equatable {
    case emptyImage
    case invalidName(String)
    case invalidMemory(String)
    case invalidCpus(String)
    case invalidPort(String)
    case invalidEnv(String)
    case invalidVolume(String)

    var errorDescription: String? {
        switch self {
        case .emptyImage: return "Image is required."
        case .invalidName(let v): return "Invalid container name: \(v)"
        case .invalidMemory(let v): return "Invalid memory value: \(v). Expected e.g. 512M, 1G (min 200M)."
        case .invalidCpus(let v): return "Invalid CPU value: \(v). Expected a positive number."
        case .invalidPort(let v): return "Invalid port mapping: \(v). Expected hostPort:containerPort."
        case .invalidEnv(let v): return "Invalid environment variable: \(v). Expected KEY=value."
        case .invalidVolume(let v): return "Invalid volume: \(v). Expected hostPath:containerPath."
        }
    }
}

enum RunContainerValidator {
    static func isValidName(_ name: String) -> Bool {
        name.range(of: #"^[a-zA-Z0-9][a-zA-Z0-9_.-]*$"#, options: .regularExpression) != nil
    }

    static func isValidMemory(_ memory: String) -> Bool {
        let pattern = #"^(\d+(?:\.\d+)?)([KMGkmg])$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: memory, range: NSRange(memory.startIndex..., in: memory)),
              let numRange = Range(match.range(at: 1), in: memory),
              let unitRange = Range(match.range(at: 2), in: memory),
              let value = Double(memory[numRange]) else { return false }
        let mb: Double
        switch memory[unitRange].lowercased() {
        case "k": mb = value / 1024
        case "m": mb = value
        case "g": mb = value * 1024
        default: return false
        }
        return mb >= 200
    }

    static func isValidCpus(_ cpus: String) -> Bool {
        guard let value = Double(cpus) else { return false }
        return value > 0
    }

    static func isValidPort(_ port: String) -> Bool {
        port.range(of: #"^\d+(:\d+)?(/tcp|/udp)?$"#, options: .regularExpression) != nil
    }

    static func isValidEnv(_ env: String) -> Bool {
        env.range(of: #"^[a-zA-Z_][a-zA-Z0-9_]*="#, options: .regularExpression) != nil
    }

    static func isValidVolume(_ volume: String) -> Bool {
        volume.contains(":")
    }

    /// Hard gate used by the service. Throws on the first invalid field.
    static func validate(image: String, name: String?, options: RunContainerOptions) throws {
        let trimmedImage = image.trimmingCharacters(in: .whitespaces)
        guard !trimmedImage.isEmpty else { throw RunContainerValidationError.emptyImage }

        if let name, !name.isEmpty, !isValidName(name) {
            throw RunContainerValidationError.invalidName(name)
        }
        if !options.memory.isEmpty, !isValidMemory(options.memory) {
            throw RunContainerValidationError.invalidMemory(options.memory)
        }
        if !options.cpus.isEmpty, !isValidCpus(options.cpus) {
            throw RunContainerValidationError.invalidCpus(options.cpus)
        }
        for port in options.ports where !port.isEmpty {
            if !isValidPort(port) { throw RunContainerValidationError.invalidPort(port) }
        }
        for env in options.envVars where !env.isEmpty {
            if !isValidEnv(env) { throw RunContainerValidationError.invalidEnv(env) }
        }
        for vol in options.volumes where !vol.isEmpty {
            if !isValidVolume(vol) { throw RunContainerValidationError.invalidVolume(vol) }
        }
    }
}
