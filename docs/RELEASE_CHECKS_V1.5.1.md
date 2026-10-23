# OverflowBar v1.5.1 release checks

**Release status: PREPARING.** The local tests, builds, and candidate package checks have passed. CI preflight, publication, and verification of the exact hosted artifacts remain outstanding.

## Release scope

Version 1.5.1 adds automatic selection of newly discovered eligible icons while hiding is enabled, a serialized Settings retry action, and the previously accepted Liquid Glass backdrop color fix. The app keeps bundle ID `com.overflowbar.mac26.v6`, its existing preference keys, and the signed Sparkle update feed. The build number is 20, following v1.5.0 build 19.

## Checks

| Check | Result | Evidence |
| --- | --- | --- |
| Focused behavior tests | **PASS** | Five `MenuBarItemStoreTests` cover initial inventory seeding, saved-order discovery, persistence across store instances, hiding-off behavior, protected/unstable items, and retry serialization. |
| Full XCTest suite | **PASS** | 72 tests executed, 0 failures; one Accessibility-dependent test skipped. |
| Debug build | **PASS** | Local Xcode build for macOS. |
| Universal Release build | **PASS** | Local Xcode Release build produced arm64 and x86_64 slices. |
| Installed candidate and nested signatures | **PASS** | Candidate was installed at `/Applications/OverflowBar.app`; app, helpers, and embedded frameworks passed strict nested signature verification. |
| User visual acceptance | **ACCEPTED** | The user confirmed acceptance of the requested visual result. A fresh Computer Use capture was unavailable in this session, so there is no new screenshot evidence. |
| Native engine, documentation, plist, cask, and source checks | **PASS** | `scripts/check-native-engine.sh`, `scripts/check-doc-links.rb`, `plutil`, `git diff --check`, and Homebrew Cask metadata validation passed. |
| Release preflight and production Sparkle signing | **PENDING** | Must pass on the exact commit before creating the release tag. |
| Published DMG, updater ZIP, appcast and Homebrew checksum | **PENDING** | Verify the exact artifacts produced by release CI; the published DMG checksum is authoritative for the cask. |

## Local candidate package

- Version/build: 1.5.1 (20), bundle ID `com.overflowbar.mac26.v6`.
- Universal app: `arm64` and `x86_64`; nested app, helper, and framework signatures passed strict verification.
- DMG: `hdiutil verify` passed. Local SHA-256: `baad6cb510798dd677b1ad16965d8bb513023c65d5615fabef02767124d6b041`.
- The local DMG checksum is provisional. Update the cask with the checksum from the exact published release asset.

## Hardware and runtime limits

- Physical macOS 15 and Intel systems were unavailable. The compatibility matrix, external/vertical displays, permission revocation and regrant, and macOS 27 runtime were not tested for this release.
- A 100-cycle interaction run and a two-hour resource soak were not performed.
- The fresh Computer Use observation was blocked by the native-pipe error; the user's explicit visual acceptance is recorded separately from a new agent-observed capture.

## Distribution

The release workflow must publish the signed tag as a stable latest release with a universal DMG, updater ZIP, and EdDSA-signed appcast. After publication, download the actual DMG, verify its checksum and signature, and update `Casks/overflowbar.rb` with that published DMG's SHA-256.
