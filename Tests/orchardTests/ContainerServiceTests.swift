import Foundation
import Testing

@testable import orchard

// MARK: - Process service mock

/// Mock for `ContainerCLIProtocol`.
///
/// Records every `run(arguments:)` invocation and returns either a stubbed
/// string, a stubbed error, or the result of a per-call handler. Thread-safe
/// (NSLock-guarded) so it satisfies the `Sendable` requirement of the protocol.
private final class MockContainerCLI: ContainerCLIProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _invocations: [[String]] = []
    private var _output: String = ""
    private var _error: Error?
    private var _handler: (@Sendable ([String]) throws -> String)?
    private var _streamChunks: [String] = []
    private var _streamError: Error?
    private var _streamedContainerIds: [String] = []

    /// Every argument array passed to `run`, in call order.
    var invocations: [[String]] {
        lock.withLock { _invocations }
    }

    var lastArguments: [String]? {
        lock.withLock { _invocations.last }
    }

    /// Every container id passed to `streamLogs`, in call order.
    var streamedContainerIds: [String] {
        lock.withLock { _streamedContainerIds }
    }

    func stub(output: String) {
        lock.withLock {
            _output = output
            _error = nil
            _handler = nil
        }
    }

    func stub(error: Error) {
        lock.withLock {
            _error = error
            _handler = nil
        }
    }

    func stub(handler: @escaping @Sendable ([String]) throws -> String) {
        lock.withLock {
            _handler = handler
            _error = nil
        }
    }

    /// Stubs the chunks `stream` will yield, optionally finishing with an error.
    func stub(streamChunks: [String], thenError error: Error? = nil) {
        lock.withLock {
            _streamChunks = streamChunks
            _streamError = error
        }
    }

    func streamLogs(containerId: String) -> AsyncThrowingStream<String, Error> {
        let (chunks, error): ([String], Error?) = lock.withLock {
            _streamedContainerIds.append(containerId)
            return (_streamChunks, _streamError)
        }
        return AsyncThrowingStream<String, Error> { continuation in
            for chunk in chunks { continuation.yield(chunk) }
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }

    func run(arguments: [String]) async throws -> String {
        let (handler, error, output):
            (
                (@Sendable ([String]) throws -> String)?, Error?, String
            ) = lock.withLock {
                _invocations.append(arguments)
                return (_handler, _error, _output)
            }

        if let handler { return try handler(arguments) }
        if let error { throw error }
        return output
    }
}

private enum TestError: Error { case boom }

private func makeService() -> (ContainerService, MockContainerCLI) {
    let mock = MockContainerCLI()
    return (ContainerService(cli: mock), mock)
}

// MARK: - JSON fixtures

private enum JSON {
    static func container(id: String, name: String?, image: String?, status: String?) -> String {
        var config = "\"id\":\"\(id)\""
        if let name { config += ",\"name\":\"\(name)\"" }
        if let image { config += ",\"image\":{\"reference\":\"\(image)\"}" }
        var obj = "{\"configuration\":{\(config)}"
        if let status { obj += ",\"status\":\"\(status)\"" }
        obj += "}"
        return obj
    }
}

// MARK: - Container listing & stats

@Suite("ContainerService — containers")
struct ContainerServiceContainerTests {

    @Test func fetchContainersDecodesJSONArray() async throws {
        let (service, mock) = makeService()
        let json = """
            [\(JSON.container(id: "abc", name: "web", image: "nginx:latest", status: "running")),\
            \(JSON.container(id: "def", name: nil, image: nil, status: "stopped"))]
            """
        mock.stub(output: json)

        let items = try await service.fetchContainers()

        #expect(mock.lastArguments == ["ls", "-a", "--format", "json"])
        #expect(items.count == 2)
        #expect(items[0].id == "abc")
        #expect(items[0].names == "web")
        #expect(items[0].image == "nginx:latest")
        #expect(items[0].state == "running")
        #expect(items[0].status == "Running")
        // name/image fall back to id / "unknown" when absent.
        #expect(items[1].names == "def")
        #expect(items[1].image == "unknown")
    }

    @Test func fetchContainersFallsBackToNDJSON() async throws {
        let (service, mock) = makeService()
        // Newline-delimited objects (not wrapped in an array) force the
        // line-by-line fallback path.
        let ndjson = """
            \(JSON.container(id: "one", name: "one", image: "alpine", status: "running"))
            \(JSON.container(id: "two", name: "two", image: "alpine", status: "running"))
            """
        mock.stub(output: ndjson)

        let items = try await service.fetchContainers()

        #expect(items.map(\.id) == ["one", "two"])
    }

    @Test func fetchContainersReturnsEmptyForEmptyOutput() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        let items = try await service.fetchContainers()

        #expect(items.isEmpty)
    }

    @Test func fetchContainersThrowsOnGarbageOutput() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "not json at all")

        await #expect(throws: (any Error).self) {
            _ = try await service.fetchContainers()
        }
    }

    @Test func fetchContainersPropagatesProcessError() async throws {
        let (service, mock) = makeService()
        mock.stub(error: ContainerCLIError.executableNotFound)

        await #expect(throws: ContainerCLIError.self) {
            _ = try await service.fetchContainers()
        }
    }

    @Test func fetchStatsDecodesArray() async throws {
        let (service, mock) = makeService()
        mock.stub(
            output: """
                [{"id":"c1","cpuUsageUsec":1000,"memoryUsageBytes":2048,"numProcesses":3}]
                """)

        let stats = try await service.fetchStats()

        #expect(mock.lastArguments == ["stats", "--no-stream", "--format", "json"])
        #expect(stats.count == 1)
        #expect(stats[0].id == "c1")
        #expect(stats[0].cpuUsageUsec == 1000)
        #expect(stats[0].memoryUsageBytes == 2048)
        #expect(stats[0].numProcesses == 3)
        #expect(stats[0].blockReadBytes == nil)
    }

    @Test func fetchStatsHandlesEmptyArray() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "[]")

        let stats = try await service.fetchStats()

        #expect(stats.isEmpty)
    }
}

// MARK: - Container lifecycle

@Suite("ContainerService — lifecycle")
struct ContainerServiceLifecycleTests {

    @Test func startContainerSendsCorrectArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.startContainer(id: "abc123")

        #expect(mock.lastArguments == ["start", "abc123"])
    }

    @Test func stopContainerSendsCorrectArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.stopContainer(id: "abc123")

        #expect(mock.lastArguments == ["stop", "abc123"])
    }

    @Test func deleteContainerSendsCorrectArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.deleteContainer(id: "abc123")

        #expect(mock.lastArguments == ["rm", "abc123"])
    }

    @Test func startContainerPropagatesError() async throws {
        let (service, mock) = makeService()
        mock.stub(error: ContainerCLIError.processFailed("no such container"))

        let thrown = await #expect(throws: ContainerCLIError.self) {
            try await service.startContainer(id: "missing")
        }
        if case .processFailed(let msg) = thrown {
            #expect(msg == "no such container")
        } else {
            Issue.record("expected .processFailed, got \(String(describing: thrown))")
        }
    }

    @Test func runContainerThrowsValidationErrorBeforeInvokingCLI() async throws {
        let (service, mock) = makeService()
        var options = RunContainerOptions()
        options.memory = "5M"

        await #expect(throws: RunContainerValidationError.self) {
            try await service.runContainer(image: "nginx", name: nil, options: options)
        }
        #expect(mock.invocations.isEmpty)
    }

    @Test func runContainerWithDefaultOptionsSendsMinimalArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.runContainer(
            image: "nginx:latest", name: nil, options: RunContainerOptions())

        #expect(mock.lastArguments == ["run", "-d", "nginx:latest"])
    }

    @Test func runContainerWithEmptyNameOmitsNameFlag() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.runContainer(
            image: "nginx", name: "", options: RunContainerOptions())

        #expect(mock.lastArguments == ["run", "-d", "nginx"])
    }

    @Test func runContainerWithAllOptionsBuildsFullArgumentList() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        var options = RunContainerOptions()
        options.memory = "512M"
        options.cpus = "2"
        options.ports = ["8080:80", "9090:90", ""]  // empty entries are skipped
        options.envVars = ["FOO=bar", ""]
        options.volumes = ["/host:/container", ""]
        options.removeOnStop = true
        options.entrypoint = "/bin/sh"

        try await service.runContainer(image: "myimage", name: "web", options: options)

        #expect(
            mock.lastArguments == [
                "run", "-d",
                "--name", "web",
                "--memory", "512M",
                "--cpus", "2",
                "--publish", "8080:80",
                "--publish", "9090:90",
                "--env", "FOO=bar",
                "--volume", "/host:/container",
                "--rm",
                "--entrypoint", "/bin/sh",
                "myimage",
            ])
    }
}

// MARK: - System

@Suite("ContainerService — system")
struct ContainerServiceSystemTests {

    @Test func getSystemStatusDecodesResponse() async throws {
        let (service, mock) = makeService()
        mock.stub(output: #"{"status":"running","apiServerVersion":"1.2.3"}"#)

        let status = try await service.getSystemStatus()

        #expect(mock.lastArguments == ["system", "status", "--format", "json"])
        #expect(status.status == "running")
        #expect(status.apiServerVersion == "1.2.3")
    }

    @Test func getSystemStatusReturnsStoppedOnError() async throws {
        let (service, mock) = makeService()
        mock.stub(error: ContainerCLIError.processFailed("daemon not running"))

        // This is the one method that intentionally swallows errors.
        let status = try await service.getSystemStatus()

        #expect(status.status == "stopped")
        #expect(status.apiServerVersion == nil)
    }

    @Test func getSystemStatusReturnsStoppedOnGarbageOutput() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "not json")

        let status = try await service.getSystemStatus()

        #expect(status.status == "stopped")
    }

    @Test func getSystemDiskUsageDecodesResponse() async throws {
        let (service, mock) = makeService()
        let stat = #"{"active":2,"reclaimable":100,"sizeInBytes":4096,"total":3}"#
        mock.stub(
            output: """
                {"containers":\(stat),"images":\(stat),"volumes":\(stat)}
                """)

        let usage = try await service.getSystemDiskUsage()

        #expect(mock.lastArguments == ["system", "df", "--format", "json"])
        #expect(usage.containers.active == 2)
        #expect(usage.images.reclaimable == 100)
        #expect(usage.volumes.sizeInBytes == 4096)
        #expect(usage.containers.total == 3)
    }

    @Test func getSystemDiskUsageThrowsOnGarbage() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "garbage")

        await #expect(throws: (any Error).self) {
            _ = try await service.getSystemDiskUsage()
        }
    }

    @Test func getSystemStatusFlagsCliMissing() async throws {
        let (service, mock) = makeService()
        mock.stub(error: ContainerCLIError.executableNotFound)

        let status = try await service.getSystemStatus()

        #expect(status.cliMissing == true)
        #expect(status.status == "stopped")
    }

    @Test func getSystemStatusDoesNotFlagCliMissingForDaemonError() async throws {
        let (service, mock) = makeService()
        mock.stub(error: ContainerCLIError.processFailed("daemon not running"))

        let status = try await service.getSystemStatus()

        #expect(status.cliMissing == false)
        #expect(status.status == "stopped")
    }

    @Test func getCliVersionTrimsWhitespace() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "container CLI version 0.4.1\n")

        let version = try await service.getCliVersion()

        #expect(mock.lastArguments == ["--version"])
        #expect(version == "container CLI version 0.4.1")
    }

    @Test func startSystemSendsCorrectArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.startSystem()

        #expect(mock.lastArguments == ["system", "start"])
    }

    @Test func stopSystemSendsCorrectArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.stopSystem()

        #expect(mock.lastArguments == ["system", "stop"])
    }
}

// MARK: - Images

@Suite("ContainerService — images")
struct ContainerServiceImageTests {

    @Test func fetchImagesDecodesResponse() async throws {
        let (service, mock) = makeService()
        mock.stub(
            output: """
                [{"reference":"nginx:latest","fullSize":"100MB",\
                "descriptor":{"size":12345,"digest":"sha256:abc"}}]
                """)

        let images = try await service.fetchImages()

        #expect(mock.lastArguments == ["image", "ls", "--format", "json"])
        #expect(images.count == 1)
        #expect(images[0].reference == "nginx:latest")
        #expect(images[0].id == "nginx:latest")
        #expect(images[0].fullSize == "100MB")
        #expect(images[0].descriptor?.size == 12345)
        #expect(images[0].descriptor?.digest == "sha256:abc")
    }

    @Test func fetchImagesReturnsEmptyForEmptyArray() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "[]")

        let images = try await service.fetchImages()

        #expect(images.isEmpty)
    }

    @Test func deleteImageSendsCorrectArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.deleteImage(reference: "nginx:latest")

        #expect(mock.lastArguments == ["image", "rm", "nginx:latest"])
    }

    @Test func pullImageSendsCorrectArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.pullImage(reference: "redis:7")

        #expect(mock.lastArguments == ["image", "pull", "redis:7"])
    }

    @Test func pullImagePropagatesError() async throws {
        let (service, mock) = makeService()
        mock.stub(error: TestError.boom)

        await #expect(throws: TestError.self) {
            try await service.pullImage(reference: "bad/ref")
        }
    }
}

// MARK: - Volumes

@Suite("ContainerService — volumes")
struct ContainerServiceVolumeTests {

    @Test func fetchVolumesDecodesResponse() async throws {
        let (service, mock) = makeService()
        mock.stub(
            output: """
                [{"name":"data","format":"ext4","driver":"local",\
                "source":"/nonexistent/path/\(UUID().uuidString)","sizeInBytes":1024}]
                """)

        let volumes = try await service.fetchVolumes()

        #expect(mock.lastArguments == ["volume", "ls", "--format", "json"])
        #expect(volumes.count == 1)
        #expect(volumes[0].name == "data")
        #expect(volumes[0].id == "data")
        #expect(volumes[0].format == "ext4")
        #expect(volumes[0].sizeInBytes == 1024)
        // A non-existent source leaves on-disk size unresolved.
        #expect(volumes[0].actualSizeInBytes == nil)
    }

    @Test func fetchVolumesResolvesActualSizeForRealFile() async throws {
        let (service, mock) = makeService()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("orchard-test-\(UUID().uuidString).bin")
        try Data(repeating: 0xAB, count: 8192).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        mock.stub(
            output: """
                [{"name":"vol","source":"\(tmp.path)"}]
                """)

        let volumes = try await service.fetchVolumes()

        #expect(volumes.count == 1)
        let actual = try #require(volumes[0].actualSizeInBytes)
        #expect(actual > 0)
    }

    @Test func fetchVolumesHandlesNilSource() async throws {
        let (service, mock) = makeService()
        mock.stub(output: #"[{"name":"vol"}]"#)

        let volumes = try await service.fetchVolumes()

        #expect(volumes.count == 1)
        #expect(volumes[0].source == nil)
        #expect(volumes[0].actualSizeInBytes == nil)
    }

    @Test func deleteVolumeSendsCorrectArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(output: "")

        try await service.deleteVolume(name: "data")

        #expect(mock.lastArguments == ["volume", "rm", "data"])
    }
}

// MARK: - Log streaming

@MainActor
@Suite("ContainerLogViewModel")
struct ContainerLogViewModelTests {

    @Test func streamingAppendsChunksAndSendsLogArguments() async throws {
        let (service, mock) = makeService()
        mock.stub(streamChunks: ["line one\n", "line two\n"])
        let vm = ContainerLogViewModel(containerId: "abc123", service: service)

        vm.startStreaming()
        await vm.streamTask?.value

        #expect(mock.streamedContainerIds == ["abc123"])
        #expect(vm.logs.contains("line one\n"))
        #expect(vm.logs.contains("line two\n"))
    }

    @Test func streamingSurfacesErrorInLogs() async throws {
        let (service, mock) = makeService()
        mock.stub(streamChunks: [], thenError: ContainerCLIError.executableNotFound)
        let vm = ContainerLogViewModel(containerId: "abc", service: service)

        vm.startStreaming()
        await vm.streamTask?.value

        #expect(vm.logs.contains("Error starting process:"))
    }

    @Test func stopStreamingClearsTask() async throws {
        let (service, mock) = makeService()
        mock.stub(streamChunks: ["x\n"])
        let vm = ContainerLogViewModel(containerId: "abc", service: service)

        vm.startStreaming()
        await vm.streamTask?.value
        vm.stopStreaming()

        #expect(vm.streamTask == nil)
    }

    @Test func logsAreTruncatedWhenExceedingCap() async throws {
        let (service, mock) = makeService()
        let chunk = String(repeating: "x", count: 30_000)
        mock.stub(streamChunks: [chunk, chunk, chunk])
        let vm = ContainerLogViewModel(containerId: "cap-test", service: service)

        vm.startStreaming()
        await vm.streamTask?.value

        #expect(vm.logs.count <= 50_000)
    }
}
