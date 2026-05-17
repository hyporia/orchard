# CODE_REVIEW.md

Prioritized list of open improvements. P1 = correctness/safety, P2 = architecture/consistency, P3 = polish/non-idiomatic.

---

## P1 — Correctness / Safety

### Silent error swallow in `ImageViewModel.fetchImages()`
**File:** `Sources/orchard/ViewModels/ImageViewModel.swift:31`
`try?` is used to fetch active containers so the error is converted to `nil` and the "active" column silently shows nothing. Remove `try?` so the error propagates to the existing `catch` block and surfaces via `errorMessage`.

### Silent error swallow in `SystemViewModel.fetchSystemInfo()`
**File:** `Sources/orchard/ViewModels/SystemViewModel.swift:22-23`
`getSystemDiskUsage()` and `getCliVersion()` are called with `try?`, so failures leave disk usage and CLI version silently absent from the UI. Either propagate errors to `errorMessage` or display a dedicated degraded-state label.

### `VolumeItem` declares `Sendable` with a mutable property
**File:** `Sources/orchard/Models/AdditionalModels.swift:28`
`VolumeItem` has `var actualSizeInBytes: Int64?` that is mutated after construction in `ContainerService.fetchVolumes()`. The mutation is currently safe (single thread before return), but the `Sendable` conformance is misleading and fragile. Compute `actualSizeInBytes` at construction time so the struct can be legitimately immutable.

### `ContainerLogViewModel.startStreaming()` calls `process.run()` on `@MainActor`
**File:** `Sources/orchard/ViewModels/ContainerLogViewModel.swift:49`
`startStreaming()` is a synchronous `@MainActor` function that calls `process.run()` directly. While `run()` returns immediately, process initialization can cause measurable main-thread work. Move setup into an `async` method and dispatch the blocking portion to a background thread, consistent with `CLIContainerService.runCommand()`.

### `getSystemStatus()` is marked `throws` but never throws
**File:** `Sources/orchard/Services/ContainerService.swift:154-162`
The method catches all errors internally and returns a fallback value, so the `throws` annotation is misleading — callers can safely remove their `try`. Either drop `throws` from the signature or remove the internal catch and let errors propagate consistently with other service methods. CLAUDE.md documents the swallowing as intentional, so drop `throws`.

---

## P2 — Architecture / Consistency

### `VolumeListView` missing loading state on delete
**File:** `Sources/orchard/Views/VolumeListView.swift:109`
The delete action fires `viewModel.delete(name:)` with no loading state, leaving the button enabled during deletion. `ContainerRow` and `ImageListView` both gate destructive actions behind an `isDeleting` flag. Add the same pattern here.

### Redundant `isLoading = false` in `ImageViewModel.fetchImages()`
**File:** `Sources/orchard/ViewModels/ImageViewModel.swift:26`
The early-return branch on line 26 sets `isLoading = false` explicitly, but the unconditional statement at the end of the method does the same. Remove the redundant assignment from the early-return branch.

---

## P3 — Polish / Non-idiomatic

### `@State` used for reference-type ViewModels in `ContentView`
**File:** `Sources/orchard/Views/ContentView.swift:5-8`
ViewModels are `@Observable` classes (reference types) stored as `@State`, which is semantically intended for value types. This works but is non-idiomatic for Swift 6 + `@Observable`. The idiomatic pattern is to store them as plain stored properties and initialize them in `init()` without `@State`. (Low risk — change only when touching `ContentView` for another reason.)

### `OrchardApp` hardcodes `CLIContainerService`
**File:** `Sources/orchard/orchard.swift:13`
The root app struct instantiates `CLIContainerService()` directly with no injection point. This makes full-app UI testing or Xcode Previews with a mock impossible at the app level. Add a `service: ContainerServiceProtocol = CLIContainerService()` parameter and thread it through.

### `findExecutablePath()` is undocumented as background-only
**File:** `Sources/orchard/Process+Extensions.swift:63-64`
The function calls `process.run()` + `waitUntilExit()` synchronously and must only be called from a background thread. It is currently safe because `CLIContainerService.runCommand()` dispatches to `DispatchQueue.global()` before calling it, but there is no doc comment or assertion enforcing this. Add a comment making the constraint explicit.

---

## Fixed

- **`RunContainerView` dismissed sheet on failure** — `run()` now `throws`; the sheet stays open and shows an inline error banner on failure. Dismissed only on success. Fixed in commit `780d9b4`-era work.
