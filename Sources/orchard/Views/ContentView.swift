import SwiftUI

struct ContentView: View {
    @StateObject private var systemViewModel = SystemViewModel()
    @StateObject private var containerViewModel = ContainerViewModel()
    @StateObject private var imageViewModel = ImageViewModel()
    @StateObject private var volumeViewModel = VolumeViewModel()
    @State private var selection: String? = "system"
    
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
            if selection == "system" {
                SystemView(viewModel: systemViewModel)
            } else if selection == "containers" {
                ContainerListView(viewModel: containerViewModel)
            } else if selection == "images" {
                ImageListView(viewModel: imageViewModel)
            } else if selection == "volumes" {
                VolumeListView(viewModel: volumeViewModel)
            } else {
                Text("Not implemented yet")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ContainerListView: View {
    @ObservedObject var viewModel: ContainerViewModel
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading Containers...")
                    .padding()
            } else if viewModel.containers.isEmpty {
                VStack {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding()
                    Text("No containers found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
