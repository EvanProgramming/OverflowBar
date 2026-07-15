# OverflowBar 1.0.3

OverflowBar 1.0.3 restores missing macOS system menu bar controls and prevents managed layouts from hiding them again.

## Fixes

- Restores Wi-Fi, Battery, Siri, Control Center, and Clock when they were left offscreen by an earlier layout operation.
- Excludes live system-control window IDs from the managed hidden set.
- Rechecks protected system controls before and after every hidden-layout update.
- Discovers system controls in Settings instead of dropping them during Accessibility reconciliation.
- Shows protected controls with their real icon and an **Always Visible** lock.
- Prevents Select All, saved selections, and stale preferences from selecting protected controls.

## Verification

- Verified live that 10 selected third-party items remain hidden while Wi-Fi, Battery, Siri, Control Center, and Clock stay onscreen.
- Verified all five system controls appear in Settings with real icons and **Always Visible** state.
- Built successfully in Debug and Release configurations.

## Install

1. Download `OverflowBar-1.0.3.dmg`.
2. Open the disk image and drag OverflowBar to Applications.
3. Replace the previous version when prompted.

## Compatibility

- macOS 15 or later.
- Public release DMG contains an Apple Silicon build.
- Accessibility and Screen Recording permissions are required for the complete experience.

## Signing notice

This community build is ad-hoc signed and is not yet Apple-notarized because the project does not currently have a Developer ID certificate. macOS may require Control-clicking the app and choosing **Open** on first launch. A SHA-256 checksum is included as a separate release asset.
