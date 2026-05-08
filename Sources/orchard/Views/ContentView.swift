import SwiftUI

struct ContentView: View {
    private let service: ContainerServiceProtocol
    @State private var systemViewModel: SystemViewModel
    @State private var containerViewModel: ContainerViewModel
    @State private var imageViewModel: ImageViewModel
    @State private var volumeViewModel: VolumeViewModel
    @State private var selection: String? = "system"
    
    init(service: ContainerServiceProtocol = CLIContainerService()) {
        self.service = service
        self._systemViewModel = State(initialValue: SystemViewModel(service: service))
        self._containerViewModel = State(initialValue: ContainerViewModel(service: service))
        self._imageViewModel = State(initialValue: ImageViewModel(service: service))
        self._volumeViewModel = State(initialValue: VolumeViewModel(service: service))
    }
    
    var isSystemRunning: Bool {
        systemViewModel.systemInfo?.isRunning == true
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: "system") {
                    Label("System", systemImage: "desktopcomputer")
                }
                
                Section("Management") {
                    NavigationLink(value: "containers") {
                        Label("Containers", systemImage: "shippingbox")
                    }
                    .disabled(!isSystemRunning)
                    
                    NavigationLink(value: "images") {
                        Label("Images", systemImage: "photo")
                    }
                    .disabled(!isSystemRunning)
                    
                    NavigationLink(value: "volumes") {
                        Label("Volumes", systemImage: "externaldrive")
                    }
                    .disabled(!isSystemRunning)
                }
            }
            .navigationTitle("Orchard")
        } detail: {
            switch selection {
            case "system":
                SystemView(viewModel: systemViewModel)
            case "containers":
                ContainerListView(viewModel: containerViewModel)
            case "images":
                ImageListView(viewModel: imageViewModel)
            case "volumes":
                VolumeListView(viewModel: volumeViewModel)
            default:
                ContentUnavailableView("Select a section", systemImage: "sidebar.left")
            }
        }
    }
}

struct ContainerListView: View {
    var viewModel: ContainerViewModel
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading Containers...")
                    .padding()
            } else if viewModel.containers.isEmpty {
                ContentUnavailableView(
                    "No Containers Found",
                    systemImage: "shippingbox",
                    description: Text("Containers will appear here once created.")
                )
            } else {
                List(viewModel.containers) { container in
                    ContainerRow(container: container, viewModel: viewModel)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Containers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { await viewModel.fetchContainers() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchContainers()
            }
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .alert(isPresented: .constant(viewModel.errorMessage != nil), error: SimpleError(msg: viewModel.errorMessage ?? "")) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        }
    }
}

struct SimpleError: LocalizedError {
    let msg: String
    var errorDescription: String? { msg }
}
