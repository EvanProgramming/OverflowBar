# OverflowBar 1.0.15

OverflowBar 1.0.15 is a stable patch release that prevents system menu-bar controls from disappearing after a hidden layout move.

## Fixed

- Hidden menu-bar windows are now included in the OverflowBar panel even when they are not present in the persisted application selection set.
- Hidden Wi-Fi, Bluetooth, Siri, Battery, and Control Center icons are captured and shown instead of being silently dropped.
- Added recognition for localized Wi-Fi descriptions and generic macOS 26 Control Center status-menu windows.
- Panel refreshes now recapture any missing hidden-system icon image.
- Startup discovery and capture remain observational, preserving the pointer-state safety fix from 1.0.14.

## Verification

- Debug and Release builds completed successfully.
- Release Settings smoke test loaded 14 of 14 menu-bar icons, including hidden Control Center windows.
- Release DMG verification and SHA-256 checks are included with the release assets.

## Install

1. Download `OverflowBar-1.0.15.dmg`.
2. Open the disk image and drag OverflowBar to Applications.
3. Replace an older copy when prompted.

## Compatibility

- macOS 15 or later; macOS 26 uses Liquid Glass.
- Public DMG contains an Apple Silicon build.
- Accessibility and Screen Recording permissions are required for the complete experience.
