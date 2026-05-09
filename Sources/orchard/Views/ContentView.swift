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
                    Label {
                        Text("System")
                    } icon: {
                        Image(systemName: "desktopcomputer")
                            .foregroundStyle(.blue)
                    }
                }
                
                Section("Management") {
                    NavigationLink(value: "containers") {
                        Label {
                            Text("Containers")
                        } icon: {
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .disabled(!isSystemRunning)
                    
                    NavigationLink(value: "images") {
                        Label {
                            Text("Images")
                        } icon: {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                    .disabled(!isSystemRunning)
                    
                    NavigationLink(value: "volumes") {
                        Label {
                            Text("Volumes")
                        } icon: {
                            Image(systemName: "externaldrive.fill")
                                .foregroundStyle(.green)
                        }
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
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.containers) { container in
                            ContainerRow(container: container, viewModel: viewModel)
                        }
                    }
                    .padding()
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .animation(.snappy, value: viewModel.containers)
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
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}


