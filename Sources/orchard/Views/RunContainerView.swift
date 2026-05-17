import SwiftUI

struct RunContainerView: View {
    var viewModel: ContainerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var imageReference = ""
    @State private var containerName = ""
    @State private var options = RunContainerOptions()
    @State private var isRunning = false

    // Port / env / volume rows as editable strings
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
                    .disabled(imageReference.trimmingCharacters(in: .whitespaces).isEmpty || isRunning)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 380)
    }

    // MARK: - Sections

    private var imageSection: some View {
        Group {
            Section("Image") {
                TextField("e.g. docker.io/nginx:latest", text: $imageReference)
                    .autocorrectionDisabled()
            }
            Section {
                TextField("my-container", text: $containerName)
                    .autocorrectionDisabled()
            } header: {
                Text("Name")
            } footer: {
                Text("Optional. Leave blank for an auto-generated name.")
            }
        }
    }

    private var resourceSection: some View {
        Section("Resources") {
            HStack {
                Text("Memory")
                    .frame(width: 80, alignment: .leading)
                TextField("e.g. 512M, 1G", text: $options.memory)
                    .autocorrectionDisabled()
            }
            HStack {
                Text("CPUs")
                    .frame(width: 80, alignment: .leading)
                TextField("e.g. 1, 2, 4", text: $options.cpus)
                    .autocorrectionDisabled()
            }
        }
    }

    private var portsSection: some View {
        Section {
            ForEach(portRows.indices, id: \.self) { i in
                HStack {
                    TextField("host:container, e.g. 8080:80", text: $portRows[i])
                        .autocorrectionDisabled()
                    if portRows.count > 1 {
                        Button(role: .destructive) { portRows.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            Button {
                portRows.append("")
            } label: {
                Label("Add Port", systemImage: "plus")
            }
        } header: {
            Text("Port Mappings")
        } footer: {
            Text("Format: [host-ip:]host-port:container-port[/protocol]")
        }
    }

    private var envSection: some View {
        Section {
            ForEach(envRows.indices, id: \.self) { i in
                HStack {
                    TextField("KEY=value", text: $envRows[i])
                        .autocorrectionDisabled()
                    if envRows.count > 1 {
                        Button(role: .destructive) { envRows.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            Button {
                envRows.append("")
            } label: {
                Label("Add Variable", systemImage: "plus")
            }
        } header: {
            Text("Environment Variables")
        }
    }

    private var volumesSection: some View {
        Section {
            ForEach(volumeRows.indices, id: \.self) { i in
                HStack {
                    TextField("/host/path:/container/path", text: $volumeRows[i])
                        .autocorrectionDisabled()
                    if volumeRows.count > 1 {
                        Button(role: .destructive) { volumeRows.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            Button {
                volumeRows.append("")
            } label: {
                Label("Add Volume", systemImage: "plus")
            }
        } header: {
            Text("Volumes")
        }
    }

    private var flagsSection: some View {
        Section("Options") {
            Toggle("Remove container when stopped", isOn: $options.removeOnStop)
            HStack {
                Text("Entrypoint")
                    .frame(width: 90, alignment: .leading)
                TextField("Override image entrypoint", text: $options.entrypoint)
                    .autocorrectionDisabled()
            }
        }
    }

    // MARK: - Action

    private func run() {
        let image = imageReference.trimmingCharacters(in: .whitespaces)
        let name = containerName.trimmingCharacters(in: .whitespaces)
        options.ports = portRows.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        options.envVars = envRows.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        options.volumes = volumeRows.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        isRunning = true
        Task {
            await viewModel.run(image: image, name: name.isEmpty ? nil : name, options: options)
            isRunning = false
            dismiss()
        }
    }
}
