# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository now contains two build targets:

1. **`alt-tab-macos` (GUI)**: the original Swift/AppKit AltTab window switcher.
2. **`alt-tab-headless` (headless)**: a CLI/daemon-focused variant that reuses the shared window-tracking core and outputs window lists as JSON.

The headless target is intentionally additive (overlay + shims) so window-discovery and switching logic can stay in sync with upstream AltTab changes. The project is **not** a SwiftUI app.

## Build & Development

### Prerequisites
- Run `scripts/codesign/setup_local.sh` once to generate a local self-signed certificate (avoids re-checking Security & Privacy permissions on every build)
- Dependencies are managed via CocoaPods (`pod install`); always open `alt-tab-macos.xcworkspace` (not `.xcodeproj`)

### Build Commands
```bash
# Headless build
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Headless

# Debug build
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug

# Release build
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Release -derivedDataPath DerivedData

# Run tests
xcodebuild test -workspace alt-tab-macos.xcworkspace -scheme Test -configuration Release
```

### Upstream Sync Check
Use this manual command to validate whether headless can cleanly absorb `master`:

```bash
SOURCE_REF=master TARGET_REF=headless scripts/headless/sync_check_from_master.sh
```

Behavior:
- Fails immediately if your working tree is dirty.
- Performs a no-commit merge dry run of `SOURCE_REF` into `TARGET_REF` in a temporary worktree.
- Prints unresolved conflict file paths if merge conflicts occur.
- On clean merge, runs `Headless` build and `Test` scheme checks before reporting success.
- Cleans up temporary worktree automatically on success/failure.

### Formatting
- SwiftFormat is configured via `.swiftformat` (max line width 110, Swift 5.8)
- SwiftFormat is currently **disabled project-wide** via `.swiftformatignore` (`**/*`), but the config exists for future use
- Run `npm run format` to format, `npm run format:check` to lint

### Commit Convention
Commits follow [Conventional Commits](https://www.conventionalcommits.org/) enforced by commitlint (e.g. `fix:`, `feat:`, `chore:`).

## Compiler Settings
- `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` — all warnings are errors; code must compile warning-free
- Debug builds enable slow compilation diagnostics (`-warn-long-function-bodies=250 -warn-long-expression-type-checking=250`)
- Deployment target: macOS 10.12

## Architecture

### Entry Point & App Lifecycle
- `src/main.swift` — entry point; sets up signal handlers and starts `App.shared.run()`
- `src/ui/App.swift` — `App` (subclass of `NSApplication`) is the application delegate and central coordinator. It manages the thumbnail panel, preview panel, preferences window, and permissions window. `applicationDidFinishLaunching` initializes the system, checks permissions, then calls `continueAppLaunchAfterPermissionsAreGranted()` to start all background work and event observers
- `src/headless/main.swift` — headless entry point; runs as daemon with no args, or as CLI client for `--list` / `--detailed-list`
- `src/headless/App.swift` — headless app delegate; starts only the services required for app/window discovery and CLI message-port handling (no visible UI)

### Source Layout (`src/`)
| Directory | Purpose |
|-----------|---------|
| `api-wrappers/` | Wrappers around C/ObjC APIs — AXUIElement, CGWindow, CGWindowID, Mission Control state |
| `api-wrappers/private-apis/` | Reverse-engineered private macOS frameworks (SkyLight, HIServices) |
| `logic/` | Business logic — Application/Window models, Preferences, Spaces, Screens, keyboard/shortcut handling |
| `logic/events/` | Event observers — keyboard, mouse, trackpad, accessibility, Spaces, screens, dock, CLI, scrollwheel |
| `headless/` | Headless overlay — daemon entrypoint, list-only CLI server/client, readiness gate, and shims for UI/permission/capture/input symbols |
| `ui/` | All UI — main thumbnail window, preferences window, permissions window, feedback window |
| `ui/main-window/` | The alt-tab overlay — ThumbnailsPanel, ThumbnailsView, ThumbnailView, PreviewPanel |
| `ui/preferences-window/` | Preferences tabs (General, Appearance, Controls, Blacklists, Policies, About, Acknowledgments) |
| `ui/generic-components/` | Reusable AppKit components (buttons, switches, table views, etc.) |

### Headless CLI Contract
- Supported commands: `--list`, `--detailed-list`, `--help`
- Unsupported in headless: `--focus=...`, `--focusUsingLastFocusOrder=...`, `--show=...` (explicit non-zero error)
- Daemon/client IPC port: `com.lwouis.alt-tab-macos.headless.cli` (separate from GUI app port)
- Readiness behavior: list commands wait up to 5 seconds for initial discovery, then return explicit warm-up timeout error
- Permission behavior: headless daemon fails fast when Accessibility permission is missing

### Threading Model
`BackgroundWork` manages all threads and queues:
- **Dedicated RunLoop threads**: accessibility events, keyboard/mouse/trackpad input, Mission Control, CLI events
- **OperationQueues**: screenshots (8 concurrent), AX commands (4), AX calls first-attempt/retries/manual-discovery (8 each), key repeat (1), crash reports (1)
- The process respects a soft limit of ~45 threads (macOS limit is 64)
- UI updates happen on the main thread

### Key Models
- `Window` — represents a macOS window with its AX element, title, thumbnail, space IDs, and state
- `Application` — represents a running app, tracks its windows and AX observer
- `Windows` (plural) — static class managing the list of all tracked windows, selection, sorting, filtering
- `Applications` — static class managing all tracked applications, initial discovery via `NSWorkspace`
- `Preferences` — static class with all user preferences stored in `UserDefaults`
- `Spaces` / `Screens` — track macOS Spaces and display configuration

### Private APIs
The app uses private macOS APIs from `SkyLight.framework` and `ApplicationServices.HIServices.framework` for features not available through public APIs (e.g., Space management, native command-tab control). These are declared in `src/api-wrappers/private-apis/` and bridged via the ObjC bridging header. They are undocumented and may break between macOS versions.

### CocoaPods Dependencies
- **Sparkle** — auto-update framework
- **ShortcutRecorder** — keyboard shortcut recording UI
- **LetsMove** — prompts user to move app to /Applications
- **AppCenter/Crashes** — crash reporting
- **SwiftyBeaver** — logging

### Build Configurations
Defined in `config/*.xcconfig` files:
- `debug.xcconfig` — local self-signed codesign, incremental compilation, `#if DEBUG` flag
- `release.xcconfig` — Developer ID signing, whole-module optimization, notarization flags
- `headless-debug.xcconfig` — headless target debug config and source exclusions
- `headless-release.xcconfig` — headless target release config and source exclusions
- `test-base.xcconfig` — no codesign, active arch only

### Testing
- Unit tests live in `unit-tests/` and run via the `Test` Xcode scheme
- QA is primarily manual due to deep OS integration (accessibility, Spaces, multi-monitor)
