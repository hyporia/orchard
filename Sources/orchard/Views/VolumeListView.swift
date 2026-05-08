import SwiftUI

struct VolumeListView: View {
    var viewModel: VolumeViewModel
    @State private var volumeToDelete: String?
    
    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.volumes.isEmpty {
                ProgressView("Loading Volumes...")
                    .padding()
            } else if viewModel.volumes.isEmpty {
                ContentUnavailableView(
                    "No Volumes Found",
                    systemImage: "externaldrive",
                    description: Text("Volumes will appear here once created.")
                )
            } else {
                List(viewModel.volumes) { volume in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(volume.name)
                                .font(.headline)
                            if let format = volume.format {
                                Text("Format: \(format)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let size = volume.actualSizeInBytes ?? volume.sizeInBytes {
                                Text("Used: \(formatBytes(size))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive, action: {
                            volumeToDelete = volume.name
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Volumes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { await viewModel.fetchVolumes() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchVolumes()
            }
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
        .confirmationDialog(
            "Delete Volume?",
            isPresented: Binding(
                get: { volumeToDelete != nil },
                set: { if !$0 { volumeToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let name = volumeToDelete {
                    Task { await viewModel.delete(name: name) }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
