# Using OverflowBar v1.5

Open OverflowBar from Applications. A manual launch shows setup or overview, including the current permission and operation state.

1. Enable Accessibility so OverflowBar can identify, arrange and activate native menu-bar items.
2. Enable Screen Recording for real icon previews. After changing that permission, quit and relaunch the installed app.
3. In Menu Bar Items, select **Hide** for the icons you want in the second row. Protected system controls and unresolved identities cannot be selected.
4. Choose **Hide Selected Icons**. OverflowBar performs bounded native drag transactions and reports any partial result.
5. Click the menu-bar arrow or **Open Second Row**. Click a preview to open the item's original menu or popover.

The divider and **Reveal Group** reveal originals. **Cancel Operation** stops an active arrangement; **Safe Reset** clears selection and reveals native icons. Quit reveals the native group but preserves your preference for the next launch.

## Permissions and limited states

Without Accessibility, automatic arrangement and activation remain disabled. Without Screen Recording, correctly attributed app icons can appear as a limited fallback; they are not genuine previews. Unknown items remain unresolved rather than becoming identical generic clickable targets.

Ad-hoc-signed updates can invalidate old permission grants. Remove only OverflowBar's stale entry from the affected Privacy & Security list, add the current app from Applications and enable it again. Do not change unrelated apps' permissions.

## Recovery

If a native operation fails, the group remains accessible and the overview explains the failure. Relaunch from Applications to reopen overview. A temporary item whose menu state cannot be confirmed stays accessible; reveal the group before retrying. Do not run another menu-bar manager alongside OverflowBar while validating layout.

macOS 27+ is unsupported for native management; icons remain accessible there. The original cursor restriction has been removed: arranging or opening an item can briefly move and restore the pointer.
