# OverflowBar 1.0.18 — Compatibility Replacement

OverflowBar 1.0.18 is the compatibility replacement for users who could not
use the previous latest stable release. It contains the macOS 26 hiding and
re-hide fixes from the validated compatibility build.

## Fixed

- Stabilized Control Center composite-host detection on macOS 26 so layout
  operations target real draggable status-item windows.
- Preserved automatic-hide requests across WindowServer refreshes and
  re-scanned after application activation so newly-created menu-bar windows
  are hidden again.
- Extended bounded startup retries for newly-installed ad-hoc builds and kept
  synthetic drag points on an active display.

## Verification

- Installed `/Applications/OverflowBar.app` on macOS 26 and completed a clean
  single-instance run.
- Captured 6 of 6 real menu-bar icons through the macOS 26 compatibility path.
- Verified successful hide moves for the selected icons and subsequent re-hide
  after activation.
- Release build, DMG verification, and SHA-256 checks are included with the
  release assets.

## Important for affected users

- This community build is ad-hoc signed and is not notarized with an Apple
  Developer ID. macOS may require Control-click → **Open** on first launch.
- Because ad-hoc builds have a new code-signing identity, macOS may require
  fresh Accessibility and Screen Recording authorization for this version.
  Open OverflowBar Settings and use **Request** for each permission if the
  status is not granted.
- Do not use an older `com.overflowbar.app` copy at the same time. Replace it
  with this build in `/Applications` before granting permissions.

## Install

1. Download `OverflowBar-1.0.18.dmg` below.
2. Drag OverflowBar to Applications and replace the older copy.
3. Open OverflowBar, complete the Accessibility and Screen Recording requests,
   then select the menu-bar items to move into the overflow panel.

### Homebrew

```bash
brew tap EvanProgramming/overflowbar https://github.com/EvanProgramming/OverflowBar.git
brew install --cask EvanProgramming/overflowbar/overflowbar
```

## Compatibility

- macOS 15 or later; macOS 26 uses the Liquid Glass compatibility path.
- Universal DMG (arm64 + x86_64) with the production compatibility bundle
  identifier `com.overflowbar.mac26.v6`.
- Accessibility and Screen Recording permissions are required for the complete
  experience.
