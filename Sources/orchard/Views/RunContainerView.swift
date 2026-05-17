import SwiftUI

struct RunContainerView: View {
    var viewModel: ContainerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var imageReference = ""
    @State private var containerName = ""
    @State private var options = RunContainerOptions()
    @State private var isRunning = false
    @State private var runError: String?

    @State private var portsText = ""
    @State private var envText = ""
    @State private var volumesText = ""

    @State private var imageTouched = false
    @State private var nameTouched = false
    @State private var memoryTouched = false
    @State private var cpusTouched = false
    @State private var portsTouched = false
    @State private var envsTouched = false
    @State private var volumesTouched = false

    private enum Field: Hashable {
        case image, name, memory, cpus
        case ports, envs, volumes
    }

    @FocusState private var focusedField: Field?

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
            .alert("Failed to Run Container", isPresented: Binding(
                get: { runError != nil },
                set: { if !$0 { runError = nil } }
            )) {
                Button("OK", role: .cancel) { runError = nil }
            } message: {
                if let error = runError { Text(error) }
            }
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
                        imageReference.trimmingCharacters(in: .whitespaces).isEmpty
                        || (!options.memory.isEmpty && !isValidMemory(options.memory))
                        || isRunning)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 460)
        .onChange(of: focusedField) { oldValue, _ in
            markTouched(oldValue)
        }
    }

    // MARK: - Sections

    private var imageSection: some View {
        Section("Image") {
            TextField(text: $imageReference, prompt: Text("docker.io/nginx:latest")) {
                Text("Image")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .image)
            if imageTouched && imageReference.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Image is required.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            TextField(text: $containerName, prompt: Text("cool_nginx")) {
                Text("Name")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .name)
            if nameTouched && !containerName.isEmpty && !isValidName(containerName) {
                Text("Use letters, numbers, hyphens, and underscores only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var resourceSection: some View {
        Section("Resources") {
            TextField(text: $options.memory, prompt: Text("default: 1G")) {
                Text("Memory")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .memory)
            if memoryTouched && !options.memory.isEmpty && !isValidMemory(options.memory) {
                Text("Expected format: 512M, 1G — minimum 200M")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            TextField(text: $options.cpus, prompt: Text("2")) {
                Text("CPUs")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .cpus)
            if cpusTouched && !options.cpus.isEmpty && !isValidCpus(options.cpus) {
                Text("Expected a positive number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var portsSection: some View {
        Section("Port Mappings") {
            TextField(text: $portsText, prompt: Text("8080:80, 443:443")) {
                Text("Ports")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .ports)
            if portsTouched && hasInvalidPorts {
                Text("Expected format: hostPort:containerPort, e.g. 8080:80")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var envSection: some View {
        Section("Environment Variables") {
            TextField(text: $envText, prompt: Text("DEBUG=true, PORT=8080")) {
                Text("Variables")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .envs)
            if envsTouched && hasInvalidEnvs {
                Text("Expected format: KEY=value, e.g. DEBUG=true")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var volumesSection: some View {
        Section("Volumes") {
            TextField(text: $volumesText, prompt: Text("/data:/data, /config:/config")) {
                Text("Volumes")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .volumes)
            if volumesTouched && hasInvalidVolumes {
                Text("Expected format: hostPath:containerPath, e.g. /data:/data")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var flagsSection: some View {
        Section("Options") {
            Toggle("Remove container when stopped", isOn: $options.removeOnStop)
        }
    }

    // MARK: - Validation helpers

    private var hasInvalidPorts: Bool {
        portsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .contains { !isValidPort($0) }
    }

    private var hasInvalidEnvs: Bool {
        envText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .contains { !isValidEnv($0) }
    }

    private var hasInvalidVolumes: Bool {
        volumesText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .contains { !isValidVolume($0) }
    }

    // MARK: - Action

    private func run() {
        let image = imageReference.trimmingCharacters(in: .whitespaces)
        let name = containerName.trimmingCharacters(in: .whitespaces)
        options.ports = portsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        options.envVars = envText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        options.volumes = volumesText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        runError = nil
        isRunning = true
        Task {
            do {
                try await viewModel.run(image: image, name: name.isEmpty ? nil : name, options: options)
                dismiss()
            } catch {
                runError = error.localizedDescription
                isRunning = false
            }
        }
    }

    // MARK: - Focus tracking

    private func markTouched(_ field: Field?) {
        switch field {
        case .image: imageTouched = true
        case .name: nameTouched = true
        case .memory: memoryTouched = true
        case .cpus: cpusTouched = true
        case .ports: portsTouched = true
        case .envs: envsTouched = true
        case .volumes: volumesTouched = true
        case nil: break
        }
    }

    // MARK: - Validators

    private func isValidName(_ name: String) -> Bool {
        name.range(of: #"^[a-zA-Z0-9][a-zA-Z0-9_.-]*$"#, options: .regularExpression) != nil
    }

    private func isValidMemory(_ memory: String) -> Bool {
        let pattern = #"^(\d+(?:\.\d+)?)([KMGkmg])$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: memory, range: NSRange(memory.startIndex..., in: memory)),
              let numRange = Range(match.range(at: 1), in: memory),
              let unitRange = Range(match.range(at: 2), in: memory),
              let value = Double(memory[numRange]) else { return false }
        let mb: Double
        switch memory[unitRange].lowercased() {
        case "k": mb = value / 1024
        case "m": mb = value
        case "g": mb = value * 1024
        default: return false
        }
        return mb >= 200
    }

    private func isValidCpus(_ cpus: String) -> Bool {
        guard let value = Double(cpus) else { return false }
        return value > 0
    }

    private func isValidPort(_ port: String) -> Bool {
        port.range(of: #"^\d+(:\d+)?(/tcp|/udp)?$"#, options: .regularExpression) != nil
    }

    private func isValidEnv(_ env: String) -> Bool {
        env.range(of: #"^[a-zA-Z_][a-zA-Z0-9_]*="#, options: .regularExpression) != nil
    }

    private func isValidVolume(_ volume: String) -> Bool {
        volume.contains(":")
    }
}
