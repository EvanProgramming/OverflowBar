# OverflowBar v1.5.0 release checks

**Verdict: RELEASED as the latest stable version on 2026-10-22.** The production-key Sparkle rehearsal, package build, release workflow, and published artifacts passed. The complete physical acceptance matrix was not run and was waived for this release; the untested items below are not represented as passing.

## Release and environment

- Release: [OverflowBar 1.5.0 — Native Engine Update](https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.5.0), stable (not a prerelease), marked latest.
- Signed tag `v1.5.0` points to `cf172457638835d4bd88c071f4e9c3df9816d70b` (version/build `1.5.0 (19)`). Bundle identity remains `com.overflowbar.mac26.v6`; ad-hoc signing is retained.
- The v1.0.19 release remains published as a manual fallback: [v1.0.19](https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.0.19). Sparkle does not downgrade automatically.
- Local environment: macOS 26.4 (25E246), Apple M3, Xcode 26.6 (17F113), internal display only. Hosted release checks ran on GitHub Actions `macos-26`.
- Production-key preflight: [run 39784573690](https://github.com/EvanProgramming/OverflowBar/actions/runs/39784573690), successful on the release-tag commit. Release publication: [run 39785595401](https://github.com/EvanProgramming/OverflowBar/actions/runs/39785595401), successful.

## Check results

| Check | Result | Evidence |
| --- | --- | --- |
| Targeted source review | **PASS** | Reviewed discovery and identity matching, native movement, activation/restoration, capture, helper authentication, preference migration, onboarding, and lifecycle paths with their tests. |
| Debug XCTest | **PASS** | Local and hosted Debug test runs: 67 tests, 0 failures; one Accessibility-permission-dependent test skipped. |
| Xcode static analysis | **PASS** | Local `xcodebuild ... analyze`: `ANALYZE SUCCEEDED`. |
| Universal Release build and nested signing | **PASS** | Hosted release build produced arm64 and x86_64 binaries; app, XPC services, and Sparkle framework signatures verified. |
| Deployment metadata | **PASS** | Published app, EngineWorker, and CaptureWorker contain arm64 and x86_64 slices and report macOS 15.0 minimum. Version/build is 1.5.0 (19). |
| macOS 26.4 native fixture subset | **PASS** | Recorded fixture checks hid four native items at real offscreen coordinates and restored them; menu activation reached the fixture owner; popover/toggle counters changed; recognizable fixture captures, Escape dismissal, and return to the hidden layout were observed. See the [implementation ledger](implementation/v1.5-engine-ledger.md). |
| Native-engine and documentation checks | **PASS** | `scripts/check-native-engine.sh`, documentation-link checks, plist lint, shell syntax, and `git diff --check` passed. The stale CI invocation of the absent repair script was removed. |
| Homebrew cask and published checksum | **PASS** | Cask metadata/style checks passed. Its SHA-256 matches the exact published DMG; the release `.sha256` asset and downloaded DMG also matched. |
| Published DMG | **PASS** | `hdiutil verify`, mounted contents, Applications symlink, and mounted app signature passed. SHA-256: `f18b2e8b9156e84e3d05083eb33a06d647fe6243f64fc641202051091d2db566`. |
| Published updater ZIP | **PASS** | Archive contains only `OverflowBar.app`; extracted app and nested signatures passed. SHA-256: `d171c0d00fcb984dd54877b871e18136dae86a9510edb1601cdaf2a5649fdcc9`. |
| Published appcast | **PASS** | Release appcast identifies version 1.5.0/build 19 and contains the archive EdDSA signature. Asset SHA-256: `61adb8c2a7f5469e968634930957de71f276f76b8af5259b1d81fb71599548cb`. |
| Production-key Sparkle rehearsal | **PASS** | The workflow signed and verified the candidate archive and appcast, rejected tampered archive/feed data, and installed v1.5.0/build 19 over a disposable copy of the published v1.0.19 app. The resulting nested signature verified. Production key material stayed in the GitHub Actions secret. |
| Stable/latest release state | **PASS** | GitHub's `/releases/latest` endpoint returns v1.5.0; release is neither draft nor prerelease. |
| Full third-party GUI acceptance | **NOT TESTED** | Snapzy and Electron tray response, permission denial/regrant, helper interruption/recycling, appearance/accessibility settings, relaunch/reset/quit, wake, Spaces, fullscreen, and auto-hide were not covered as a complete matrix. |
| 100 activation cycles and two-hour soak | **NOT TESTED** | No complete 100-cycle run, fixture-counter record for that run, or per-minute two-hour resource/error samples were collected. |
| macOS 15 and Intel hardware | **NOT TESTED** | No physical macOS 15 system or Intel hardware was available. Universal slices and the macOS 15 deployment floor were verified on the published package. |
| Display matrix | **NOT TESTED** | Only the internal display was available; external and vertically arranged display configurations were not exercised. |
| macOS 27 runtime readiness | **NOT TESTED** | The code retains a fail-open compatibility path, but macOS 27 runtime behavior was not exercised in this release audit. |

## Confirmed fixes

- Removed CI and documentation references to the absent optional Control Center repair tool.
- Fixed `scripts/create-dmg.sh` passing an empty array with `set -u`, which failed under macOS Bash 3.2.
- Added a nonpublishing production-key Sparkle preflight for the v1.0.19-to-v1.5.0 update path. Its first run exposed an incorrect XML-shape assumption in the feed-tampering probe; the probe was corrected and the second run passed.
- Updated the Homebrew cask to the checksum of the exact DMG produced by the release workflow. DMG hashes vary between builds, so the published artifact—not a local rebuild—is authoritative.

The release is usable as the latest stable update, with v1.0.19 retained for manual rollback. Confidence is strongest for automated checks and the recorded macOS 26.4 fixture flows; the physical matrix remains open validation work.
