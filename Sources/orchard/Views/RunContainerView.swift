import SwiftUI

struct RunContainerView: View {
    var viewModel: ContainerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var imageReference = ""
    @State private var containerName = ""
    @State private var options = RunContainerOptions()
    @State private var isRunning = false

    @State private var portRows: [String] = [""]
    @State private var envRows: [String] = [""]
    @State private var volumeRows: [String] = [""]

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                resourceSection
                portsSection
                envSection
                volumesSection
                flagsSection
            }
            .navigationTitle("Run Container")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: run) {
                        if isRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Run")
                        }
                    }
                    .disabled(
                        imageReference.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 460)
    }

    // MARK: - Sections

    private var imageSection: some View {
        Section("Image") {
            TextField(text: $imageReference, prompt: Text("docker.io/nginx:latest")) {
                Text("Image")
            }
            .autocorrectionDisabled()
            TextField(text: $containerName, prompt: Text("cool_nginx")) {
                Text("Name")
            }
            .autocorrectionDisabled()
        }
    }

    private var resourceSection: some View {
        Section("Resources") {
            TextField(text: $options.memory, prompt: Text("512M")) {
                Text("Memory")
            }
            .autocorrectionDisabled()
            TextField(text: $options.cpus, prompt: Text("2")) {
                Text("CPUs")
            }
            .autocorrectionDisabled()
        }
    }

    private var portsSection: some View {
        Section {
            ForEach(portRows.indices, id: \.self) { (i: Int) in
                LabeledContent {
                    HStack(spacing: 8) {
                        TextField("", text: $portRows[i], prompt: Text("8080:80"))
                            .autocorrectionDisabled()
                        if portRows.count > 1 {
                            Button(role: .destructive) {
                                portRows.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } label: {
                    Text("Port")
                }
            }
            Button {
                portRows.append("")
            } label: {
                Label("Add Port", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        } header: {
            Text("Port Mappings")
        }
    }

    private var envSection: some View {
        Section("Environment Variables") {
            ForEach(envRows.indices, id: \.self) { (i: Int) in
                LabeledContent {
                    HStack(spacing: 8) {
                        TextField("", text: $envRows[i], prompt: Text("DEBUG=true"))
                            .autocorrectionDisabled()
                        if envRows.count > 1 {
                            Button(role: .destructive) {
                                envRows.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } label: {
                    Text("Variable")
                }
            }
            Button {
                envRows.append("")
            } label: {
                Label("Add Variable", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        }
    }

    private var volumesSection: some View {
        Section("Volumes") {
            ForEach(volumeRows.indices, id: \.self) { (i: Int) in
                LabeledContent {
                    HStack(spacing: 8) {
                        TextField("", text: $volumeRows[i], prompt: Text("/data:/data"))
                            .autocorrectionDisabled()
                        if volumeRows.count > 1 {
                            Button(role: .destructive) {
                                volumeRows.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } label: {
                    Text("Volume")
                }
            }
            Button {
                volumeRows.append("")
            } label: {
                Label("Add Volume", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        }
    }

    private var flagsSection: some View {
        Section("Options") {
            Toggle("Remove container when stopped", isOn: $options.removeOnStop)
            TextField(text: $options.entrypoint, prompt: Text("Override image entrypoint")) {
                Text("Entrypoint")
            }
            .autocorrectionDisabled()
        }
    }

    // MARK: - Action

    private func run() {
        let image = imageReference.trimmingCharacters(in: .whitespaces)
        let name = containerName.trimmingCharacters(in: .whitespaces)
        options.ports = portRows.map { $0.trimmingCharacters(in: .whitespaces) }.filter {
            !$0.isEmpty
        }
        options.envVars = envRows.map { $0.trimmingCharacters(in: .whitespaces) }.filter {
            !$0.isEmpty
        }
        options.volumes = volumeRows.map { $0.trimmingCharacters(in: .whitespaces) }.filter {
            !$0.isEmpty
        }
        isRunning = true
        Task {
            await viewModel.run(image: image, name: name.isEmpty ? nil : name, options: options)
            isRunning = false
            dismiss()
        }
    }
}
