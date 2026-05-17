import SwiftUI

struct SystemView: View {
    var viewModel: SystemViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isLoading && viewModel.systemInfo == nil {
                    ProgressView("Loading System Info...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if let info = viewModel.systemInfo {

                    // Status Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Status")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            HStack {
                                Circle()
                                    .fill(info.isRunning ? Color.green : Color.red)
                                    .frame(width: 12, height: 12)
                                Text(info.status.capitalized)
                                    .font(.headline)
                                Spacer()
                                if !info.isRunning {
                                    Button(action: {
                                        Task { await viewModel.startSystem() }
                                    }) {
                                        if viewModel.isLoading {
                                            ProgressView().controlSize(.small).tint(.green)
                                        } else {
                                            Text("Start System")
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                                    .disabled(viewModel.isLoading)
                                } else {
                                    Button(action: {
                                        Task { await viewModel.stopSystem() }
                                    }) {
                                        if viewModel.isLoading {
                                            ProgressView().controlSize(.small).tint(.red)
                                        } else {
                                            Text("Stop System")
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                                    .disabled(viewModel.isLoading)
                                }
                            }
                            .padding()

                            Divider()

                            HStack {
                                Text("Version")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(info.version)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .padding()
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }

                    // Disk Usage Section
                    if let df = info.diskUsage {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Disk Usage")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                DiskUsageRow(title: "Containers", stat: df.containers)
                                    .padding()
                                Divider()
                                DiskUsageRow(title: "Images", stat: df.images)
                                    .padding()
                                Divider()
                                DiskUsageRow(title: "Volumes", stat: df.volumes)
                                    .padding()
                            }
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        }
                    }
                }
            }
            .padding()
        }
        .animation(.snappy, value: viewModel.isLoading)
        .animation(.snappy, value: viewModel.systemInfo?.isRunning)
        .navigationTitle("System")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { await viewModel.fetchSystemInfo() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .onAppear {
            Task { await viewModel.fetchSystemInfo() }
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
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
    }
}

struct DiskUsageRow: View {
    let title: String
    let stat: SystemDiskUsage.UsageStat

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(stat.active) active of \(stat.total) total")
                    .font(.subheadline)
                Text(formatBytes(stat.sizeInBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
