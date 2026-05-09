import Foundation

extension Process {
    static func containerProcess(arguments: [String]) -> Process {
        let process = Process()
        
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/container")
        process.arguments = arguments
        
        return process
    }
}
