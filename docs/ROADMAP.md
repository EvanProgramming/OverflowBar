# Roadmap

This roadmap describes direction, not guaranteed delivery dates. Priorities may change when macOS updates affect menu bar behavior.

## Now — reliability and distribution

- [ ] Developer ID signing and Apple notarization
- [ ] Automated clean-install smoke test for every release
- [ ] Broader testing across MacBook notch sizes, external displays, and auto-hidden menu bars
- [ ] Better app/title identification for generic `Item-0` windows
- [ ] Diagnostics export with privacy-safe system and layout information
- [ ] Harden activation against source apps that rebuild their status item at runtime

## Next — faster daily use

- [ ] Keyboard shortcut to toggle the second row
- [ ] Search when the second row contains many items
- [ ] Per-display placement preferences
- [ ] Named visibility profiles for work, meetings, and travel
- [ ] Optional separator groups and custom item ordering
- [ ] Update checks with release notes

## Later — ecosystem and polish

- [ ] Universal binary release after compatibility testing
- [ ] Localization framework and community translations
- [ ] Signed Homebrew Cask after notarization and project adoption meet Homebrew requirements
- [ ] Plugin-safe integration points for automation tools
- [ ] Performance and energy diagnostics dashboard

## Non-goals for the current release

- Disabling System Integrity Protection
- Depending on private frameworks that prevent normal distribution
- Uploading screen captures, menu bar contents, or usage telemetry
- Replacing macOS Control Center

Use [GitHub Discussions](https://github.com/EvanProgramming/OverflowBar/discussions) for roadmap ideas and [Issues](https://github.com/EvanProgramming/OverflowBar/issues) for scoped, reproducible work.

