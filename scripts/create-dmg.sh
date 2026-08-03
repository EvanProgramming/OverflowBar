#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/OverflowBar/Resources/Info.plist")}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.release-build}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
APP="$DERIVED_DATA/Build/Products/Release/OverflowBar.app"
DMG="$OUTPUT_DIR/OverflowBar-$VERSION.dmg"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/overflowbar-dmg.XXXXXX")"
MOUNT_POINT=""

cleanup() {
    if [[ -n "$MOUNT_POINT" ]]; then
        hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
    fi
    rm -rf "$STAGING"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
rm -f "$DMG" "$DMG.sha256"

xcodebuild \
    -project "$ROOT/OverflowBar.xcodeproj" \
    -scheme OverflowBar \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO \
    build

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    codesign --force --deep --options runtime --timestamp \
        --sign "$DEVELOPER_ID_APPLICATION" "$APP"
else
    codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"

ditto "$APP" "$STAGING/OverflowBar.app"
ln -s /Applications "$STAGING/Applications"

mkdir -p "$STAGING/.background"
swiftc "$ROOT/scripts/make-dmg-background.swift" -o "$STAGING/.make-dmg-background"
"$STAGING/.make-dmg-background" "$STAGING/.background/Background.png"
rm -f "$STAGING/.make-dmg-background"
printf '%s\n' \
    'Before You Install' \
    '' \
    'macOS may show a warning that OverflowBar is from an unidentified developer or cannot be verified.' \
    'This happens because this local distribution is not notarized by Apple. The warning does not mean' \
    'the app contains malware. Download OverflowBar only from the official GitHub release, then open' \
    'System Settings > Privacy & Security and choose Open Anyway if macOS blocks the first launch.' \
    '' \
    'OverflowBar needs Accessibility and Screen Recording permissions to discover and manage menu-bar items.' \
    > "$STAGING/Install Guide.txt"

hdiutil create \
    -volname "OverflowBar $VERSION" \
    -srcfolder "$STAGING" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG"

# Configure a friendly Finder presentation. This is best-effort because Finder
# is unavailable in some headless build environments; the background and guide
# remain inside the DMG even when icon placement cannot be saved.
ATTACH_OUTPUT="$(hdiutil attach -nobrowse "$DMG")"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | sed -n 's#^.*\(/Volumes/.*\)$#\1#p' | tail -1)"
if [[ -n "$MOUNT_POINT" ]]; then
    osascript >/dev/null <<OSA
tell application "Finder"
    tell disk "OverflowBar $VERSION"
        open
        set current view of container window to icon view
        set bounds of container window to {120, 120, 1020, 680}
        set iconOptions to icon view options of container window
        set icon size of iconOptions to 112
        set background picture of iconOptions to POSIX file "$MOUNT_POINT/.background/Background.png"
        set position of item "OverflowBar.app" to {220, 300}
        set position of item "Applications" to {680, 300}
        set position of item "Install Guide.txt" to {450, 115}
        close
        open
    end tell
end tell
OSA
    sync
fi
hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
MOUNT_POINT=""

(cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$DMG")") | tee "$DMG.sha256"
echo "Created $DMG"
