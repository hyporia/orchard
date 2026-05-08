import SwiftUI

struct ImageListView: View {
    @ObservedObject var viewModel: ImageViewModel
    
    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView("Loading Images...")
                    .padding()
            } else if viewModel.images.isEmpty {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding()
                    Text("No images found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                            }
                            Text("Size: \(image.fullSize ?? "Unknown")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive, action: {
                            Task { await viewModel.delete(reference: image.reference) }
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
        .alert(isPresented: .constant(viewModel.errorMessage != nil), error: SimpleError(msg: viewModel.errorMessage ?? "")) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        }
    }
}
