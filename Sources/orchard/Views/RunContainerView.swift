import SwiftUI

struct RunContainerView: View {
    var viewModel: ContainerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var imageReference = ""
    @State private var containerName = ""
    @State private var options = RunContainerOptions()
    @State private var isRunning = false
    @State private var runError: String?

    @State private var portRows: [String] = [""]
    @State private var envRows: [String] = [""]
    @State private var volumeRows: [String] = [""]

    @State private var imageTouched = false
    @State private var nameTouched = false
    @State private var memoryTouched = false
    @State private var cpusTouched = false
    @State private var portsTouched: [Bool] = [false]
    @State private var envsTouched: [Bool] = [false]
    @State private var volumesTouched: [Bool] = [false]

    private enum Field: Hashable {
        case image, name, memory, cpus
        case port(Int), env(Int), volume(Int)
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                if let error = runError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
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
            Text("Image is required.")
                .font(.caption)
                .foregroundStyle(.red)
                .opacity(imageTouched && imageReference.trimmingCharacters(in: .whitespaces).isEmpty ? 1 : 0)
            TextField(text: $containerName, prompt: Text("cool_nginx")) {
                Text("Name")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .name)
            Text("Use letters, numbers, hyphens, and underscores only.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(nameTouched && !containerName.isEmpty && !isValidName(containerName) ? 1 : 0)
        }
    }

    private var resourceSection: some View {
        Section("Resources") {
            TextField(text: $options.memory, prompt: Text("default: 1G")) {
                Text("Memory")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .memory)
            Text("Expected format: 512M, 1G — minimum 200M")
                .font(.caption)
                .foregroundStyle(.red)
                .opacity(memoryTouched && !options.memory.isEmpty && !isValidMemory(options.memory) ? 1 : 0)
            TextField(text: $options.cpus, prompt: Text("2")) {
                Text("CPUs")
            }
            .autocorrectionDisabled()
            .focused($focusedField, equals: .cpus)
            Text("Expected a positive number")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(cpusTouched && !options.cpus.isEmpty && !isValidCpus(options.cpus) ? 1 : 0)
        }
    }

    private var portsSection: some View {
        Section {
            ForEach(portRows.indices, id: \.self) { i in
                portRow(at: i)
            }
            Button {
                portRows.append("")
                portsTouched.append(false)
            } label: {
                Label("Add Port", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        } header: {
            Text("Port Mappings")
        }
    }

    private func portRow(at i: Int) -> some View {
        let invalid = portsTouched.indices.contains(i) && portsTouched[i]
            && !portRows[i].trimmingCharacters(in: .whitespaces).isEmpty
            && !isValidPort(portRows[i])
        return LabeledContent {
            HStack(spacing: 8) {
                TextField("", text: $portRows[i], prompt: Text("8080:80"))
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .port(i))
                    .overlay {
                        if invalid {
                            RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1)
                        }
                    }
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .help("Expected format: hostPort:containerPort, e.g. 8080:80")
                    .opacity(invalid ? 1 : 0)
                if portRows.count > 1 {
                    Button(role: .destructive) {
                        portRows.remove(at: i)
                        portsTouched.remove(at: i)
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

    private var envSection: some View {
        Section("Environment Variables") {
            ForEach(envRows.indices, id: \.self) { i in
                envRow(at: i)
            }
            Button {
                envRows.append("")
                envsTouched.append(false)
            } label: {
                Label("Add Variable", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        }
    }

    private func envRow(at i: Int) -> some View {
        let invalid = envsTouched.indices.contains(i) && envsTouched[i]
            && !envRows[i].trimmingCharacters(in: .whitespaces).isEmpty
            && !isValidEnv(envRows[i])
        return LabeledContent {
            HStack(spacing: 8) {
                TextField("", text: $envRows[i], prompt: Text("DEBUG=true"))
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .env(i))
                    .overlay {
                        if invalid {
                            RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1)
                        }
                    }
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .help("Expected format: KEY=value")
                    .opacity(invalid ? 1 : 0)
                if envRows.count > 1 {
                    Button(role: .destructive) {
                        envRows.remove(at: i)
                        envsTouched.remove(at: i)
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

    private var volumesSection: some View {
        Section("Volumes") {
            ForEach(volumeRows.indices, id: \.self) { i in
                volumeRow(at: i)
            }
            Button {
                volumeRows.append("")
                volumesTouched.append(false)
            } label: {
                Label("Add Volume", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        }
    }

    private func volumeRow(at i: Int) -> some View {
        let invalid = volumesTouched.indices.contains(i) && volumesTouched[i]
            && !volumeRows[i].trimmingCharacters(in: .whitespaces).isEmpty
            && !isValidVolume(volumeRows[i])
        return LabeledContent {
            HStack(spacing: 8) {
                TextField("", text: $volumeRows[i], prompt: Text("/data:/data"))
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .volume(i))
                    .overlay {
                        if invalid {
                            RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1)
                        }
                    }
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .help("Expected format: hostPath:containerPath, e.g. /data:/data")
                    .opacity(invalid ? 1 : 0)
                if volumeRows.count > 1 {
                    Button(role: .destructive) {
                        volumeRows.remove(at: i)
                        volumesTouched.remove(at: i)
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

    private var flagsSection: some View {
        Section("Options") {
            Toggle("Remove container when stopped", isOn: $options.removeOnStop)
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
        case .port(let i): if portsTouched.indices.contains(i) { portsTouched[i] = true }
        case .env(let i): if envsTouched.indices.contains(i) { envsTouched[i] = true }
        case .volume(let i): if volumesTouched.indices.contains(i) { volumesTouched[i] = true }
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
