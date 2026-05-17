import SwiftUI

struct ContainerRow: View {
    let container: ContainerItem
    var viewModel: ContainerViewModel

    var isRunning: Bool {
        container.state.lowercased() == "running"
    }

    @State private var showingLogs = false
    @State private var showDeleteConfirmation = false
    @State private var isProcessing = false

    var body: some View {
        HStack {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(container.names)
                    .font(.headline)
                    .textSelection(.enabled)
                Text(container.image)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if isRunning, let stat = viewModel.stats[container.id] {
                    HStack(spacing: 12) {
                        let cpuText = viewModel.cpuPercent[container.id].map {
                            String(format: "%.1f%%", $0)
                        } ?? "—"
                        Label(cpuText, systemImage: "cpu")
                            .font(.caption)
                            .foregroundStyle(viewModel.cpuPercent[container.id] != nil ? AnyShapeStyle(.blue) : AnyShapeStyle(.secondary))

                        if let usage = stat.memoryUsageBytes {
                            Label(memoryLabel(usage: usage, limit: stat.memoryLimitBytes), systemImage: "memorychip")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }
                } else {
                    Text(container.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: { showingLogs = true }) {
                Label("Logs", systemImage: "text.alignleft")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())

            if isRunning {
                Button(action: {
                    Task {
                        withAnimation(.snappy) { isProcessing = true }
                        await viewModel.stop(containerId: container.id)
                        withAnimation(.snappy) { isProcessing = false }
                    }
                }) {
                    if isProcessing {
                        ProgressView().controlSize(.small).tint(.orange)
                    } else {
                        Label("Stop", systemImage: "stop.fill")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
                .disabled(isProcessing)

                Button(action: {
                    Task {
                        withAnimation(.snappy) { isProcessing = true }
                        await viewModel.restart(containerId: container.id)
                        withAnimation(.snappy) { isProcessing = false }
                    }
                }) {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
                .disabled(isProcessing)
            } else {
                Button(action: {
                    Task {
                        withAnimation(.snappy) { isProcessing = true }
                        await viewModel.start(containerId: container.id)
                        withAnimation(.snappy) { isProcessing = false }
                    }
                }) {
                    if isProcessing {
                        ProgressView().controlSize(.small).tint(.green)
                    } else {
                        Label("Start", systemImage: "play.fill")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .foregroundStyle(.green)
                .clipShape(Capsule())
                .disabled(isProcessing)
            }

            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.1))
            .foregroundStyle(.red)
            .clipShape(Capsule())
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
        .animation(.snappy, value: isRunning)
        .animation(.snappy, value: isProcessing)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingLogs) {
            ContainerLogView(containerId: container.id, containerName: container.names)
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    private func memoryLabel(usage: Int64, limit: Int64?) -> String {
        let usageStr = formatBytes(usage)
        if let limit = limit, limit > 0 {
            return "\(usageStr) / \(formatBytes(limit))"
        }
        return usageStr
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_000_000.0
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1000)
        }
        return String(format: "%.0f MB", mb)
    }
}
