# Contributing

Menu-bar behavior varies by macOS release, display setup, and source application. Focused changes and reproducible reports help protect safe recovery.

## Before filing a bug

Search existing reports and reproduce on the latest release when possible. Include the macOS and OverflowBar versions, Mac and display setup, source app, expected and actual behavior, and exact steps. Remove private menu-bar or screen content from screenshots and logs.

If icons are hidden unexpectedly, use **Settings → More → Reset Icon Selection**. Normal quit also reveals icons while preserving the saved selection.

## Build and test

Use macOS 15 or later and Xcode 26. Follow [Development](docs/DEVELOPMENT.md) for the project layout, Debug build, XCTest, helper tests, and native acceptance requirements.

## Pull requests

- Keep changes focused and explain user impact and macOS versions tested.
- Preserve cancellation, timeouts, reveal-on-reset, and reveal-on-quit behavior.
- Native operations may briefly move and restore the pointer; preserve bounded input and cleanup on every exit.
- Avoid designs that require disabling System Integrity Protection. The current engine already uses private macOS APIs; treat them as a compatibility risk and preserve existing safeguards.
- Document user-visible changes and keep third-party provenance and required license notices intact.
- Run git diff --check, project builds, tests, and relevant validation checks before submitting.

## Security and privacy

Do not report vulnerabilities in a public issue. Follow [SECURITY.md](SECURITY.md). Preserve the local-only capture model in [Privacy](PRIVACY.md). Read the [architecture guide](docs/ARCHITECTURE.md) before changing discovery, capture, movement, or activation.

## Related guides

[Development](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md) · [Privacy](PRIVACY.md) · [Security policy](SECURITY.md)
