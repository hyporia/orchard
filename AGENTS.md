# AGENTS.md

## Project overview

Orchard is a native macOS SwiftUI dashboard for managing Apple containers via the `container` CLI. It targets **macOS 14+ (Sonoma)** and is built with **Swift 6.0** (strict concurrency enabled by default).

The app manages containers, images, volumes, and the container daemon lifecycle — all through shell invocations of the `container` CLI tool (located via `/usr/bin/env`).

## Build and run

```bash
# Build (debug)
swift build

# Run
swift run

# Run tests
swift test
```

There are no external dependencies — the project uses only Apple system frameworks (SwiftUI, Foundation).

## Architecture

MVVM with protocol-based dependency injection.

```
Sources/orchard/
├── orchard.swift              # @main App entry point + AppDelegate
├── Models/                    # Data models (Codable structs)
│   ├── ContainerItem.swift    # Container model
│   ├── AdditionalModels.swift # ImageItem, VolumeItem, ContainerStat, etc.
│   └── SystemModel.swift      # SystemStatus, SystemDiskUsage
├── Services/
│   └── ContainerService.swift # ContainerServiceProtocol + ContainerService + MockContainerService
├── ViewModels/                # @MainActor ObservableObject classes
│   ├── ContainerViewModel.swift
│   ├── ContainerLogViewModel.swift
│   ├── ImageViewModel.swift
│   ├── SystemViewModel.swift
│   └── VolumeViewModel.swift
└── Views/                     # SwiftUI views
    ├── ContentView.swift      # Root NavigationSplitView with sidebar
    ├── ContainerRow.swift     # Single container row with actions
    ├── ContainerLogView.swift # Live log streaming view
    ├── ImageListView.swift
    ├── SystemView.swift
    └── VolumeListView.swift
```

## Code style and conventions

- **Swift 6 strict concurrency**: All ViewModels are `@MainActor`. Models crossing actor boundaries must be `Sendable`. Use `@Sendable` closures and `Task { @MainActor in }` instead of `DispatchQueue.main.async`.
- **Blocking work**: Never run `Process.run()` / `waitUntilExit()` directly in `async` contexts. Wrap in `withCheckedThrowingContinuation` + `DispatchQueue.global()` to avoid starving the cooperative thread pool.
- **DI pattern**: All ViewModels accept a `ContainerServiceProtocol` via init injection. Use `MockContainerService` for tests and previews.
- **CLI interaction**: All container operations go through `ContainerService.runCommand()` which invokes `/usr/bin/env container <args>`. Never read container runtime files directly from disk.
- **Error handling**: Surface errors via ViewModel `errorMessage` properties. Don't silently swallow errors with `try?` or empty catch blocks returning `[]`.
- **Naming**: Models use `Item` suffix (e.g. `ContainerItem`, `ImageItem`). ViewModels use `ViewModel` suffix. Views match their content (e.g. `ContainerRow`, `ImageListView`).

## Testing

- Tests live in `Tests/orchardTests/`.
- Use `MockContainerService` (defined in `ContainerService.swift`) for unit testing ViewModels without requiring the container daemon.
- Run `swift test` to execute all tests.

## Key constraints

- **macOS 14+ only** — you can use `ContentUnavailableView`, `@Observable`, `foregroundStyle`, and other Sonoma-era APIs.
- **No third-party dependencies** — keep it that way unless explicitly approved.
- **The `container` CLI must be installed** on the host for the app to function. The app gracefully handles the daemon being stopped (returns a default `SystemStatus(status: "stopped")`).

## Known issues

See `CODE_REVIEW.md` for a prioritized list of open improvements covering concurrency, modern API adoption, architecture, and polish.
