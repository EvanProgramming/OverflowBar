# OverflowBar 1.0.10

OverflowBar 1.0.10 fixes a regression where other applications could lose their normal hover cursor shapes while OverflowBar was enabled.

OverflowBar no longer publishes synthetic session-wide mouse-movement events after layout changes. Pointer and text-edit cursor states are now left to the active application.

## Fixed

- New and late-starting status items are discovered automatically, including after login launch.
- Normal activation uses Accessibility Press or a direct target-process click, avoiding the old multi-second synthetic drag path.
- Temporary moves no longer wait for the next unrelated mouse-up, preventing window-drag and Hover races.
- Blank captures fall back to application or symbol icons while real screenshots are filled in asynchronously.

## Install

1. Download `OverflowBar-1.0.10.dmg`.
2. Open the disk image and drag OverflowBar to Applications.
3. Replace an older copy when prompted.

## Compatibility

- macOS 15 or later; macOS 26 uses Liquid Glass.
- Public DMG contains an Apple Silicon build.
- Accessibility and Screen Recording permissions are required for the complete experience.
