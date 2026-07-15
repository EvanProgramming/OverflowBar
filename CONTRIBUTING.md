# Contributing to OverflowBar

Thanks for helping improve OverflowBar. Menu bar behavior varies by macOS version, display topology, and source application, so reproducible reports and focused changes are especially valuable.

## Before opening an issue

- Search existing issues.
- Try **Settings → Safe Reset**.
- Confirm Accessibility and Screen Recording permissions.
- Reproduce with the latest release.

Bug reports should include the macOS version, Mac model/display setup, source app, expected behavior, actual behavior, and exact reproduction steps. Do not attach screenshots that expose private menu bar or screen content without reviewing them first.

## Development setup

1. Use macOS 15 or later and Xcode 16 or later.
2. Clone the repository.
3. Open `OverflowBar.xcodeproj`.
4. Build the `OverflowBar` scheme.
5. Grant the debug app Accessibility and Screen Recording permissions when testing discovery or capture.

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
- Preserve the Safe Reset and normal-quit restoration paths.
- Avoid private frameworks and any design that requires disabling platform security.
- Add or update documentation for user-visible behavior.
- Run `git diff --check` and both Debug and Release builds.

UI changes should respect Reduce Motion, safe areas, light/dark appearances, and small displays.

## Architecture

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before changing scanning, capture, layout, or activation. These systems intentionally use bounded retries and verification because menu bar windows can be rebuilt asynchronously.

## Security and privacy

Do not open a public issue for a vulnerability. Follow [SECURITY.md](SECURITY.md). Changes must preserve the local-only capture model documented in [PRIVACY.md](PRIVACY.md).
