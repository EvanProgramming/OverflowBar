# Installation

## Requirements

- macOS 15 Sequoia or later
- Apple Silicon for the downloadable DMG
- Accessibility and Screen Recording permissions for the full feature set

## Install the DMG

1. Open the [latest GitHub Release](https://github.com/EvanProgramming/OverflowBar/releases/latest).
2. Download `OverflowBar-<version>.dmg`.
3. Optionally verify the download with the accompanying `.sha256` file:

   ```bash
   shasum -a 256 -c OverflowBar-<version>.dmg.sha256
   ```

4. Open the DMG and drag **OverflowBar** into **Applications**.
5. Launch OverflowBar from Applications.

## First launch and Gatekeeper

The current community release is ad-hoc signed because the project does not yet have a Developer ID certificate or notarization. If macOS blocks the first launch:

1. Open **Applications** in Finder.
2. Control-click **OverflowBar** and choose **Open**.
3. Confirm **Open** in the system dialog.

Do not disable Gatekeeper or System Integrity Protection.

## Permissions

OverflowBar's onboarding opens the relevant System Settings pages.

### Accessibility

Used to discover accessible menu bar controls, invoke `AXPress`, relay compatible activation events, and manage the selected layout.

Path: **System Settings → Privacy & Security → Accessibility**

### Screen Recording

Used to capture small, local images of selected menu bar items for the second row. OverflowBar does not continuously record the screen and does not upload captures.

Path: **System Settings → Privacy & Security → Screen & System Audio Recording**

After changing either permission, quit and reopen OverflowBar if macOS does not refresh the permission immediately.

## Update

1. Open **Settings → Restore All Managed Icons** in the installed version.
2. Quit OverflowBar.
3. Download the latest DMG and replace the existing app in Applications.
4. Reopen OverflowBar. Existing selections are preserved through `UserDefaults`.

## Uninstall

1. Open OverflowBar Settings.
2. Click **Safe Reset** to restore managed items and disable layout management.
3. Disable **Open OverflowBar at Login**.
4. Quit OverflowBar and move it from Applications to the Trash.

Optional preference cleanup:

```bash
defaults delete com.overflowbar.app
```

