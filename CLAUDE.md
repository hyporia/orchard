# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See `AGENTS.md` for the full project overview, code style rules, and constraints. This file captures only what's not already there.

## Commands

```bash
swift build              # debug build
swift run                # build + launch the app
swift test               # run all tests
swift test --filter <TestClassName.testMethod>   # run a single test
./install_app.sh         # build release, bundle as Orchard.app, copy to ~/Applications
```

Swift 6.0 toolchain, macOS 14+, no external dependencies.

## Architecture notes beyond AGENTS.md

- **`container` CLI discovery**: `ContainerCLI` in `Sources/orchard/Services/ContainerCLI.swift` searches common install paths (homebrew, rancher, orbstack, `~/.local/bin`), then `$PATH`, then falls back to `zsh -lc 'which container'`. The discovered path is cached for the lifetime of the instance; `ContainerCLI.shared` is the process-wide cached instance used by default. One env var overrides this for tests and is evaluated on every call (never cached): `ORCHARD_CONTAINER_PATH=<path>` forces a specific binary. Use this — don't stub `Process` itself.
- **CLI invocation path**: `ContainerCLIProtocol` (injected via init, defaulting to `ContainerCLI.shared`) exposes two seams: `run(arguments:)` for one-shot commands and `streamLogs(containerId:)` for the long-running `logs -f` follow. Both are wrapped by `ContainerService` (`runCommand()` and `streamLogs(containerId:)` respectively), so ViewModels — including `ContainerLogViewModel` — depend only on `ContainerServiceProtocol`, never on the CLI gateway directly. Both throw/finish with `ContainerCLIError.executableNotFound` when the CLI isn't installed. `Process` construction is a private implementation detail of `ContainerCLI` — don't widen it back into the protocol. The AGENTS.md line about invoking via `/usr/bin/env container` is stale.
- **Daemon-stopped handling**: `getSystemStatus()` catches errors and returns `SystemStatus(status: "stopped")` rather than throwing. This is the *only* place that swallows errors intentionally; preserve that behavior.
- **Output format**: All `container` subcommands are invoked with `--format json` and decoded with `JSONDecoder`. When adding a new command, follow the same pattern; don't parse human-readable output.

## Stale references

- `AGENTS.md` points to `CODE_REVIEW.md` for known issues; that file does not exist in the repo. Ignore the reference or remove it if you touch `AGENTS.md`.
