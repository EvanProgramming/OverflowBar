# OverflowBar 1.0.2

OverflowBar 1.0.2 fixes the menu bar icon capture regression introduced in 1.0.1.

## Fixes

- Fixed menu bar items appearing as generic placeholders instead of their real icons.
- Cache visible icons before expanding the managed hidden section at launch.
- Added a compatibility capture path for offscreen layer-25 menu bar windows that ScreenCaptureKit rejects on macOS 26.
- Excluded OverflowBar's own hidden spacer from scanning and capture results.
- Preserve cached images across rescans to prevent icon flicker.
- Pause hidden layout activation when selected icons cannot be captured safely.
- Show the number of successfully captured icons in Settings.
- Keep ScreenCaptureKit as the primary capture implementation for supported windows.

## Verification

- Captured 11 of 11 real menu bar icons during a live launch test.
- Verified offscreen compatibility capture against 11 hidden status-item windows.
- Verified that system Wi-Fi, Battery, Siri, Control Center, and Clock items are restored after a normal quit.
- Built successfully for arm64 and x86_64 in Debug configuration.

## Install

1. Download `OverflowBar-1.0.2.dmg`.
2. Open the disk image and drag OverflowBar to Applications.
3. Replace the previous version when prompted.

## Compatibility

- macOS 15 or later.
- Public release DMG contains an Apple Silicon build.
- Accessibility and Screen Recording permissions are required for the complete experience.

## Signing notice

This community build is ad-hoc signed and is not yet Apple-notarized because the project does not currently have a Developer ID certificate. macOS may require Control-clicking the app and choosing **Open** on first launch. A SHA-256 checksum is included as a separate release asset.
