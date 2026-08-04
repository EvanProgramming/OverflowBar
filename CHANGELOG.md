# Changelog

All notable user-visible changes to OverflowBar are documented here.

## [Unreleased]

- Added an alternative third-party Homebrew Cask installation path backed by versioned GitHub Release artifacts and checksum validation; the DMG remains the recommended installation method.

## [1.0.16] - 2026-08-04

- Clarified menu-bar activation status in Settings: WindowServer-backed items now show the fast activation indicator instead of a misleading warning.
- Kept the warning indicator only for items that have no available activation path.
- Preserved the non-blocking scanner and fast activation behavior introduced in the previous stability fixes.

## [1.0.15] - 2026-08-04

- Included hidden menu-bar windows in the OverflowBar panel so protected system controls cannot disappear after a previous layout move.
- Captured hidden Wi-Fi, Bluetooth, Siri, Battery, and other Control Center items instead of limiting capture to persisted application selections.
- Added localized and descriptive system-item recognition, including Wi-Fi descriptions such as “Wi‑Fi, connected” and generic macOS 26 status-menu windows.
- Preserved the startup pointer-safety rule: discovery and capture remain observational and do not inject synthetic layout events.

## [1.0.14] - 2026-08-04

- Prevented startup discovery and icon capture from injecting synthetic menu-bar events.
- Removed automatic recovery of protected system items during login and startup.
- Restricted hidden-layout changes to explicit user actions, preventing stale pointer and hover state in Safari, Codex, and other AppKit applications.
- Preserved the fast Accessibility activation path and right-click handling for supported menu-bar items.

## [1.0.11] - 2026-08-03

- Capture the real pointer before synthetic menu-bar drags and restore it using the correct Quartz coordinate space.
- Reassociate the hardware mouse with WindowServer after a drag so subsequent movement updates hover state in other applications.

## [1.0.10] - 2026-08-03

- Removed the synthetic session-wide `mouseMoved` event used after layout moves, which could force other applications to keep the arrow cursor until mouse-down.
- Keep Pointer and text-edit I-beam hover states entirely under the active application while still preserving the physical cursor position during layout changes.

## [1.0.9] - 2026-08-03

- Normalize Control Center window identities so generic items such as Feishu remain selected and hidden across WindowServer refreshes.
- Persist explicit deselections and detect newly-created menu-bar windows without requiring a restart.
- Route fallback activation through the WindowServer session event tap for more reliable Control Center clicks.

## [1.0.8] - 2026-08-03

### Fixed

- Added continuous menu-bar discovery with startup retries, launch/termination notifications, and immediate refresh when the overflow panel opens.
- Added stable icon fallbacks and background capture so missing or blank screenshots no longer block layout or show empty cells.
- Made normal activation use cached Accessibility Press or a direct target-process click; temporary WindowServer moves are now only a fallback.
- Removed the delayed rehide-on-next-mouse-up race that could interfere with dragging another application's window or corrupt Hover state.
- Coalesced refresh/capture/layout work and shortened move verification to avoid multi-second activation delays.
- Prevented regular application menus from being mistaken for status-bar controls.

## [1.0.7] - 2026-07-22

### Fixed

- Stopped forcing the mouse cursor back to its current position after menu bar item moves and activations, preventing synthetic pointer updates from leaving other menu bar items in an incorrect hover state.

## [1.0.6] - 2026-07-16

### Fixed

- Made the persistent OverflowBar arrow a macOS template image so it automatically uses the correct black or white contrast in light and dark menu bars.

## [1.0.5] - 2026-07-16

### Fixed

- Rebuilt the downloadable DMG with the Icon Composer app icon, so installed copies display the OverflowBar icon correctly.
- Built public artifacts with the macOS 26 SDK so macOS 26 uses the Liquid Glass second-row surface instead of the macOS 15 material fallback.
- Rendered captured menu bar glyphs as white template icons in dark mode for reliable contrast.

## [1.0.4] - 2026-07-15

### Added

- Rebuilt the repository landing page and documentation for public discovery and contribution.
- Added automated tagged-release packaging.
- Added a product demo GIF, social preview asset, contribution templates, and documentation-link validation.

### Changed

- Updated repository metadata, topics, release navigation, and community settings.

## [1.0.3] - 2026-07-15

### Fixed

- Restored Wi-Fi, Battery, Siri, Control Center, and Clock when an earlier layout left them offscreen.
- Prevented stale selections from hiding protected system controls.
- Added protected system controls to Settings with their real icons and an Always Visible state.

## [1.0.2] - 2026-07-15

### Fixed

- Restored real menu bar icon capture for visible and managed offscreen items.
- Preserved cached icon images across rescans.
- Paused managed layout when selected icons could not be captured safely.

## [1.0.1] - 2026-07-15

### Added

- Guided onboarding, DMG packaging, login launch, and release documentation.
- Adaptive Liquid Glass/material surfaces and refined panel animation.

## [1.0.0] - 2026-07-15

### Added

- Initial public release with item discovery, selection, managed hiding, second-row presentation, and hybrid activation.

[Unreleased]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.16...HEAD
[1.0.16]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.15...v1.0.16
[1.0.15]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.14...v1.0.15
[1.0.14]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.13...v1.0.14
[1.0.11]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.10...v1.0.11
[1.0.10]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.9...v1.0.10
[1.0.9]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.0.0
