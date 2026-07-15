# User guide

## The OverflowBar arrow

OverflowBar installs a persistent chevron on the right side of the menu bar.

- **Left-click** toggles the second row.
- **Right-click** opens Settings.
- **Pointer at the menu bar** opens the second row when hover reveal is enabled.
- Clicking outside the second row closes it.

## Choose managed items

1. Right-click the OverflowBar arrow.
2. Select **Refresh Menu Bar Items** if an app was launched after OverflowBar.
3. Enable the switch beside every third-party item you want in OverflowBar.
4. Turn on **Hide selected original icons**.

The settings list shows the captured icon, owning process, discovered title, and activation method. macOS system controls such as Wi-Fi, Battery, Siri, Control Center, and Clock are marked **Always Visible**.

## Use the second row

Click the arrow to reveal a compact row beneath the menu bar. Selecting an item follows one of two paths:

- If the control supports Accessibility press, OverflowBar invokes it directly.
- Otherwise, OverflowBar briefly places the original item in a visible slot, activates it, and returns it to the managed section after the interaction.

The mouse pointer should remain where the user left it throughout this operation.

## Layout controls

- **Apply Hidden Layout** moves currently selected items into the managed section.
- **Restore All Managed Icons** brings selected originals back to the visible menu bar.
- **Safe Reset** disables layout management and restores managed and protected system items.

Use Safe Reset before uninstalling or whenever an interrupted operation leaves the menu bar in an unexpected state.

## Display behavior

The second row chooses the screen containing the OverflowBar arrow and remains inside that screen's visible frame and safe area. Its width is capped for small displays and becomes horizontally scrollable when many items are selected.

OverflowBar uses macOS 26 Liquid Glass where available and an ultra-thin material surface on macOS 15. Reduce Motion is respected.

## Troubleshooting

### An app is missing from Settings

1. Confirm the app's menu bar item is enabled in that app.
2. Grant Accessibility permission.
3. Click **Refresh Menu Bar Items**.
4. Restart the source app, then refresh again.

Some apps do not expose enough Accessibility or window metadata to be mirrored reliably.

### Icons are placeholders

Grant Screen Recording permission, reopen OverflowBar, and refresh the item list. The status message reports how many icons were captured.

### A selected item does not open

Restore all managed icons, verify that the original item works in the system menu bar, then reapply the layout. Include the app name and macOS version in a bug report.

### Wi-Fi, Battery, Siri, or Clock is missing

Open Settings and click **Safe Reset**, then quit and reopen OverflowBar. Protected system controls are restored at launch and before/after layout updates.

### The arrow disappears

Quit another menu bar app or reduce visible status items temporarily, then reopen OverflowBar. The arrow uses the right-most app-owned status slot, but macOS can still constrain all menu bar items when space is exhausted.

