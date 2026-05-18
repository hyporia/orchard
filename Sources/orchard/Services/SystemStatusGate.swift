import Foundation

enum SystemGateResult {
    case proceed
    case notRunning
}

@MainActor
func checkSystemRunning(_ service: ContainerServiceProtocol) async throws -> SystemGateResult {
    let status = try await service.getSystemStatus()
    return status.status == "running" ? .proceed : .notRunning
}
