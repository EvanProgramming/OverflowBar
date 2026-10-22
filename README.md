# OverflowBar

OverflowBar v1.5 gives selected menu bar icons a second row. Open an icon there to use its original menu or popover.

**v1.5.0 is a candidate, not a published stable release.** Actual native hiding, preview/activation cycles and a two-hour soak must pass on macOS 15 and 26.4 before publication. See [validation gates](docs/NATIVE_VALIDATION.md).

- Choose menu bar icons one at a time.
- Source-aware Tahoe discovery, including Control Center-hosted windows.
- Authenticated ad-hoc discovery and recyclable capture helpers.
- Open selected icons using Accessibility or supported menu bar actions.
- A scrollable panel with system materials and keyboard accessibility.
- Universal Intel/Apple Silicon build; macOS 15 target; macOS 27+ fails open.
- Ad-hoc signing and signed Sparkle updates; no paid certificate required.

Accessibility is required to hide selected icons and open their menus. Screen Recording enables live previews. Moving icons may briefly move the pointer; you can cancel an operation at any time.

## Documentation

[Installation](docs/INSTALLATION.md) · [Usage](docs/USAGE.md) · [Architecture](docs/ARCHITECTURE.md) · [Privacy](PRIVACY.md) · [Release process](docs/RELEASING.md) · [Contributing](CONTRIBUTING.md)

v1.5 adopts [GPL-3.0](LICENSE). Exact Ice/Thaw source pins and local changes are recorded in [third-party notices](THIRD_PARTY_NOTICES.md). Earlier OverflowBar code retains its [original MIT notice](LICENSE-MIT-ORIGINAL).
