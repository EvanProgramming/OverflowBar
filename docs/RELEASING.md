# Release process

OverflowBar publishes DMGs and Sparkle ZIP/appcast assets through GitHub Releases. The DMG is the primary manual download; the third-party Homebrew Cask mirrors the published DMG.

## Release cadence

- Patch: focused compatibility, capture, activation, or packaging fixes.
- Minor: a user-visible capability or meaningful workflow improvement.
- Major: an incompatible preference, architecture, or product-direction change.

There is no release solely to meet a calendar.

## Release checklist

1. Update CFBundleShortVersionString and increment CFBundleVersion in OverflowBar/Resources/Info.plist.
2. Update the Cask version in Casks/overflowbar.rb.
3. Update CHANGELOG.md and RELEASE_NOTES.md with user-visible changes.
4. Build Debug and Release configurations, run XCTest, and run the native-engine and package checks.
5. Run the [native acceptance matrix](NATIVE_VALIDATION.md). Builds and generic icons do not establish physical GUI reliability.
6. Build and verify the DMG and updater ZIP:

        ./scripts/create-dmg.sh
        hdiutil verify dist/OverflowBar-<version>.dmg
        shasum -a 256 -c dist/OverflowBar-<version>.dmg.sha256

   CI signs appcast.xml with the SPARKLE_ED_KEY GitHub Actions secret. Keep the private key out of the repository.
7. Run Homebrew Cask and documentation-link checks:

        bash scripts/validate-homebrew-cask.sh
        ruby scripts/check-doc-links.rb

8. Commit and push the release source. Run **Release preflight** from Actions against that exact commit. Preflight checks the production signing key and exercises the signed updater over a disposable copy of the published v1.0.19 app. It does not publish; never use its localhost feed as a release feed.
9. Create a signed annotated version tag on the verified commit and push it:

        git tag -s v<version> -m "OverflowBar <version>"
        git push origin v<version>

10. After publication, download the exact DMG and its checksum file. Verify both and update the Cask SHA-256 to the checksum of the published artifact, then push the Cask update to the default branch.
11. Check that the release page, installer links, README badge, and Homebrew Cask agree.

The tag triggers .github/workflows/release.yml, which validates version parity and monotonic build numbers, builds the DMG and updater ZIP, signs the Sparkle feed, and publishes the GitHub Release. A stable release is marked as latest.

If published release notes need correction, update RELEASE_NOTES.md on the default branch and run **Refresh release notes** from Actions for that version. The workflow verifies a refreshed signed appcast and updates the release without rebuilding the app.

## Signing and community builds

scripts/create-dmg.sh uses DEVELOPER_ID_APPLICATION when set. Otherwise it ad-hoc signs the community build, which is not notarized. Do not describe an ad-hoc build as notarized or as Gatekeeper-approved. The Homebrew Cask uses the exact published DMG checksum, which can vary between builds.

## Related guides

[Development](DEVELOPMENT.md) · [Homebrew](HOMEBREW.md) · [Installation](INSTALLATION.md) · [Native validation](NATIVE_VALIDATION.md)
