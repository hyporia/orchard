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
                    GroupBox("Status") {
                        HStack {
                            Circle()
                                .fill(info.isRunning ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            Text(info.status.capitalized)
                                .font(.headline)
                            Spacer()
                            if !info.isRunning {
                                Button("Start System") {
                                    Task { await viewModel.startSystem() }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.isLoading)
                            } else {
                                Button("Stop System", role: .destructive) {
                                    Task { await viewModel.stopSystem() }
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.isLoading)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                        
                        HStack {
                            Text("Version")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(info.version)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Disk Usage Section
                    if let df = info.diskUsage {
                        GroupBox("Disk Usage") {
                            VStack(spacing: 12) {
                                DiskUsageRow(title: "Containers", stat: df.containers)
                                Divider()
                                DiskUsageRow(title: "Images", stat: df.images)
                                Divider()
                                DiskUsageRow(title: "Volumes", stat: df.volumes)
                            }
                        }
                    }
                }
            }
            .padding()
        }
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
            Task {
                await viewModel.fetchSystemInfo()
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
                Text("\(stat.active) / \(stat.total) active")
                    .font(.subheadline)
                Text("Size: \(formatBytes(stat.sizeInBytes))")
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
