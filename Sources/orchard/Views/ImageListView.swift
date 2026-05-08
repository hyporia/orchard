import SwiftUI

struct ImageListView: View {
    var viewModel: ImageViewModel
    @State private var imageToDelete: String?
    
    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView("Loading Images...")
                    .padding()
            } else if viewModel.images.isEmpty {
                ContentUnavailableView(
                    "No Images Found",
                    systemImage: "photo",
                    description: Text("Images will appear here once pulled.")
                )
            } else {
                List(viewModel.images) { image in
                    let isActive = viewModel.activeImages.contains(image.reference)
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(image.reference)
                                    .font(.headline)
                                if isActive {
                                    Text("Active")
                                        .font(.caption2).bold()
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundStyle(.green)
                                        .cornerRadius(4)
                                }
                            }
                            Text("Size: \(image.fullSize ?? "Unknown")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive, action: {
                            imageToDelete = image.reference
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isActive)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Images")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { await viewModel.fetchImages() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchImages()
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
    }
}
