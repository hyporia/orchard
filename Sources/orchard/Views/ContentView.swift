import SwiftUI

struct ContentView: View {
    private let service: ContainerServiceProtocol
    @State private var systemViewModel: SystemViewModel
    @State private var containerViewModel: ContainerViewModel
    @State private var imageViewModel: ImageViewModel
    @State private var volumeViewModel: VolumeViewModel
    @State private var selection: String? = "system"

    init(service: ContainerServiceProtocol = ContainerService()) {
        self.service = service
        self._systemViewModel = State(initialValue: SystemViewModel(service: service))
        self._containerViewModel = State(initialValue: ContainerViewModel(service: service))
        self._imageViewModel = State(initialValue: ImageViewModel(service: service))
        self._volumeViewModel = State(initialValue: VolumeViewModel(service: service))
    }

    var isSystemRunning: Bool {
        systemViewModel.systemInfo?.isRunning == true
    }

    var cliMissing: Bool {
        systemViewModel.systemInfo?.cliMissing == true
    }

    private func disabledHelp(_ noun: String) -> String {
        cliMissing
            ? "The 'container' CLI was not found. Install it and ensure it is in your PATH."
            : "Start the system daemon to manage \(noun)"
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: "system") {
                    Label {
                        Text("System")
                    } icon: {
                        Image(systemName: "cpu")
                            .foregroundStyle(.blue)
                    }
                }

                Section("Management") {
                    NavigationLink(value: "containers") {
                        Label {
                            Text("Containers")
                        } icon: {
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .disabled(!isSystemRunning)
                    .help(isSystemRunning ? "" : disabledHelp("containers"))

                    NavigationLink(value: "images") {
                        Label {
                            Text("Images")
                        } icon: {
                            Image(systemName: "cube.box.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                    .disabled(!isSystemRunning)
                    .help(isSystemRunning ? "" : disabledHelp("images"))

                    NavigationLink(value: "volumes") {
                        Label {
                            Text("Volumes")
                        } icon: {
                            Image(systemName: "externaldrive.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .disabled(!isSystemRunning)
                    .help(isSystemRunning ? "" : disabledHelp("volumes"))
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
    @State private var searchText = ""
    @State private var showRunContainer = false

    var filteredContainers: [ContainerItem] {
        guard !searchText.isEmpty else { return viewModel.containers }
        return viewModel.containers.filter {
            $0.names.localizedCaseInsensitiveContains(searchText)
                || $0.image.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.containers.isEmpty {
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
                        ForEach(filteredContainers) { container in
                            ContainerRow(container: container, viewModel: viewModel)
                        }
                    }
                    .padding()
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .animation(.snappy, value: viewModel.containers)
                .overlay {
                    if filteredContainers.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
        .navigationTitle("Containers")
        .searchable(text: $searchText, prompt: "Search containers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { await viewModel.fetchContainers() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showRunContainer = true }) {
                    Label("Run Container", systemImage: "plus")
                }
            }
        }
        .onAppear {
            Task { await viewModel.fetchContainers() }
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
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showRunContainer) {
            RunContainerView(viewModel: viewModel)
        }
    }
}
