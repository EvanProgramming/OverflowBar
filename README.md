# OverflowBar

A native macOS 15+ menu-bar overflow panel for notch-equipped Macs. It mirrors selected, accessibility-exposed status icons beneath the menu bar and forwards activation to the original item.

## Original-icon layout mode

OverflowBar also includes an opt-in, experimental layout mode modeled on menu-bar managers: selected original icons are Command-dragged to the left of the OverflowBar arrow, forming a hidden section. The arrow stays on the visible side of that divider; the second row provides a compact way to access the hidden items. When an item is chosen, OverflowBar temporarily returns the original item to the visible section, invokes it, and re-hides it after a short delay.

Enable this only from **Settings → Menu Bar Layout**, then use **Apply Hidden Layout**. **Restore All Managed Icons** moves managed items back to the visible side. This changes the user's menu-bar arrangement and is deliberately never performed automatically. It requires Accessibility permission and may need adaptation for future macOS releases.

## Run

Open `OverflowBar.xcodeproj` in Xcode 16 or later, choose the `OverflowBar` scheme, and run it. The app is an accessory app, so it has no Dock icon; use the chevron in the menu bar and open its Settings scene from the app menu if needed.

## Permissions

- **Accessibility** permits OverflowBar to discover accessible right-side menu bar controls and invoke their `AXPress` action. If an item does not offer that action, macOS accessibility permission is also needed for the mouse-click fallback.
- **Screen Recording** permits a low-frequency capture of each selected control so the overflow panel can show its actual current icon. Captures occur when the panel/settings refresh, not continuously.

Open the corresponding System Settings pane from OverflowBar's Settings window. The app stays functional without permissions, but scanning, capture, or activation is unavailable as applicable.

## V1 scope and limitations

The scanner deliberately uses public Accessibility APIs and only includes controls exposed by third-party apps on the right side of the menu bar. Apps that do not expose their status item cannot be mirrored. Layout mode uses macOS's user-facing Command-drag behaviour for status-item arrangement; it is an experimental compatibility feature, not an App Store target.
