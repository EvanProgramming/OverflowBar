# Release process

OverflowBar uses semantic version tags and publishes installable DMGs plus
Sparkle ZIP/appcast assets through GitHub Releases. The DMG remains the primary
manual distribution path; the ZIP is the in-app update payload and the
third-party Homebrew Cask mirrors the DMG.

## Cadence

- **Patch release**: focused compatibility, capture, activation, or packaging fixes
- **Minor release**: a user-visible capability or meaningful workflow improvement
- **Major release**: an incompatible preference, architecture, or product-direction change

There is no release solely to satisfy a calendar. Important fixes should be released promptly; routine improvements are grouped into coherent updates.

## Checklist

1. Update `CFBundleShortVersionString` and increase `CFBundleVersion` in `OverflowBar/Resources/Info.plist`.
2. Update `Casks/overflowbar.rb` with the release version and the SHA-256 of the matching DMG.
3. Move user-visible changes into `CHANGELOG.md` and update `RELEASE_NOTES.md`.
4. Build Debug and Release configurations.
5. Run live checks:
   - arrow is present
   - selected native icons can be automatically arranged and hidden/revealed
   - second row opens and closes
   - genuine previews load and fresh AX/native activation opens the intended interface; uncertain items remain accessible
   - Safe Reset and normal quit reveal the group
   - macOS 27 leaves hiding disabled
   - 100 complete panel/activation cycles and a two-hour soak complete without input interference or resource growth
6. Build and verify the DMG and updater ZIP:

   ```bash
   ./scripts/create-dmg.sh
   hdiutil verify dist/OverflowBar-<version>.dmg
   shasum -a 256 -c dist/OverflowBar-<version>.dmg.sha256
   ```

   The release workflow also generates and signs `dist/appcast.xml` using the
   `SPARKLE_ED_KEY` GitHub Actions secret. Keep the private key out of the
   repository and publish only the public key in `Info.plist`.

7. Validate the Homebrew Cask metadata:

   ```bash
   bash scripts/validate-homebrew-cask.sh
   ```

8. Commit and push the release source.
9. Run **Release preflight** from Actions on that exact commit. It checks the
   production signing key, serves a staged feed locally, then probes and
   installs the signed ZIP over a disposable copy of the published v1.0.19 app.
   The preflight does not publish; its localhost appcast is test evidence and
   must not be used as a release feed.
10. Create a signed annotated tag on the verified commit and push it:

   ```bash
   git tag -s v<version> -m "OverflowBar <version>"
   git push origin v<version>
   ```

The tag triggers `.github/workflows/release.yml`, which validates version
parity and monotonic build numbers, builds the DMG and updater ZIP, generates
the signed appcast, and creates the GitHub Release with all updater assets. A
stable release is explicitly marked as the latest stable version.

11. After publication, download the exact DMG and its `.sha256` asset from that
release, verify them, then update `Casks/overflowbar.rb` to the published DMG's
checksum. DMG container hashes can vary between builds, so the cask must match
the artifact CI actually published. Push the checksum update to the default
branch so the documented Homebrew tap receives it.

## Signing

`scripts/create-dmg.sh` uses `DEVELOPER_ID_APPLICATION` when provided. Without it, the script creates an ad-hoc signed community build. Notarization must be added before describing a release as Gatekeeper-ready.

## Native validation policy

The [native validation matrix](NATIVE_VALIDATION.md) remains open follow-up validation for v1.5.0 and future releases. Generic placeholders, a widened divider, passing unit tests or a signed DMG are not native GUI evidence. The v1.5.0 release report records the physical checks waived for that release. Keep signed Sparkle generation in release CI, package both ad-hoc XPC services, and verify their current designated requirements from the installed application.
