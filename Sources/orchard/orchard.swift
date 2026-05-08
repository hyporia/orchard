import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct OrchardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let service: ContainerServiceProtocol = CLIContainerService()
    
    var body: some Scene {
        WindowGroup {
            ContentView(service: service)
        }
    }
}

