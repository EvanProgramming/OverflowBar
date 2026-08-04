# OverflowBar 1.0.14

OverflowBar 1.0.14 is a stable patch release focused on pointer-state safety during startup.

## Fixed

- Startup discovery and icon capture are now observational and never apply synthetic menu-bar layout changes.
- Removed automatic recovery of off-screen protected system items during login and startup.
- Hidden layout changes are performed only after an explicit user action.
- Prevented the stale hover and cursor state observed in Safari, Codex, and other AppKit applications.
- Preserved fast Accessibility activation and right-click handling for supported menu-bar items.

## Verification

- Release build completed successfully.
- DMG passed hdiutil verification.
- SHA-256 checksum is included with the release assets.

## Install

1. Download `OverflowBar-1.0.14.dmg`.
2. Open the disk image and drag OverflowBar to Applications.
3. Replace an older copy when prompted.

## Compatibility

- macOS 15 or later; macOS 26 uses Liquid Glass.
- Public DMG contains an Apple Silicon build.
- Accessibility and Screen Recording permissions are required for the complete experience.
