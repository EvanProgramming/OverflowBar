#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="${1:-/private/tmp/OverflowBarNativeFixture.app}"
mkdir -p "$FIXTURE_DIR/Contents/MacOS"
BUILD_DIR="$(mktemp -d /private/tmp/overflowbar-fixture-build.XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT
for architecture in arm64 x86_64; do
    xcrun swiftc "$ROOT/NativeFixtures/main.swift" -target "$architecture-apple-macos15.0" -framework AppKit -o "$BUILD_DIR/$architecture"
done
lipo -create "$BUILD_DIR/arm64" "$BUILD_DIR/x86_64" -output "$FIXTURE_DIR/Contents/MacOS/OverflowBarNativeFixture"
cat > "$FIXTURE_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.overflowbar.nativefixture</string><key>CFBundleExecutable</key><string>OverflowBarNativeFixture</string><key>CFBundleName</key><string>OverflowBar Native Fixture</string><key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/><key>LSMinimumSystemVersion</key><string>15.0</string></dict></plist>
PLIST
codesign --force --sign - "$FIXTURE_DIR"
codesign --verify --deep --strict "$FIXTURE_DIR"
printf '%s\n' "$FIXTURE_DIR"
