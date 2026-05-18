import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        setupStatusItem()
        captureMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "shippingbox.fill",
                accessibilityDescription: "Orchard"
            )
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        statusItem = item
    }

    @objc private func statusItemClicked() {
        togglePopover()
    }

    private func captureMainWindow() {
        mainWindow = NSApp.windows.first { $0.canBecomeMain }
        if let window = mainWindow {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(mainWindowWillClose),
                name: NSWindow.willCloseNotification,
                object: window
            )
        }
    }

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        if mainWindow == nil {
            mainWindow = NSApp.windows.first { $0.canBecomeMain }
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 220, height: 96)
        popover.contentViewController = NSHostingController(
            rootView: StatusMenuView(
                onShow: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.showMainWindow()
                },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        self.popover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func mainWindowWillClose() {
        Task { @MainActor [weak self] in
            self?.dropToBackground()
        }
    }

    private func dropToBackground() {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct OrchardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let service: ContainerServiceProtocol = ContainerService()

    var body: some Scene {
        WindowGroup {
            ContentView(service: service)
        }
    }
}

private struct StatusMenuView: View {
    let onShow: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button("Show Orchard", action: onShow)
                .buttonStyle(.borderedProminent)
            Button("Quit Orchard", action: onQuit)
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
