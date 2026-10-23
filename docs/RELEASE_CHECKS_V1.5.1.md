# OverflowBar v1.5.1 release checks

**Verdict: RELEASED as the latest stable version on 2026-10-23.** The user accepted the visual result. Automated source, package, and publication checks passed; physical coverage that was not run is listed separately.

## Release and environment

- Release: [OverflowBar 1.5.1 — Automatic Icon Hiding and Retry](https://github.com/EvanProgramming/OverflowBar/releases/tag/v1.5.1), stable, not a prerelease, and marked latest.
- Signed tag `v1.5.1` points to `b7d1c4c9e770e5e962aa1851872009cc28106bc1`; the signed source commit is verified. Version/build is 1.5.1 (20). Bundle ID remains `com.overflowbar.mac26.v6`.
- Release preflight: [run 39958284968](https://github.com/EvanProgramming/OverflowBar/actions/runs/39958284968), successful on the release source commit. Release publication: [run 39959261366](https://github.com/EvanProgramming/OverflowBar/actions/runs/39959261366), successful.
- The v1.0.19 release remains available for manual fallback. Sparkle does not automatically downgrade.

## Check results

| Check | Result | Evidence |
| --- | --- | --- |
| Focused store tests | **PASS** | Five tests cover first-inventory seeding, saved-order discovery, persistence across store instances, hiding-off behavior, protected and unstable items, and retry serialization. |
| Full XCTest suite | **PASS** | 72 tests executed, 0 failures; one Accessibility-dependent test skipped. The hosted preflight also built Debug and ran the suite. |
| Debug and universal Release builds | **PASS** | Local and hosted Debug checks passed; local and release-workflow Release builds produced arm64 and x86_64 slices. |
| Native-engine, documentation, plist, cask and source checks | **PASS** | Native-engine check, documentation links, plist lint, shell syntax, `git diff --check`, Homebrew cask style, and metadata validation passed. |
| Release preflight and Sparkle rehearsal | **PASS** | The production-key workflow installed v1.5.1/build 20 over a disposable v1.0.19 app, validated signatures, and rejected a tampered archive and appcast. Key material stayed in GitHub Actions. |
| Published DMG | **PASS** | Release workflow and independent download passed `hdiutil verify` and the published `.sha256` check. SHA-256: `5260412c515f5806db701e9b741e741e6bd352903d987d1babbffd6f1039d0f7`. |
| Published updater ZIP | **PASS** | SHA-256: `31cc0d686bc541ba28ba1974dbdeb72c1940ba9d1e6b8aa53fe738096c9436d0`. Archive contains only `OverflowBar.app`; the extracted app and nested signatures verify. |
| Published appcast | **PASS** | SHA-256: `c9998fde3f658c3f6991201ab2fe2570b2d5433ffaeec1a3224008c7d18555c4`. It identifies version 1.5.1/build 20, links the published updater ZIP, and contains an EdDSA signature. |
| Homebrew cask | **PASS** | Version is 1.5.1 and the cask SHA-256 matches the exact published DMG. Cask metadata and style checks passed. |
| User visual acceptance | **ACCEPTED** | The user confirmed acceptance. A fresh Computer Use capture was unavailable because the native pipe closed, so no new screenshot evidence was collected. |
| Stable/latest state | **PASS** | GitHub lists v1.5.1 as Latest; the release is neither draft nor prerelease. |

## Native and hardware limits

- Physical macOS 15 and Intel systems were unavailable. External and vertical displays, the full permission revocation/regrant matrix, and macOS 27 runtime were not tested for this release.
- A 100-cycle interaction run and a two-hour resource soak were not performed.
- The CUA observation issue is recorded separately from the user's visual acceptance; it is not represented as a completed agent-observed check.
