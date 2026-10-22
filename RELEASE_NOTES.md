# OverflowBar 1.5.0 — Native Engine Update

OverflowBar 1.5.0 is the latest stable release and replaces the old manual-grouping backend with an updated native menu bar engine based on Ice/Thaw. Choose icons individually, arrange them in a second row, and open their original menus or popovers from the panel.

The update also improves source-aware discovery, captured previews, keyboard navigation, safe restoration, and helper isolation. The app keeps its existing bundle identity and preferences, so signed Sparkle updates remain available to existing users. The engine changes are documented with upstream provenance in [third-party notices](THIRD_PARTY_NOTICES.md); v1.5.0 is distributed under GPL-3.0.

OverflowBar supports macOS 15 and later on Intel and Apple silicon. Accessibility is required for automatic arrangement and native activation; Screen & System Audio Recording enables live previews. The community build is ad-hoc signed and not notarized; see the [installation guide](docs/INSTALLATION.md) if macOS blocks first launch.

The previous stable release, [v1.0.19](https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.0.19), remains available as a manual fallback.
