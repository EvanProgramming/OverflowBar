# Installation

OverflowBar 1.5.0 is the latest stable release. It supports macOS 15 and later on Intel and Apple silicon and includes the updated native menu bar engine. The previous stable [v1.0.19 release](https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.0.19) remains available for manual rollback.

## Install

Download the current OverflowBar DMG from the [official GitHub releases](https://github.com/EvanProgramming/OverflowBar/releases/latest), drag the app to Applications and open it. The first launch opens setup; later launches open Menu Bar.

## First launch and Gatekeeper

Community builds remain ad-hoc signed and are not notarized. Follow macOS's **Open Anyway** flow for a build you trust if Gatekeeper blocks launch. No paid Developer ID certificate is required. Signed Sparkle updates are enabled and retain manual installation confirmation.

## Permissions

Accessibility enables automatic icon arrangement and native activation. Screen Recording enables actual status-icon captures. Captures are local and in-memory; see [privacy](../PRIVACY.md). Screen Recording changes can require app relaunch. After replacing a local ad-hoc-signed build in Applications, remove the old OverflowBar entry and add `/Applications/OverflowBar.app` again under **Privacy & Security > Accessibility** and **Screen & System Audio Recording**, then quit and reopen OverflowBar. The ad-hoc signature changes between builds, so the old entry may look enabled while the new build is denied.

Embedded discovery and capture helpers are ad-hoc signed too. They authenticate the currently packaged app by designated code requirement, without a Team ID.

## Updating

Preserve the existing app identity and preferences. If setup opens again, choose **Set Up Later** to leave your current icon layout unchanged. Quitting shows icons in the menu bar and keeps your saved choices.

## Uninstall

Quit OverflowBar to reveal originals, then remove the app from Applications. Optional cleanup can remove its own preference, cache and HTTP-storage files. Never delete another application's menu-bar preferences.

## macOS blocks the arrow even with “Allow in the Menu Bar” enabled

Some Tahoe installations retain cross-app ownership references in Control Center’s protected `trackedApplications` state. A disabled app can then block OverflowBar’s items. This matches the failure documented in [CodexBar issue 1440](https://github.com/steipete/CodexBar/issues/1440). A status-item proxy window or enabled toggle does not prove the real arrow/divider is present.

OverflowBar makes one bounded control recreation attempt and leaves native icons accessible if it fails. Do not repeatedly reset Control Center, edit its protected preferences, or change the app’s bundle identifier. OverflowBar does not ship a Control Center repair tool. If its arrow remains unavailable, use **Settings → More → Reset Icon Selection** to restore all icons, then report the issue with your macOS version and OverflowBar build.
