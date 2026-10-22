# Installation

## Compatibility

| macOS | Release package | Runtime status |
|---|---|---|
| macOS 15 | Universal binary; deployment target 15.0 | No physical macOS 15 machine was available for v1.5.0 acceptance. |
| macOS 26 | Universal binary; deployment target 15.0 | The release audit ran on macOS 26.4. A subset of native-fixture workflows passed; this does not establish the full GUI matrix. |
| macOS 27 and later | Universal binary; deployment target 15.0 | Source has a fail-open path that leaves icons accessible. macOS 27 runtime behavior was not tested. |

The v1.5.0 release contains both Apple silicon (arm64) and Intel (x86_64) slices. Intel hardware was not available for physical testing.

## Install from GitHub

1. Download the OverflowBar DMG from the [latest stable release](https://github.com/EvanProgramming/OverflowBar/releases/latest).
2. Open the DMG and drag OverflowBar to Applications.
3. Open OverflowBar. First launch opens setup; enable Accessibility, optionally enable Screen Recording, and choose icons.

The current DMG is OverflowBar-1.5.0.dmg. Community builds are ad-hoc signed and are not notarized. Only download builds from the official release. If macOS blocks a trusted copy, follow Apple's [Open Anyway instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). See [Permissions](PERMISSIONS.md) before granting access.

## Install with Homebrew

The repository's third-party Cask provides an alternative:

    brew tap EvanProgramming/overflowbar https://github.com/EvanProgramming/OverflowBar.git
    brew install --cask EvanProgramming/overflowbar/overflowbar

See [Homebrew](HOMEBREW.md) for trust prompts and upgrades. Homebrew does not grant macOS privacy permissions.

## Update or roll back

Existing users can check for updates in the app. Sparkle verifies the signed update and asks before installation. Updates preserve the app identity and preferences. An ad-hoc-signed replacement can require permission reauthorization; see [After replacing a local build](PERMISSIONS.md#after-replacing-a-local-build).

Sparkle does not downgrade. If you need to roll back, manually install the previous stable [v1.0.19 release](https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.0.19).

## Uninstall

Quit OverflowBar first. Quitting reveals managed icons while retaining your saved selection. Then remove OverflowBar from Applications. Homebrew users can run:

    brew uninstall --cask overflowbar

Removing the app is sufficient to uninstall it. Do not delete preferences belonging to other apps.

## Related guides

[Permissions](PERMISSIONS.md) · [Homebrew](HOMEBREW.md) · [Using OverflowBar](USAGE.md) · [Troubleshooting](TROUBLESHOOTING.md) · [Release validation](RELEASE_CHECKS_V1.5.md)
