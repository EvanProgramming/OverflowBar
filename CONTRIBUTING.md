# Contributing to OverflowBar

Thanks for helping improve OverflowBar. Menu bar behavior varies by macOS version, display topology, and source application, so reproducible reports and focused changes are especially valuable.

## Before opening an issue

- Search existing issues.
- Use **Settings → Safe Reset** to reveal the group.
- Accessibility and Screen Recording are optional; use them only for discovery, activation, and previews.
- Reproduce with the latest release.

Bug reports should include the macOS version, Mac model/display setup, source app, expected behavior, actual behavior, and exact reproduction steps. Do not attach screenshots that expose private menu bar or screen content without reviewing them first.

## Development setup

1. Use macOS 15 or later and Xcode 16 or later.
2. Clone the repository.
3. Open `OverflowBar.xcodeproj`.
4. Build the `OverflowBar` scheme.
5. Grant optional Accessibility or Screen Recording permission only when testing those features.

Command-line build:

```bash
xcodebuild \
  -project OverflowBar.xcodeproj \
  -scheme OverflowBar \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Pull requests

- Keep each pull request focused.
- Explain user impact and the macOS versions tested.
- Preserve the reveal-on-reset and reveal-on-quit paths; do not add synthetic input or cursor control.
- Avoid private frameworks and any design that requires disabling platform security.
- Add or update documentation for user-visible behavior.
- Run `git diff --check` and both Debug and Release builds.

UI changes should respect Reduce Motion, safe areas, light/dark appearances, and small displays.

## Architecture

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before changing scanning, capture, divider geometry, or activation. Menu-bar placement changes across macOS releases; verify each supported version on live hardware.

## Security and privacy

Do not open a public issue for a vulnerability. Follow [SECURITY.md](SECURITY.md). Changes must preserve the local-only capture model documented in [PRIVACY.md](PRIVACY.md).

The v1.5 native engine uses pinned Ice/Thaw GPL code; preserve provenance and imported notices. Read [native validation](docs/NATIVE_VALIDATION.md) before claiming runtime reliability.
