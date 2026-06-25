import SwiftUI

struct ContainerRow: View {
    let container: ContainerItem
    var viewModel: ContainerViewModel

    var isRunning: Bool {
        container.state.lowercased() == "running"
    }

    @State private var showingLogs = false
    @State private var showDeleteConfirmation = false

    var isProcessing: Bool {
        viewModel.isProcessing(container.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        Task { await viewModel.stop(containerId: container.id) }
                    }) {
                        if isProcessing {
                            ProgressView().controlSize(.small).tint(.red)
                        } else {
                            Label("Stop", systemImage: "stop.fill")
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
                    .disabled(isProcessing)
    
                    Button(action: {
                        Task { await viewModel.restart(containerId: container.id) }
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
                        Task { await viewModel.start(containerId: container.id) }
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

            if isRunning {
                HStack(spacing: 12) {
                    if let stat = viewModel.stats[container.id] {
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

                    if let started = container.startedDate {
                        Label(formatUptime(since: started), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(container.publishedPorts, id: \.self) { port in
                        PortLink(port: port)
                    }

                    Spacer(minLength: 0)
                }
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 18)
            } else {
                Text(container.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 18)
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

}

/// A published port shown as `host:container`. TCP ports open
/// `http://localhost:<hostPort>` in the default browser when clicked.
private struct PortLink: View {
    let port: ContainerItem.PublishedPort

    @State private var isHovering = false

    private var isClickable: Bool {
        port.proto?.lowercased() != "udp"
    }

    private var text: String {
        let mapping = "\(port.hostPort):\(port.containerPort)"
        return isClickable ? mapping : "\(mapping)/udp"
    }

    var body: some View {
        if isClickable {
            Button(action: {
                if let url = URL(string: "http://localhost:\(port.hostPort)") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Label(text, systemImage: "globe")
                    .font(.caption)
                    .underline(isHovering)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .help("Open http://localhost:\(port.hostPort) in browser")
        } else {
            Label(text, systemImage: "network")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
