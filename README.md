# Orchard

A native macOS dashboard for managing [Apple containers](https://github.com/apple/container) via the `container` CLI.

Orchard is a SwiftUI app that gives you a graphical front end for the `container` runtime — manage the daemon, containers, images, and volumes without memorizing CLI flags. It shells out to the official `container` binary and parses its JSON output; it never touches the runtime's files on disk directly.

## Features

- **System** — view daemon status and disk usage, start/stop the container daemon, see the CLI version.
- **Containers** — list, search, start, stop, and delete containers; launch new ones with custom memory, CPU, port mappings, environment variables, volume mounts, and entrypoint.
- **Live stats** — per-container CPU and memory usage, polled every 2 seconds.
- **Live logs** — stream container logs in real time.
- **Images** — list, pull, and delete images.
- **Volumes** — list and delete volumes.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6.0 toolchain (Xcode 16+)
- The [`container`](https://github.com/apple/container) CLI installed on the host

Orchard discovers the `container` binary automatically in common install locations (Homebrew, Rancher, OrbStack, `~/.local/bin`), then `$PATH`, then `zsh -lc 'which container'`.

## Build and run

```bash
swift build              # debug build
swift run                # build + launch the app
swift test               # run all tests
```

The project uses only Apple system frameworks (SwiftUI, Foundation) — there are no external dependencies.

## Install as an app bundle

```bash
./install_app.sh
```

This builds a release binary, bundles it as `Orchard.app` with an icon, and copies it to `~/Applications/Orchard.app`.

## Architecture

MVVM with protocol-based dependency injection.

```
Sources/orchard/
├── orchard.swift              # @main App entry point + AppDelegate
├── Models/                    # Codable data models (ContainerItem, ImageItem, …)
├── Services/
│   └── ContainerService.swift # ContainerServiceProtocol + ContainerService + MockContainerService
├── ViewModels/                # @MainActor @Observable classes, one per section
└── Views/                     # SwiftUI views (ContentView is the root NavigationSplitView)
```

All container operations flow through `ContainerService`, which invokes the `container` CLI with `--format json` and decodes the result. Every ViewModel takes a `ContainerServiceProtocol` via init injection, so `MockContainerService` can drive tests and SwiftUI previews without a running daemon.

For contributor-facing details on code style, concurrency rules, and conventions, see [AGENTS.md](AGENTS.md).

## Testing

Tests live in `Tests/orchardTests/` and use `MockContainerService` so they run without the container daemon.

```bash
swift test                                       # all tests
swift test --filter <TestClass.testMethod>       # a single test
```
