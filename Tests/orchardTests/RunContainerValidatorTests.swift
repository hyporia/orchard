import Testing

@testable import orchard

@Suite("RunContainerValidator — field validators")
struct RunContainerValidatorFieldTests {

    // MARK: - Name

    @Test func validNameAlphanumeric() {
        #expect(RunContainerValidator.isValidName("web"))
    }

    @Test func validNameWithSeparators() {
        #expect(RunContainerValidator.isValidName("my-container_1.0"))
    }

    @Test func invalidNameStartsWithSeparator() {
        #expect(!RunContainerValidator.isValidName("-web"))
        #expect(!RunContainerValidator.isValidName("_web"))
        #expect(!RunContainerValidator.isValidName(".web"))
    }

    @Test func invalidNameEmpty() {
        #expect(!RunContainerValidator.isValidName(""))
    }

    @Test func invalidNameContainsSpace() {
        #expect(!RunContainerValidator.isValidName("my container"))
    }

    // MARK: - Memory

    @Test func validMemoryMegabytes() {
        #expect(RunContainerValidator.isValidMemory("512M"))
        #expect(RunContainerValidator.isValidMemory("200M"))
        #expect(RunContainerValidator.isValidMemory("200m"))
    }

    @Test func validMemoryGigabytes() {
        #expect(RunContainerValidator.isValidMemory("1G"))
        #expect(RunContainerValidator.isValidMemory("2g"))
    }

    @Test func validMemoryKilobytesAboveThreshold() {
        // 200 MB = 204800 KB
        #expect(RunContainerValidator.isValidMemory("204800K"))
    }

    @Test func invalidMemoryBelowMinimum() {
        #expect(!RunContainerValidator.isValidMemory("100M"))
        #expect(!RunContainerValidator.isValidMemory("5M"))
    }

    @Test func invalidMemoryBelowMinimumKilobytes() {
        #expect(!RunContainerValidator.isValidMemory("1024K"))
    }

    @Test func invalidMemoryNoUnit() {
        #expect(!RunContainerValidator.isValidMemory("512"))
    }

    @Test func invalidMemoryEmpty() {
        #expect(!RunContainerValidator.isValidMemory(""))
    }

    @Test func invalidMemoryBadUnit() {
        #expect(!RunContainerValidator.isValidMemory("512T"))
    }

    // MARK: - CPUs

    @Test func validCpusInteger() {
        #expect(RunContainerValidator.isValidCpus("2"))
        #expect(RunContainerValidator.isValidCpus("1"))
    }

    @Test func validCpusFractional() {
        #expect(RunContainerValidator.isValidCpus("0.5"))
    }

    @Test func invalidCpusZero() {
        #expect(!RunContainerValidator.isValidCpus("0"))
    }

    @Test func invalidCpusNegative() {
        #expect(!RunContainerValidator.isValidCpus("-1"))
    }

    @Test func invalidCpusNonNumeric() {
        #expect(!RunContainerValidator.isValidCpus("two"))
    }

    // MARK: - Port

    @Test func validPortSimple() {
        #expect(RunContainerValidator.isValidPort("8080"))
    }

    @Test func validPortMapped() {
        #expect(RunContainerValidator.isValidPort("8080:80"))
    }

    @Test func validPortWithProtocol() {
        #expect(RunContainerValidator.isValidPort("8080:80/tcp"))
        #expect(RunContainerValidator.isValidPort("53:53/udp"))
    }

    @Test func invalidPortNonNumeric() {
        #expect(!RunContainerValidator.isValidPort("abc:80"))
    }

    @Test func invalidPortEmpty() {
        #expect(!RunContainerValidator.isValidPort(""))
    }

    // MARK: - Env

    @Test func validEnvSimple() {
        #expect(RunContainerValidator.isValidEnv("FOO=bar"))
    }

    @Test func validEnvWithUnderscoreAndNumbers() {
        #expect(RunContainerValidator.isValidEnv("MY_VAR_2=hello"))
    }

    @Test func validEnvEmptyValue() {
        #expect(RunContainerValidator.isValidEnv("KEY="))
    }

    @Test func invalidEnvNoEquals() {
        #expect(!RunContainerValidator.isValidEnv("FOOBAR"))
    }

    @Test func invalidEnvStartsWithNumber() {
        #expect(!RunContainerValidator.isValidEnv("1FOO=bar"))
    }

    @Test func invalidEnvEmpty() {
        #expect(!RunContainerValidator.isValidEnv(""))
    }

    // MARK: - Volume

    @Test func validVolumeHostContainerPath() {
        #expect(RunContainerValidator.isValidVolume("/host:/container"))
    }

    @Test func validVolumeNamedVolume() {
        #expect(RunContainerValidator.isValidVolume("myvolume:/data"))
    }

    @Test func invalidVolumeNoColon() {
        #expect(!RunContainerValidator.isValidVolume("/hostpath"))
    }

    @Test func invalidVolumeEmpty() {
        #expect(!RunContainerValidator.isValidVolume(""))
    }
}

@Suite("RunContainerValidator — validate()")
struct RunContainerValidatorValidateTests {

    @Test func emptyImageThrows() throws {
        #expect(throws: RunContainerValidationError.emptyImage) {
            try RunContainerValidator.validate(image: "", name: nil, options: RunContainerOptions())
        }
    }

    @Test func whitespaceOnlyImageThrows() throws {
        #expect(throws: RunContainerValidationError.emptyImage) {
            try RunContainerValidator.validate(image: "   ", name: nil, options: RunContainerOptions())
        }
    }

    @Test func invalidNameThrows() throws {
        #expect(throws: RunContainerValidationError.invalidName("-bad")) {
            try RunContainerValidator.validate(image: "nginx", name: "-bad", options: RunContainerOptions())
        }
    }

    @Test func emptyNameIsAllowed() throws {
        try RunContainerValidator.validate(image: "nginx", name: "", options: RunContainerOptions())
    }

    @Test func nilNameIsAllowed() throws {
        try RunContainerValidator.validate(image: "nginx", name: nil, options: RunContainerOptions())
    }

    @Test func invalidMemoryThrows() throws {
        var options = RunContainerOptions()
        options.memory = "5M"
        #expect(throws: RunContainerValidationError.invalidMemory("5M")) {
            try RunContainerValidator.validate(image: "nginx", name: nil, options: options)
        }
    }

    @Test func emptyMemoryIsAllowed() throws {
        var options = RunContainerOptions()
        options.memory = ""
        try RunContainerValidator.validate(image: "nginx", name: nil, options: options)
    }

    @Test func invalidCpusThrows() throws {
        var options = RunContainerOptions()
        options.cpus = "0"
        #expect(throws: RunContainerValidationError.invalidCpus("0")) {
            try RunContainerValidator.validate(image: "nginx", name: nil, options: options)
        }
    }

    @Test func invalidPortThrows() throws {
        var options = RunContainerOptions()
        options.ports = ["abc:80"]
        #expect(throws: RunContainerValidationError.invalidPort("abc:80")) {
            try RunContainerValidator.validate(image: "nginx", name: nil, options: options)
        }
    }

    @Test func emptyPortEntriesAreSkipped() throws {
        var options = RunContainerOptions()
        options.ports = ["", ""]
        try RunContainerValidator.validate(image: "nginx", name: nil, options: options)
    }

    @Test func invalidEnvThrows() throws {
        var options = RunContainerOptions()
        options.envVars = ["NOEQUALS"]
        #expect(throws: RunContainerValidationError.invalidEnv("NOEQUALS")) {
            try RunContainerValidator.validate(image: "nginx", name: nil, options: options)
        }
    }

    @Test func invalidVolumeThrows() throws {
        var options = RunContainerOptions()
        options.volumes = ["/nocolon"]
        #expect(throws: RunContainerValidationError.invalidVolume("/nocolon")) {
            try RunContainerValidator.validate(image: "nginx", name: nil, options: options)
        }
    }

    @Test func validFullOptionsPass() throws {
        var options = RunContainerOptions()
        options.memory = "512M"
        options.cpus = "2"
        options.ports = ["8080:80"]
        options.envVars = ["FOO=bar"]
        options.volumes = ["/host:/container"]
        try RunContainerValidator.validate(image: "nginx:latest", name: "web", options: options)
    }

    @Test func errorDescriptionsAreNonEmpty() {
        let errors: [RunContainerValidationError] = [
            .emptyImage,
            .invalidName("x"),
            .invalidMemory("x"),
            .invalidCpus("x"),
            .invalidPort("x"),
            .invalidEnv("x"),
            .invalidVolume("x"),
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }
}
