# OverflowBar

A native macOS 15+ menu-bar overflow panel for notch-equipped Macs. It mirrors selected, accessibility-exposed status icons beneath the menu bar and forwards activation to the original item.

## Install

Download the latest `OverflowBar-*.dmg` from [GitHub Releases](https://github.com/EvanProgramming/OverflowBar/releases), open it, and drag OverflowBar into Applications. The first launch presents a guided setup for Accessibility, Screen Recording, login launch, and choosing menu bar items.

The current community build is ad-hoc signed because the project does not yet have a Developer ID certificate or Apple notarization. macOS may require **Control-click → Open** on the first launch. A notarized build will replace it once release signing is configured.

## Original-icon layout mode

OverflowBar also includes an opt-in, experimental layout mode modeled on menu-bar managers: selected original icons are Command-dragged to the left of the OverflowBar arrow, forming a hidden section. The arrow stays on the visible side of that divider; the second row provides a compact way to access the hidden items. When an item is chosen, OverflowBar temporarily returns the original item to the visible section, invokes it, and re-hides it after a short delay.

Critical macOS controls—including Wi-Fi, Battery, Siri, Control Center, and Clock—are discovered separately and kept visible. Settings identifies these controls with an **Always Visible** lock, and every layout operation restores them if an earlier build or interrupted operation left them offscreen.

Enable this only from **Settings → Menu Bar Layout**, then use **Apply Hidden Layout**. **Restore All Managed Icons** moves managed items back to the visible side. This changes the user's menu-bar arrangement and is deliberately never performed automatically. It requires Accessibility permission and may need adaptation for future macOS releases.

## Run

Open `OverflowBar.xcodeproj` in Xcode 16 or later, choose the `OverflowBar` scheme, and run it. The app is an accessory app, so it has no Dock icon; use the chevron in the menu bar and open its Settings scene from the app menu if needed.

To create the Apple Silicon release DMG locally:

```bash
./scripts/create-dmg.sh
```

The artifact and its SHA-256 checksum are written to `dist/`.

## Permissions

- **Accessibility** permits OverflowBar to discover accessible right-side menu bar controls and invoke their `AXPress` action. If an item does not offer that action, macOS accessibility permission is also needed for the mouse-click fallback.
- **Screen Recording** permits a low-frequency capture of each selected control so the overflow panel can show its actual current icon. OverflowBar uses ScreenCaptureKit first and an isolated Core Graphics compatibility path only for offscreen menu bar windows that ScreenCaptureKit cannot capture on macOS 26. Captures occur when the panel/settings refresh, not continuously.

Open the corresponding System Settings pane from OverflowBar's Settings window. The app stays functional without permissions, but scanning, capture, or activation is unavailable as applicable.

If a layout operation does not complete as expected, open Settings and use **Safe Reset**. OverflowBar also attempts to restore managed icons before a normal quit.

## V1 scope and limitations

The scanner deliberately uses public Accessibility and window-list APIs. Apps that do not expose enough status-item information may not be mirrored. Layout mode uses macOS's user-facing Command-drag behaviour for status-item arrangement; it is an experimental compatibility feature, not an App Store target.
