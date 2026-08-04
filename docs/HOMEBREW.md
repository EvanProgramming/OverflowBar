# Alternative Homebrew installation

The DMG is the recommended installation path for most users. Homebrew is an
alternative for users who prefer package-manager workflows. The third-party
Homebrew Cask uses the versioned DMG and SHA-256 checksum published by the
matching GitHub Release.

See the [main installation guide](INSTALLATION.md) for the recommended DMG flow.

## Install from the current repository

The source repository contains the Cask under `Casks/`. Homebrew can use this
repository as a tap when the repository URL is supplied explicitly:

```bash
brew tap EvanProgramming/overflowbar https://github.com/EvanProgramming/OverflowBar.git
brew install --cask EvanProgramming/overflowbar/overflowbar
```

The fully qualified cask name makes Homebrew load only the requested item from
the non-official tap. If a local Homebrew policy requires explicit trust, use:

```bash
brew trust --cask EvanProgramming/overflowbar/overflowbar
```

After installation, normal Homebrew maintenance applies:

```bash
brew update
brew outdated --cask
brew upgrade --cask overflowbar
```

## First launch and permissions

The current community release is ad-hoc signed and not Apple-notarized. This
means Homebrew can install it, but macOS may block the first launch. If that
happens, Control-click **OverflowBar** in Applications and choose **Open**.

OverflowBar still requires Accessibility and Screen Recording permissions. The
app's onboarding opens the relevant System Settings pages; Homebrew cannot grant
those permissions on the user's behalf.

## Release maintenance

Before creating a release tag, update `Casks/overflowbar.rb` so its `version`
and `sha256` match the DMG that will be published by that tag. Validate it with:

```bash
bash scripts/validate-homebrew-cask.sh
```

The `Casks/` directory can later be moved unchanged into a dedicated
`homebrew-overflowbar` repository if a separate tap repository is preferred.
