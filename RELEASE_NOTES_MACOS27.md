# macOS 27 startup fix preview

This prerelease includes the fix for the startup crash reported in [issue #11](https://github.com/EvanProgramming/OverflowBar/issues/11). It breaks a synchronous recursion in the unsupported-system fallback. Native icon hiding remains disabled on macOS 27 and later; menu bar icons remain accessible.

**This preview has not been tested on macOS 27.** Automated tests and macOS CI passed on macOS 26. If you test this preview on macOS 27, please report whether the app launches and include a sanitized crash report if it does not.

Download the DMG and install manually. This preview is ad-hoc signed and not notarized; macOS may require you to allow it in Privacy & Security. It uses app version 1.5.1 (build 20) and does not update the stable Sparkle feed. Back up your preferences before installing if you wish to preserve your existing setup.
