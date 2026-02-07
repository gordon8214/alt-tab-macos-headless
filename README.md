# AltTab Headless

This fork of [AltTab](https://github.com/lwouis/alt-tab-macos) provides a light-weight "headless" implementation of the core window-switching functionality for use via the CLI. It has no UI and allows for the core window 

[![Screenshot](docs/public/demo/frontpage.jpg)](docs/public/demo/frontpage.jpg)

**AltTab** brings the power of Windows alt-tab to macOS

[Official website](https://alt-tab-macos.netlify.app/) | [Download](https://github.com/lwouis/alt-tab-macos/releases/download/v8.3.4/AltTab-8.3.4.zip)

## Headless Upstream Sync Check

Run this from a clean working tree to validate whether headless can absorb upstream changes:

```bash
SOURCE_REF=master TARGET_REF=headless scripts/headless/sync_check_from_master.sh
```

The command performs a no-commit merge simulation in a temporary worktree, prints conflict files on failure, and runs the `Headless` build plus `Test` scheme checks on success.

## Headless Runtime Guard

`AltTabHeadless` and the full GUI `AltTab` app are mutually exclusive at startup.

- Headless checks whether `com.lwouis.alt-tab-macos` is already running.
- If a conflict is found, headless shows a critical alert and exits with status code `1` before starting background services.

## Headless CLI Commands

`AltTabHeadless` supports:

- `--list`: return JSON window list (`id`, `title`)
- `--detailed-list`: return JSON window list with detailed metadata
- `--focus=<window_id>`: focus a window by `id`
- `--focusUsingLastFocusOrder=<focus_order>`: focus by `lastFocusOrder` from `--detailed-list`
- `--show=<shortcut_index>`: one-shot shortcut-aware cycle-and-focus action (headless equivalent of triggering a shortcut)
- `--help`: print usage

Run with no arguments to start the headless daemon. List/focus/show commands wait up to 5 seconds for initial discovery, then return a warm-up timeout if still not ready.
Malformed focus/show payloads (for example `--focus=abc` or `--show=9`) are treated as invalid commands and return the generic command error response.

## Team Signing Overrides (Distribution Builds)

Use a local xcconfig override so teammates can build properly signed release binaries without editing tracked upstream files.

Run from the repository root:

```bash
scripts/codesign/setup_team_signing_overrides.sh
```

Then edit `config/signing-overrides.local.xcconfig` and set:
- `DEVELOPMENT_TEAM`
- `CODE_SIGN_IDENTITY` (Developer ID Application certificate)

Validate that placeholders were replaced:

```bash
scripts/codesign/setup_team_signing_overrides.sh --check
```

Build signed release binaries with standard commands:

```bash
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Release -configuration Release
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Headless -configuration Release
```

`config/signing-overrides.local.xcconfig` is gitignored, and both release xcconfigs now optionally include it, so upstream merges remain low-friction.
