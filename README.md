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
