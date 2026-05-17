import SwiftUI

struct ImageListView: View {
    var viewModel: ImageViewModel
    @State private var imageToDelete: String?
    @State private var showPullSheet = false
    @State private var searchText = ""

    var filteredImages: [ImageItem] {
        guard !searchText.isEmpty else { return viewModel.images }
        return viewModel.images.filter { $0.reference.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView("Loading Images...")
                    .padding()
            } else if viewModel.images.isEmpty {
                ContentUnavailableView(
                    "No Images Found",
                    systemImage: "cube.box",
                    description: Text("Images will appear here once pulled.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredImages) { image in
                            let isActive = viewModel.activeImages.contains(image.reference)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(image.reference)
                                            .font(.headline)
                                            .textSelection(.enabled)
                                        if isActive {
                                            Text("Active")
                                                .font(.caption2).bold()
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.2))
                                                .foregroundStyle(.green)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    if let size = image.fullSize {
                                        Text(size)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let date = image.createdAt {
                                        Text(relativeDate(date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive, action: {
                                    imageToDelete = image.reference
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isActive ? Color.gray.opacity(0.1) : Color.red.opacity(0.1))
                                .foregroundStyle(isActive ? .gray : .red)
                                .clipShape(Capsule())
                                .disabled(isActive)
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
                .animation(.snappy, value: viewModel.images)
                .overlay {
                    if filteredImages.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
        .navigationTitle("Images")
        .searchable(text: $searchText, prompt: "Search images")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { await viewModel.fetchImages() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showPullSheet = true }) {
                    Label("Pull Image", systemImage: "arrow.down.circle")
                }
            }
        }
        .onAppear {
            Task { await viewModel.fetchImages() }
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
            "Delete Image?",
            isPresented: Binding(
                get: { imageToDelete != nil },
                set: { if !$0 { imageToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let reference = imageToDelete {
                    Task { await viewModel.delete(reference: reference) }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showPullSheet) {
            PullImageSheet(viewModel: viewModel)
        }
    }

    private func relativeDate(_ dateString: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: dateString) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        // Fallback: try without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: dateString) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return dateString
    }
}

struct PullImageSheet: View {
    var viewModel: ImageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var reference = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Image Reference") {
                    TextField("e.g. docker.io/nginx:latest", text: $reference)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Pull Image")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        Task {
                            await viewModel.pull(reference: reference.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        }
                    }) {
                        if viewModel.isPulling {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Pull")
                        }
                    }
                    .disabled(reference.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isPulling)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 150)
    }
}
