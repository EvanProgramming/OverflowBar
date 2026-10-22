# OverflowBar 1.5.0 — Native Engine Update

OverflowBar 1.5.0 is the latest stable release. It replaces the previous manual-grouping backend with an updated native menu bar engine based on Ice and Thaw. Select individual menu bar icons, arrange them in OverflowBar's second row, and use their original menus and popovers from the panel. The release retains the existing app identity and preferences, and v1.0.19 users can update through the signed in-app update flow.

## What's new

- **Choose icons individually.** Select the items to manage from a redesigned setup flow and settings page. Protected macOS controls are excluded from selection, and items that cannot be identified safely stay available in the menu bar.
- **Use the original controls.** The native engine moves selected status items into OverflowBar's second row. Selecting an item opens its original menu, popover, or toggle through the owning application rather than substituting a screenshot.
- **See live previews.** When Screen & System Audio Recording access is enabled, OverflowBar can show captured status-item images. Captures are processed locally and kept in memory; without this permission, available app icons are used instead.
- **Navigate by keyboard.** The panel supports keyboard focus, arrow-key navigation, and Escape dismissal, alongside the updated Liquid Glass appearance on macOS 26.
- **Recover safely.** Selection is saved across launches. Cancel stops an active operation; Reset Icon Selection and normal quit reveal the originals. If movement or restoration is uncertain, OverflowBar leaves the affected item accessible instead of repeatedly applying an unverified move.
- **Isolate native services.** Discovery and image capture run in separate authenticated helpers. The helpers validate their parent app, bound their replies, and can be recycled after a failed or timed-out request.

## Fixed and reliability improvements

- Improved source-aware matching across application-owned and Control Center-hosted status items, including identity refresh after WindowServer changes.
- Preserved the selected layout across wake-related refreshes and avoided unnecessary reordering when the current layout already matches the saved selection.
- Prevented protected system controls and ambiguous targets from becoming automatic movement or activation targets.
- Corrected native menu-bar movement and click routing, and made activation prefer a freshly resolved target when an older Accessibility reference may be stale.
- Added bounded movement, cancellation, verification, and recovery behavior so a failed operation does not trigger repeated clicks or hide an item whose state is uncertain.

## In-app updates

OverflowBar keeps its existing bundle identifier and Sparkle feed, so compatible installations can receive this release in the app. Sparkle verifies the signed updater archive and asks before installing. The production-key rehearsal installed v1.5.0 over a disposable copy of v1.0.19; tampered archive and feed checks were rejected. Sparkle does not automatically downgrade to v1.0.19.

## Verification

- **Automated tests:** 67 XCTest cases passed with 0 failures; one test requiring a live Accessibility permission was skipped. Debug and universal Release builds, static analysis, native-engine checks, documentation links, and package metadata checks passed.
- **Native fixture checks on macOS 26.4:** four fixture items were moved out of the visible menu bar and restored. Native menu activation reached its fixture owner; popover and toggle counters changed; recognizable captures, keyboard navigation, Escape dismissal, and return to the hidden layout were observed.
- **Release packages:** the published universal DMG and updater ZIP passed archive and nested-signature checks. The release DMG SHA-256 is `f18b2e8b9156e84e3d05083eb33a06d647fe6243f64fc641202051091d2db566`; the updater ZIP SHA-256 is `d171c0d00fcb984dd54877b871e18136dae86a9510edb1601cdaf2a5649fdcc9`.
- See the [v1.5.0 release-check report](https://github.com/EvanProgramming/OverflowBar/blob/main/docs/RELEASE_CHECKS_V1.5.md) for commands, results, and the complete test matrix.

## Important for affected users

- This community build is ad-hoc signed and is not notarized with an Apple Developer ID. If macOS blocks the first launch, Control-click OverflowBar in Applications and choose **Open**.
- Accessibility access is required to arrange icons and open their native controls. Screen & System Audio Recording access enables live previews. Without Accessibility, items remain in the menu bar.
- An ad-hoc update can leave an older permission entry looking enabled while the new app is denied. In **System Settings → Privacy & Security**, remove only the stale OverflowBar entry from **Accessibility** and **Screen & System Audio Recording**, add `/Applications/OverflowBar.app` again, enable it, then quit and reopen OverflowBar.
- The engine incorporates upstream Ice and Thaw work under GPL-3.0. See the [license](https://github.com/EvanProgramming/OverflowBar/blob/v1.5.0/LICENSE) and [third-party notices](https://github.com/EvanProgramming/OverflowBar/blob/v1.5.0/THIRD_PARTY_NOTICES.md).

## Install

1. [Download the v1.5.0 DMG](https://github.com/EvanProgramming/OverflowBar/releases/download/v1.5.0/OverflowBar-1.5.0.dmg).
2. Drag OverflowBar to Applications and replace the older copy.
3. Open OverflowBar, grant the requested permissions, and select the icons you want in the second row.

Homebrew is also available:

```bash
brew tap EvanProgramming/overflowbar https://github.com/EvanProgramming/OverflowBar.git
brew install --cask EvanProgramming/overflowbar/overflowbar
```

## Compatibility and validation limits

- The universal release contains Apple silicon (`arm64`) and Intel (`x86_64`) slices and targets macOS 15 or later. The release package metadata was checked for both architectures and the macOS 15 deployment floor.
- Physical macOS 15 and Intel hardware were not available for this audit. Snapzy and Electron tray responses, the full permission and system-state matrix, 100 activation cycles, a two-hour soak, and external-display configurations were not tested.
- macOS 27 uses a fail-open compatibility path that leaves automatic hiding disabled. Runtime behavior on macOS 27 was not tested.
- The [previous stable v1.0.19 release](https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.0.19) remains available for manual fallback. Sparkle will not downgrade automatically.
