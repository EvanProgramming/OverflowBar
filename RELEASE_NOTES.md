# OverflowBar 1.0.1

OverflowBar 1.0.1 is a safety and reliability update for Apple Silicon Macs running macOS 15 or later.

## Improvements

- The hidden-section spacer is now active only when layout management is enabled and at least one item is selected.
- First-run setup no longer changes the menu bar before the user finishes customization.
- Managed icons are restored before a normal app quit, with a bounded timeout to avoid blocking shutdown.
- Added **Safe Reset** to restore managed icons and disable layout management in one action.
- Replaced the private window screenshot symbol with the public ScreenCaptureKit screenshot API.
- Added multi-display menu bar discovery based on Core Graphics display bounds.
- Prevented stale asynchronous icon captures from overwriting a newer scan.
- Added bounded retries and visible layout operation feedback.
- Improved Accessibility metadata matching and filtering of protected system controls.
- Added a configurable, debounced hover-to-reveal behavior.
- Added same-app outside-click handling for the overflow panel.
- Added GitHub Actions builds plus privacy and security documentation.

## Install

1. Download `OverflowBar-1.0.1.dmg`.
2. Open the disk image and drag OverflowBar to Applications.
3. Launch OverflowBar and follow the welcome setup if this is a new installation.

## Compatibility

- Apple Silicon
- macOS 15 or later
- Liquid Glass appearance on macOS 26 or later

## Signing notice

This community build remains ad-hoc signed and is not yet Apple-notarized because the project does not currently have a Developer ID certificate. macOS may require Control-clicking the app and choosing **Open** on first launch. A SHA-256 checksum is included as a separate release asset.
