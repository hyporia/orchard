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

- **`container` CLI discovery**: `Process.findExecutablePath()` in `Sources/orchard/Process+Extensions.swift` searches common install paths (homebrew, rancher, orbstack, `~/.local/bin`), then `$PATH`, then falls back to `zsh -lc 'which container'`. Two env vars override this for tests: `ORCHARD_CONTAINER_PATH=<path>` forces a specific binary; `ORCHARD_FORCE_NO_CONTAINER=1` simulates a missing binary. Use these — don't stub `Process` itself.
- **CLI invocation path**: `CLIContainerService.runCommand()` calls `Process.containerProcess(arguments:)`, which throws `ContainerProcessError.executableNotFound` when the CLI isn't installed. The AGENTS.md line about invoking via `/usr/bin/env container` is stale — the actual mechanism is `Process.containerProcess`.
- **Daemon-stopped handling**: `getSystemStatus()` catches errors and returns `SystemStatus(status: "stopped")` rather than throwing. This is the *only* place that swallows errors intentionally; preserve that behavior.
- **Output format**: All `container` subcommands are invoked with `--format json` and decoded with `JSONDecoder`. When adding a new command, follow the same pattern; don't parse human-readable output.

## Stale references

- `AGENTS.md` points to `CODE_REVIEW.md` for known issues; that file does not exist in the repo. Ignore the reference or remove it if you touch `AGENTS.md`.
