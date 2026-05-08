import SwiftUI

struct ContainerLogView: View {
    @StateObject private var viewModel: ContainerLogViewModel
    @Environment(\.dismiss) private var dismiss

    init(containerId: String) {
        _viewModel = StateObject(wrappedValue: ContainerLogViewModel(containerId: containerId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ScrollViewReader { proxy in
                    Text(viewModel.logs)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                        .onChange(of: viewModel.logs) { _, _ in
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
            .navigationTitle("Logs: \(viewModel.containerId)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive, action: {
                        viewModel.logs = ""
                    }) {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
        }
        .onAppear {
            viewModel.startStreaming()
        }
        .onDisappear {
            viewModel.stopStreaming()
        }
    }
}
