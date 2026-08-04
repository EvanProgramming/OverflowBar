# OverflowBar 1.0.16

OverflowBar 1.0.16 is a stable patch release that clarifies menu-bar activation status without changing the fast activation behavior.

## Fixed

- WindowServer-backed menu-bar items now show a fast activation indicator in Settings instead of a misleading warning triangle.
- The warning indicator is reserved for items with no available activation path.
- Preserved the non-blocking menu-bar scanner and low-latency activation path from the previous stability fixes.

## Verification

- Debug and Release builds completed successfully.
- Installed Release build loaded 14 of 14 menu-bar icons in Settings.
- WindowServer-backed rows reported `bolt.fill` with the help text `Uses fast WindowServer activation`.
- Release DMG verification and SHA-256 checks are included with the release assets.

## Install

### Recommended: DMG

1. Download `OverflowBar-1.0.16.dmg`.
2. Open the disk image and drag OverflowBar to Applications.
3. Replace an older copy when prompted.

### Alternative: Homebrew

```bash
brew tap EvanProgramming/overflowbar https://github.com/EvanProgramming/OverflowBar.git
brew install --cask EvanProgramming/overflowbar/overflowbar
```

Homebrew installs the same Apple Silicon DMG. The current community build is
ad-hoc signed, so macOS may require a one-time Control-click → **Open**
confirmation. Accessibility and Screen Recording permissions are still required.

## Compatibility

- macOS 15 or later; macOS 26 uses Liquid Glass.
- Public DMG contains an Apple Silicon build.
- Accessibility and Screen Recording permissions are required for the complete experience.
