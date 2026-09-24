#!/usr/bin/env bash
set -euo pipefail

# package-extension.sh — Packages the idstack Chrome Extension for Chrome Web Store submission

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXT_DIR="$REPO_ROOT/extension"
BUILD_DIR="$REPO_ROOT/build"
# The zip is named for the version in manifest.json, so a release bump cannot ship a stale name.
ZIP_NAME="idstack-chrome-extension-v$(node -p 'require(process.argv[1]).version' "$EXT_DIR/manifest.json").zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"

echo "==> Verifying extension test suite..."
"$REPO_ROOT/test/test-extension.sh"

echo "==> Creating build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
rm -f "$ZIP_PATH"

echo "==> Packaging extension from $EXT_DIR..."
# Zip contents directly so manifest.json is at root of archive
# icons/generate-icons.js is a dev-time script that drew the PNGs; it is not part of the extension.
(cd "$EXT_DIR" && zip -r "$ZIP_PATH" . -x "*.DS_Store" "*__MACOSX*" "*.git*" "icons/generate-icons.js")

echo ""
echo "✅ Extension packaged successfully!"
echo "📦 Archive path: $ZIP_PATH"
echo "📏 Archive size: $(du -h "$ZIP_PATH" | cut -f1)"
echo ""
echo "To publish to the Chrome Web Store:"
echo "1. Go to https://chrome.google.com/webstore/devconsole"
echo "2. Click 'New Item'"
echo "3. Upload: $ZIP_PATH"
