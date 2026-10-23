# OverflowBar 1.5.1 — Automatic Icon Hiding and Retry

OverflowBar 1.5.1 adds automatic handling for newly appearing menu bar icons and a quick way to retry a layout that did not hide successfully. It also keeps the color behind the second row's Liquid Glass while rendering menu bar icons in grayscale. Existing preferences, app identity, and signed Sparkle update path are preserved.

## What's new

- **Hide new icons automatically.** When **Hide selected icons** is on, OverflowBar adds newly discovered, eligible icons to the saved selection and applies the layout. On first use, it seeds its known-item list from the last verified menu bar order when available; otherwise, the current icons become the baseline. Protected macOS controls and items without stable identities stay out of the selection.
- **Retry from Settings.** The new **Retry Hiding** toolbar button cancels an active layout, waits for it to stop, reveals the current arrangement, and applies the saved selection again. It keeps the selection and hide preference unchanged. Accessibility must be enabled, hiding must be on, and at least one icon must be selected.
- **Keep color behind Liquid Glass.** The second-row surface shows the colors behind it while menu bar icons remain grayscale.

## Permissions and updates

Accessibility lets OverflowBar arrange selected icons and open their controls. Screen Recording enables live previews; without it, available app icons remain in use. Icons remain accessible in the menu bar when hiding is off or Accessibility is unavailable.

Existing users can install 1.5.1 through the signed in-app updater, which asks before installing, or download the DMG below. The app keeps its existing bundle identifier and preferences. Ad-hoc replacement builds may require macOS permissions to be reauthorized. The previous stable [v1.0.19 release](https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.0.19) remains available for manual rollback; Sparkle does not downgrade automatically.

## Verification

- 72 XCTest cases ran: 71 passed, one test requiring live Accessibility permission was skipped, and there were no failures.
- Debug and universal Release builds succeeded. The installed universal app and nested helper/framework signatures were checked.
- The user accepted the requested visual result. Physical macOS 15 and Intel testing, the full display and permission matrix, 100 activation cycles, and a two-hour soak were not performed for this release.
- See the [v1.5.1 release-check report](https://github.com/EvanProgramming/OverflowBar/blob/main/docs/RELEASE_CHECKS_V1.5.1.md) for the detailed evidence and remaining limits.

## Install

1. [Download the v1.5.1 DMG](https://github.com/EvanProgramming/OverflowBar/releases/download/v1.5.1/OverflowBar-1.5.1.dmg) or install the update from OverflowBar.
2. Drag OverflowBar to Applications and replace the older copy.
3. Open OverflowBar, grant Accessibility if you want to hide or open icons, and select the icons to place in the second row.

Community builds are ad-hoc signed and not notarized. If macOS blocks the first launch, Control-click OverflowBar in Applications and choose **Open**. The universal build targets macOS 15 and later on Apple silicon and Intel; macOS 27 runtime behavior remains untested.
