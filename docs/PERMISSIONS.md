# Permissions

OverflowBar asks for access only for the menu-bar actions it performs. You control both grants in System Settings.

## Accessibility

Accessibility is required to identify, arrange, and activate supported menu-bar items. If it is off, icons remain available in the menu bar and the app reports that it cannot apply the layout.

Open **System Settings → Privacy & Security → Accessibility**. Add or enable the installed OverflowBar application. Do not grant access to unrelated applications.

## Screen & System Audio Recording

Screen Recording enables live status-icon previews. It is optional: OverflowBar can display available application icons without it. Preview captures stay in bounded memory on your Mac and are not uploaded.

Open **System Settings → Privacy & Security → Screen & System Audio Recording** and enable OverflowBar. macOS may require you to quit and reopen the app after changing this permission.

## After replacing a local build

Ad-hoc signatures can change between local builds. macOS may show an old OverflowBar permission entry as enabled while the replaced application is denied.

1. Quit OverflowBar and replace the copy in Applications.
2. In each affected privacy list, remove only the stale OverflowBar entry.
3. Add /Applications/OverflowBar.app again and enable it.
4. Quit and reopen OverflowBar.

Use this recovery only for a local rebuild whose permission stopped working; do not remove another app’s permission entry. For general installation and first-launch steps, see [Installation](INSTALLATION.md).

## Related guides

[Installation](INSTALLATION.md) · [Using OverflowBar](USAGE.md) · [Troubleshooting](TROUBLESHOOTING.md) · [Privacy](../PRIVACY.md)
