# Release process

OverflowBar uses semantic version tags and publishes installable DMGs through GitHub Releases.
The DMG is the primary distribution path; the third-party Homebrew Cask mirrors
the same versioned DMG and checksum as an alternative installation method.

## Cadence

- **Patch release**: focused compatibility, capture, activation, or packaging fixes
- **Minor release**: a user-visible capability or meaningful workflow improvement
- **Major release**: an incompatible preference, architecture, or product-direction change

There is no release solely to satisfy a calendar. Important fixes should be released promptly; routine improvements are grouped into coherent updates.

## Checklist

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `OverflowBar/Resources/Info.plist`.
2. Update `Casks/overflowbar.rb` with the release version and the SHA-256 of the matching DMG.
3. Move user-visible changes into `CHANGELOG.md` and update `RELEASE_NOTES.md`.
4. Build Debug and Release configurations.
5. Run live checks:
   - arrow is present
   - selected third-party items are managed
   - protected system items remain visible
   - second row opens and closes
   - direct and temporary-reveal activation work
   - Safe Reset and normal quit restore the layout
6. Build and verify the DMG:

   ```bash
   ./scripts/create-dmg.sh
   hdiutil verify dist/OverflowBar-<version>.dmg
   shasum -a 256 -c dist/OverflowBar-<version>.dmg.sha256
   ```

7. Validate the Homebrew Cask metadata:

   ```bash
   bash scripts/validate-homebrew-cask.sh
   ```

8. Commit and push the release source.
9. Tag the exact release commit:

   ```bash
   git tag v<version>
   git push origin v<version>
   ```

The tag triggers `.github/workflows/release.yml`, which validates version parity, builds the DMG, and creates the GitHub Release with the checksum attached.

## Signing

`scripts/create-dmg.sh` uses `DEVELOPER_ID_APPLICATION` when provided. Without it, the script creates an ad-hoc signed community build. Notarization must be added before describing a release as Gatekeeper-ready.
