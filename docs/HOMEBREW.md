# Install with Homebrew

The DMG is the recommended path for most users. Homebrew is an alternative for users who prefer package-manager workflows. This repository includes a third-party Homebrew Cask for the published DMG.

## Install from this repository

The tap uses a custom name. Supply the repository URL and use the fully qualified cask token:

    brew tap EvanProgramming/overflowbar https://github.com/EvanProgramming/OverflowBar.git
    brew install --cask EvanProgramming/overflowbar/overflowbar

Homebrew may ask you to trust a third-party tap or cask, depending on your local policy. Only trust it if you verified the cask source and want Homebrew to use it.

## Upgrade or uninstall

    brew update
    brew outdated --cask
    brew upgrade --cask overflowbar

To remove the app:

    brew uninstall --cask overflowbar

## First launch and permissions

The community release is ad-hoc signed and not notarized. If macOS blocks the official release, follow Apple's [Open Anyway instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). Accessibility enables arrangement and activation. Screen Recording enables live previews. Homebrew cannot grant macOS privacy permissions for you; see [Permissions](PERMISSIONS.md).

## Maintainer release checks

After publication, update Casks/overflowbar.rb to the release version and the SHA-256 from that release's .dmg.sha256 asset. Verify the checksum against the published DMG, then run:

    bash scripts/validate-homebrew-cask.sh

See [Releasing](RELEASING.md) for the release sequence.

## Related guides

[Installation](INSTALLATION.md) · [Permissions](PERMISSIONS.md) · [Troubleshooting](TROUBLESHOOTING.md) · [Releasing](RELEASING.md)
