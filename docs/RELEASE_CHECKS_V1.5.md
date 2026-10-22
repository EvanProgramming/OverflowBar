# OverflowBar v1.5.0 pre-release checks

**Verdict: NOT CLEARED FOR RELEASE.** Local automated and packaging checks pass after two confirmed blockers were fixed. Release approval remains blocked by untested installed-app behavior, endurance, physical compatibility, and Sparkle update installation.

## Candidate and environment

- Base commit: `4dfb1a43e14fa0be262925ff31d9495b97d8aa29`. The candidate changes in this report are in the worktree and are not committed.
- Candidate version/build: `1.5.0 (19)`; bundle identity remains `com.overflowbar.mac26.v6`; ad-hoc signing is retained.
- Environment: macOS 26.4 (25E246), Apple M3, Xcode 26.6 (17F113), internal display only. The installed app and preferences were backed up under `/private/tmp/OverflowBar-v15-installed-backup`; the installed app was not replaced.
- No release tag, GitHub release, or production feed was created or modified.

## Check results

| Check | Result | Evidence |
| --- | --- | --- |
| Targeted source review | **PASS** | Reviewed discovery and identity matching, native movement, activation/restoration, capture, helper authentication, preference migration, onboarding, and lifecycle paths with their associated tests. No additional confirmed runtime blocker was found; this does not replace the live acceptance gates below. |
| Debug XCTest | **PASS** | `xcodebuild -project OverflowBar.xcodeproj -scheme OverflowBar -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/OverflowBar-v15-final-debug CODE_SIGN_IDENTITY=- test`: 67 tests, 0 failures; one Accessibility-permission-dependent test skipped. |
| Xcode static analysis | **PASS** | `xcodebuild ... -configuration Debug ... CODE_SIGN_IDENTITY=- analyze`: `ANALYZE SUCCEEDED`. Xcode emitted only App Intents metadata and signed dependency stripping warnings. |
| Universal Release build and signing | **PASS** | `scripts/create-dmg.sh` completed for arm64 and x86_64. `codesign --verify --deep --strict` passed for the app and nested XPC/framework code. |
| Deployment metadata | **PASS** | App, EngineWorker, CaptureWorker, and native fixture contain arm64 and x86_64 slices and report macOS 15.0 minimum OS. `LSMinimumSystemVersion` and app version metadata are 15.0 and 1.5.0 (19). |
| DMG | **PASS** | `hdiutil verify` passed; mounted contents include the app, Applications symlink, and install guide; mounted app signature verified. SHA-256: `7d1dd8ea6268bd138e78c327659db17f74833750ed34bddc12efec76f7d2bb3c`. |
| Updater ZIP | **PASS** | Extracted app signature verified; archive contains only `OverflowBar.app`, retains Sparkle symlinks and executable permissions. SHA-256: `aeb2830d0f736fc9516019c8d78fdd573a12485f72948ca5c0abd3a7eeff6205`. |
| Native fixture build | **PASS** | Ad-hoc signature verified; arm64 and x86_64 slices, macOS 15.0 minimum. |
| Native-engine and documentation checks | **PASS** | `bash scripts/check-native-engine.sh`; `ruby scripts/check-doc-links.rb` (9 files); plist lint; shell syntax; `git diff --check`; all passed. References to the absent repair script were removed. |
| Homebrew cask | **PASS** | `bash scripts/validate-homebrew-cask.sh` passed. Cask SHA-256 matches the candidate DMG above. |
| Disposable Sparkle update installation | **PASS** | Downloaded the published v1.0.19 archive, staged a signed local HTTP appcast and v1.5.0 ZIP with an ephemeral test key, confirmed Sparkle 2.9.6 detected the update, installed it over a disposable copy, and verified version 1.5.0/build 19 and the resulting nested signature. No user-installed app or production feed was changed. |
| Release preflight workflow | **NOT TESTED** | `.github/workflows/preflight.yml` parses as YAML and its shell blocks pass `bash -n`. It now rehearses the published v1.0.19 app against the candidate using Sparkle 2.9.6. It was not dispatched; hosted CI and the production signing secret were not exercised. |
| Production-key Sparkle signing and tamper rejection | **NOT TESTED** | The workflow checks signed feed/archive acceptance and rejects archive/feed tampering, but this production-key path was not run. No production key was accessed. |
| Installed GUI acceptance | **NOT TESTED** | Native hide/show, captured previews, menu/popover/toggle ownership, Snapzy/Electron activation, keyboard and appearance behavior, permissions, helper interruption, reset/quit, wake, Spaces, fullscreen, and menu-bar auto-hide were not exercised. The Computer Use UI bridge was unavailable. |
| Activation cycles and endurance | **NOT TESTED** | No 100-cycle run, fixture response-counter record, or two-hour per-minute resource/error soak was completed. |
| macOS 15 and Intel hardware | **NOT TESTED** | No physical macOS 15 or Intel system was available. Rosetta availability does not substitute for hardware and OS acceptance. |
| Display configurations | **NOT TESTED** | Only the M3 internal display was available; external and vertically arranged display configurations were not tested. |

## Confirmed fixes

- Removed the CI call to missing `scripts/test-controlcenter-repair.py` and removed user-facing references to the absent optional repair tool.
- Fixed `scripts/create-dmg.sh` passing an empty array with `set -u`, which failed under macOS's Bash 3.2. Verified empty and populated argument expansion under `/bin/bash` 3.2; the universal package build then completed.
- Updated the candidate cask checksum to the verified candidate DMG and added a matching checksum assertion to the manual preflight workflow.

## Required before release

Run the installed-app, 100-cycle, and two-hour soak gates on macOS 26.4 and macOS 15; run Intel and unavailable display checks where hardware permits; dispatch the production-key preflight and retain its logs. If any package is rebuilt, rerun package verification and update the cask checksum to that exact distribution DMG. If TCC grants are stale, remove OverflowBar from **System Settings → Privacy & Security → Accessibility** and **Screen & System Audio Recording**, add the installed `/Applications/OverflowBar.app` again, then quit and reopen it. Do not use a successful build as a substitute for these gates.

## Artifact digests

- App executable: `616903637d3a2321648bbde13c8c3240e6748fa715afa9d4d81868da803bd929`
- EngineWorker: `39376fa2277d8ffff33a6f8549e8ff910c540f78cc8b992c6a627f18c19459db`
- CaptureWorker: `0a88d0252c2ce064aa6d8cfc58c2e2cb2605b2c1a84958f4f5cd3880701b28a0`
- Native fixture executable: `91077cbbb718ff4781829f6241829478f8ae8c67d06aab79f122b63493699eca`

The cask hash above matches the first verified candidate DMG. A second fresh package build produced DMG SHA-256 `5a14cc73cd9f4913f0698f6603f63f9e990b77896a5cb7f0445a6efe65523bae`, so package outputs are not byte-for-byte reproducible; refresh the cask hash for the exact DMG selected for distribution.
