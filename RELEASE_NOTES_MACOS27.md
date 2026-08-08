# OverflowBar macOS 27 Compatibility Preview

This is a separate compatibility preview for macOS 27 Golden Gate. It is not
the stable release and is intended for users who want to evaluate OverflowBar
on macOS 27 before the platform and third-party compatibility behavior settles.

## What changed

- Avoids the legacy per-status-item WindowServer Command-drag path on macOS 27.
- Uses bounded Accessibility discovery and position updates when macOS exposes
  a status item as an individually writable Accessibility element.
- Disables OverflowBar's legacy hidden staging section on macOS 27 so it does
  not compete with Apple's native menu-bar overflow control.
- Preserves the existing macOS 15 and macOS 26 paths.

## Important limitations

- macOS 27 renders the menu bar through a unified host and provides its own
  overflow/expand control. Apple does not provide a public API for third-party
  apps to reorder or hide every arbitrary status item.
- Some icons may not be individually exposed or may expose a read-only
  Accessibility position. Those icons cannot be forcibly hidden by OverflowBar
  and remain controlled by macOS's native overflow behavior.
- Accessibility and Screen Recording permissions are required for the complete
  discovery, icon capture, activation, and compatibility behavior.
- This preview was built and statically verified with the available macOS 26.5
  SDK. It has not been runtime-tested on macOS 27 because no macOS 27 test
  device or runtime is available in this environment.
- The preview is ad-hoc signed and may require Control-click → Open or Open
  Anyway in System Settings > Privacy & Security.

## Install

Download the DMG attached to this pre-release. Keep the stable release if you
need the existing production behavior, and use macOS 27's native overflow
control for icons that OverflowBar cannot individually manage.
