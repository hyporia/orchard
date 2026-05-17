import SwiftUI

struct VolumeListView: View {
    var viewModel: VolumeViewModel
    @State private var volumeToDelete: String?
    @State private var searchText = ""

    var filteredVolumes: [VolumeItem] {
        guard !searchText.isEmpty else { return viewModel.volumes }
        return viewModel.volumes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

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
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredVolumes) { volume in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(volume.name)
                                        .font(.headline)
                                        .textSelection(.enabled)
                                    if let format = volume.format {
                                        Text(format)
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
                                .buttonStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                            }
                            .padding(16)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding()
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .animation(.snappy, value: viewModel.volumes)
                .overlay {
                    if filteredVolumes.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
        .navigationTitle("Volumes")
        .searchable(text: $searchText, prompt: "Search volumes")
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
            Task { await viewModel.fetchVolumes() }
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
