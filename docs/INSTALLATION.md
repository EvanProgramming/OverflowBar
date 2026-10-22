# Installation

OverflowBar targets macOS 15 and macOS 26, on Intel and Apple Silicon. The v1.5 engine is a release candidate until its [physical validation gates](NATIVE_VALIDATION.md) pass. Do not treat a successful build as a stable release.

## Install

Download a published OverflowBar DMG from the official GitHub releases, drag the app to Applications and open it. The first launch opens setup; later launches open Menu Bar. For local candidate validation, use the verified universal build installed in Applications.

## First launch and Gatekeeper

Community builds remain ad-hoc signed and are not notarized. Follow macOS's **Open Anyway** flow for a build you trust if Gatekeeper blocks launch. No paid Developer ID certificate is required. Existing signed Sparkle updates remain enabled; candidate publication is gated separately.

## Permissions

Accessibility enables automatic icon arrangement and native activation. Screen Recording enables actual status-icon captures. Captures are local and in-memory; see [privacy](../PRIVACY.md). Screen Recording changes can require app relaunch. After replacing a local ad-hoc-signed build in Applications, remove the old OverflowBar entry and add `/Applications/OverflowBar.app` again under **Privacy & Security > Accessibility** and **Screen & System Audio Recording**, then quit and reopen OverflowBar. The ad-hoc signature changes between builds, so the old entry may look enabled while the new build is denied.

Embedded discovery and capture helpers are ad-hoc signed too. They authenticate the currently packaged app by designated code requirement, without a Team ID. Candidate verification must exercise their permission attribution from the installed application.

## Updating

Preserve the existing app identity and preferences. If setup opens again, choose **Set Up Later** to leave your current icon layout unchanged. Quitting shows icons in the menu bar and keeps your saved choices.

## Uninstall

Quit OverflowBar to reveal originals, then remove the app from Applications. Optional cleanup can remove its own preference, cache and HTTP-storage files. Never delete another application's menu-bar preferences.

## macOS blocks the arrow even with “Allow in the Menu Bar” enabled

Some Tahoe installations retain cross-app ownership references in Control Center’s protected `trackedApplications` state. A disabled app can then block OverflowBar’s items. This matches the failure documented in [CodexBar issue 1440](https://github.com/steipete/CodexBar/issues/1440). A status-item proxy window or enabled toggle does not prove the real arrow/divider is present.

OverflowBar makes one bounded control recreation attempt and leaves native icons accessible if it fails. Do not repeatedly reset the whole Control Center or change the app’s bundle identifier. The optional `scripts/repair-controlcenter-overflowbar.py` tool defaults to a dry run. It requires explicit user authorization and a process allowed to read the protected preferences. With `--apply`, it retains a complete backup beside the original, enables only OverflowBar’s record and removes only foreign mappings to `com.overflowbar.mac26.v6`. It refuses unexpected schemas, duplicate owners and concurrent file changes. Other apps’ allow flags and unrelated settings stay unchanged. Reload the user preference daemon and Control Center after an approved repair. The application never performs this protected-file repair automatically.
