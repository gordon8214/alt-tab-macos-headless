<div align = center>

# AltTab

[![Screenshot](docs/public/demo/frontpage.jpg)](docs/public/demo/frontpage.jpg)

**AltTab** brings the power of Windows alt-tab to macOS

[Official website](https://alt-tab-macos.netlify.app/)<br/><sub>15K stars</sub> | [Download](https://github.com/lwouis/alt-tab-macos/releases/download/v8.3.4/AltTab-8.3.4.zip)<br/><sub>6.7M downloads</sub>
-|-

<div align="right">
  <p>Project supported by</p>
  <a href="https://jb.gg/OpenSource">
    <img src="docs/public/demo/jetbrains.svg" alt="Jetbrains" width="149" height="32">
  </a>
</div>

</div>

## Headless Upstream Sync Check

Run this from a clean working tree to validate whether headless can absorb upstream changes:

```bash
SOURCE_REF=master TARGET_REF=headless scripts/headless/sync_check_from_master.sh
```

The command performs a no-commit merge simulation in a temporary worktree, prints conflict files on failure, and runs the `Headless` build plus `Test` scheme checks on success.

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
