import SwiftUI

struct VolumeListView: View {
    var viewModel: VolumeViewModel
    
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
                            if let size = volume.sizeInBytes {
                                Text("Size: \(formatBytes(size))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive, action: {
                            Task { await viewModel.delete(name: volume.name) }
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
        .alert(isPresented: .constant(viewModel.errorMessage != nil), error: SimpleError(msg: viewModel.errorMessage ?? "")) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let megabytes = Double(bytes) / 1_000_000.0
        return String(format: "%.2f MB", megabytes)
    }
}
