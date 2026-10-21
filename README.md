# OverflowBar

OverflowBar v1.5 is a native macOS menu-bar manager that arranges selected icons into a hidden section and displays genuine previews in a floating second row. Clicking a preview opens the original native menu or popover.

**v1.5.0 is a candidate, not a published stable release.** Actual native hiding, preview/activation cycles and a two-hour soak must pass on macOS 15 and 26.4 before publication. See [validation gates](docs/NATIVE_VALIDATION.md).

- Per-icon selection with bounded native drag transactions.
- Source-aware Tahoe discovery, including Control Center-hosted windows.
- Authenticated ad-hoc discovery and recyclable capture helpers.
- Native Accessibility activation where appropriate; scoped native events otherwise.
- Liquid Glass/material panel, scrolling and accessibility.
- Universal Intel/Apple Silicon build; macOS 15 target; macOS 27+ fails open.
- Ad-hoc signing and signed Sparkle updates; no paid certificate required.

Accessibility is required for automatic arrangement/activation. Screen Recording enables actual icon previews. Native operations can briefly move the pointer; timeouts and cancellation always clean up event state.

## Documentation

[Installation](docs/INSTALLATION.md) · [Usage](docs/USAGE.md) · [Architecture](docs/ARCHITECTURE.md) · [Privacy](PRIVACY.md) · [Release process](docs/RELEASING.md) · [Contributing](CONTRIBUTING.md)

v1.5 adopts [GPL-3.0](LICENSE). Exact Ice/Thaw source pins and local changes are recorded in [third-party notices](THIRD_PARTY_NOTICES.md). Earlier OverflowBar code retains its [original MIT notice](LICENSE-MIT-ORIGINAL).
