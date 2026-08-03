# OverflowBar 1.0.9

OverflowBar 1.0.9 makes menu-bar discovery and activation substantially faster and more resilient.

This release keeps Control Center-backed items (including Feishu's generic status item) stable across refreshes, automatically detects newly-created items, and uses a WindowServer session event for fallback activation.

## Fixed

- New and late-starting status items are discovered automatically, including after login launch.
- Normal activation uses Accessibility Press or a direct target-process click, avoiding the old multi-second synthetic drag path.
- Temporary moves no longer wait for the next unrelated mouse-up, preventing window-drag and Hover races.
- Blank captures fall back to application or symbol icons while real screenshots are filled in asynchronously.

## Install

1. Download `OverflowBar-1.0.9.dmg`.
2. Open the disk image and drag OverflowBar to Applications.
3. Replace an older copy when prompted.

## Compatibility

- macOS 15 or later; macOS 26 uses Liquid Glass.
- Public DMG contains an Apple Silicon build.
- Accessibility and Screen Recording permissions are required for the complete experience.
