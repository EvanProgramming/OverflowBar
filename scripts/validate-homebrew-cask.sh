#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_TAP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/overflowbar-homebrew-tap.XXXXXX")"
TAP_NAME="evanprogramming/overflowbar-ci"

cleanup() {
    brew untap "$TAP_NAME" >/dev/null 2>&1 || true
    rm -rf "$TEST_TAP_DIR"
}
trap cleanup EXIT

ruby "$ROOT/scripts/check-homebrew-cask.rb"

mkdir -p "$TEST_TAP_DIR/Casks"
cp "$ROOT/Casks/overflowbar.rb" "$TEST_TAP_DIR/Casks/overflowbar.rb"
git -C "$TEST_TAP_DIR" init -q
git -C "$TEST_TAP_DIR" add Casks/overflowbar.rb
git -C "$TEST_TAP_DIR" \
    -c user.name="OverflowBar CI" \
    -c user.email="overflowbar-ci@example.invalid" \
    commit -qm "Add OverflowBar cask"

HOMEBREW_NO_AUTO_UPDATE=1 brew tap "$TAP_NAME" "$TEST_TAP_DIR" >/dev/null
HOMEBREW_NO_AUTO_UPDATE=1 brew style --cask "$TAP_NAME/overflowbar"
HOMEBREW_NO_AUTO_UPDATE=1 brew info --cask "$TAP_NAME/overflowbar" >/dev/null

echo "Homebrew Cask passed validation in a temporary tap"
