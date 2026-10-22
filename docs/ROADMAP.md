# Roadmap

This roadmap describes possible work, not guaranteed delivery dates. macOS menu-bar changes can alter priorities.

## Reliability and distribution

- [ ] Broader physical coverage across macOS 15 and 26, Intel and Apple silicon, display layouts, notches, and auto-hidden menu bars
- [ ] Complete third-party app and permission-state acceptance
- [ ] Record 100 activation cycles and a two-hour soak
- [ ] Clean-install smoke test for each release
- [ ] Improve identification of generic status items where source information is available
- [ ] Privacy-safe diagnostics that never export menu-bar captures or item names
- [ ] Consider Developer ID signing and notarization

## Possible product work

- [ ] Keyboard shortcut to toggle the second row
- [ ] Search for selected icons
- [ ] Per-display placement preferences
- [ ] Saved visibility profiles or custom item ordering
- [ ] Localization

## Current limits and non-goals

- The v1.5 release already ships a universal arm64/x86_64 binary.
- macOS 15 is the deployment target; physical macOS 15 and Intel acceptance remains unverified.
- macOS 27 and later use a fail-open path; runtime behavior has not been verified.
- The app uses private macOS capture APIs, which remain compatibility and release-validation risks.
- The project does not ask users to disable System Integrity Protection, upload screen captures or usage telemetry, or replace macOS Control Center.

Discuss ideas on [GitHub Discussions](https://github.com/EvanProgramming/OverflowBar/discussions); file scoped, reproducible work in [Issues](https://github.com/EvanProgramming/OverflowBar/issues).

## Related guides

[Installation](INSTALLATION.md) · [Native validation](NATIVE_VALIDATION.md) · [Release checks](RELEASE_CHECKS_V1.5.md)
