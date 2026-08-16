#!/usr/bin/env bash
set -euo pipefail

# package-extension.sh — Packages the idstack Chrome Extension for Chrome Web Store submission

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXT_DIR="$REPO_ROOT/extension"
BUILD_DIR="$REPO_ROOT/build"
ZIP_NAME="idstack-chrome-extension-v1.0.0.zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"

echo "==> Verifying extension test suite..."
"$REPO_ROOT/test/test-extension.sh"

echo "==> Creating build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
rm -f "$ZIP_PATH"

echo "==> Packaging extension from $EXT_DIR..."
# Zip contents directly so manifest.json is at root of archive
(cd "$EXT_DIR" && zip -r "$ZIP_PATH" . -x "*.DS_Store" "*__MACOSX*" "*.git*")

echo ""
echo "✅ Extension packaged successfully!"
echo "📦 Archive path: $ZIP_PATH"
echo "📏 Archive size: $(du -h "$ZIP_PATH" | cut -f1)"
echo ""
echo "To publish to the Chrome Web Store:"
echo "1. Go to https://chrome.google.com/webstore/devconsole"
echo "2. Click 'New Item'"
echo "3. Upload: $ZIP_PATH"
