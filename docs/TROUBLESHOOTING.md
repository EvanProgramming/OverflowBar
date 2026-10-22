# Troubleshooting

## macOS blocks the first launch

The community build is ad-hoc signed and not notarized. Download it from the [official releases](https://github.com/EvanProgramming/OverflowBar/releases/latest). If Gatekeeper blocks it, follow Apple's [Open Anyway instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) for an app you trust.

## The arrow or second row is missing

Refresh **Menu Bar Icons** in Settings. If the native arrow remains unavailable, choose **Settings → More → Reset Icon Selection** to restore the menu-bar icons. Some macOS Tahoe installations retain ownership references in Control Center's protected state; this is a system issue, not a state to repair by repeatedly resetting Control Center.

Do not edit protected Control Center preferences, change the app's bundle identifier, or repeatedly attempt to recreate controls. OverflowBar makes one bounded recovery attempt and leaves icons accessible when it cannot verify the result. Include the macOS and OverflowBar versions in a report.

## No icons appear in the list

Open another application that has a menu-bar status item, then choose **Refresh Icons**. Protected system controls are excluded. Items the app cannot identify safely are not offered for selection.

## Preview images are missing

Screen Recording is optional. Without it, OverflowBar displays available application icons. For genuine previews, enable **Screen & System Audio Recording** for OverflowBar in System Settings. For setup steps and local-build recovery, see [Permissions](PERMISSIONS.md).

## A click does not open the expected menu

Refresh the icon list and try again. If OverflowBar cannot verify the source control or its menu, it leaves the item available rather than guessing. Choose **Cancel** to stop an active layout operation; choose **Reset Icon Selection** to restore the group.

## An ad-hoc update appears to lose its permission

macOS can retain a grant for an older local app signature. Follow [After replacing a local build](PERMISSIONS.md#after-replacing-a-local-build) and remove only the stale OverflowBar entry.

## OverflowBar does not hide icons on macOS 27 or later

The v1.5 engine fails open on macOS 27 and later. It leaves icons in the menu bar and disables native management. This compatibility path is based on source review; macOS 27 runtime behavior was not tested. Review the [release validation report](RELEASE_CHECKS_V1.5.md) before relying on a compatibility claim.

## Frequently asked questions

**Does OverflowBar need Screen Recording to hide icons?** No. Accessibility enables native arrangement and activation; Screen Recording adds live previews.

**Does OverflowBar upload icon previews?** No. Preview captures and layout selections remain local. Sparkle contacts its configured release feed to check for signed updates. See [Privacy](../PRIVACY.md).

**How do I restore every icon?** In Settings, choose **More → Reset Icon Selection** and confirm **Reset Icon Selection**. Quitting also shows the icons without clearing your saved selection.

**Will an in-app update downgrade my version?** No. Sparkle does not automatically downgrade. The previous stable [v1.0.19 release](https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.0.19) remains available for manual rollback.

**How do I uninstall?** Quit OverflowBar, then remove it from Applications. Quitting reveals the icons. See [Installation](INSTALLATION.md#uninstall).

## Related guides

[Installation](INSTALLATION.md) · [Permissions](PERMISSIONS.md) · [Using OverflowBar](USAGE.md) · [Homebrew](HOMEBREW.md)
