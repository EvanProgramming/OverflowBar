# Changelog

All notable user-visible changes to OverflowBar are documented here.

## [Unreleased]

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

[Unreleased]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.6...HEAD
[1.0.6]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/EvanProgramming/OverflowBar/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.0.0
