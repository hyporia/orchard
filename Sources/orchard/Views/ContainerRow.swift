import SwiftUI

struct ContainerRow: View {
    let container: ContainerItem
    var viewModel: ContainerViewModel
    
    var isRunning: Bool {
        container.state.lowercased() == "running"
    }
    
    @State private var showingLogs = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(container.names.isEmpty ? container.id : container.names)
                    .font(.headline)
                Text(container.image)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if isRunning, let stat = viewModel.stats[container.id] {
                    HStack(spacing: 12) {
                        Label(formatCPU(stat.cpuUsageUsec), systemImage: "cpu")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Label(formatMemory(stat.memoryUsageBytes), systemImage: "memorychip")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                } else {
                    Text(container.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                showingLogs = true
            }) {
                Label("Logs", systemImage: "text.alignleft")
            }
            .buttonStyle(.bordered)
            
            if isRunning {
                Button(action: {
                    Task { await viewModel.stop(containerId: container.id) }
                }) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button(action: {
                    Task { await viewModel.start(containerId: container.id) }
                }) {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
            
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .confirmationDialog(
                "Delete Container?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.delete(containerId: container.id) }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingLogs) {
            ContainerLogView(containerId: container.id)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
    
    private func formatCPU(_ usec: Int64?) -> String {
        guard let usec = usec else { return "0%" }
        // Very basic CPU conversion, usually usec requires delta calculation.
        // We will just show a static placeholder or basic calculation if delta isn't available.
        // Alternatively, displaying usec directly or just an active indicator:
        return "\(usec / 100_000)%"
    }
    
    private func formatMemory(_ bytes: Int64?) -> String {
        guard let bytes = bytes else { return "0 MB" }
        let mb = Double(bytes) / 1_000_000.0
        return String(format: "%.2f MB", mb)
    }
}
