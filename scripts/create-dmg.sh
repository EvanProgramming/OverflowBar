#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/OverflowBar/Resources/Info.plist")}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.release-build}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
APP="$DERIVED_DATA/Build/Products/Release/OverflowBar.app"
DMG="$OUTPUT_DIR/OverflowBar-$VERSION.dmg"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/overflowbar-dmg.XXXXXX")"

cleanup() {
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

hdiutil create \
    -volname "OverflowBar $VERSION" \
    -srcfolder "$STAGING" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$DMG"

(cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$DMG")") | tee "$DMG.sha256"
echo "Created $DMG"
