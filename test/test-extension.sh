#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Running idstack Chrome Extension test suite..."
node "$DIR/test-manifest.js"
node "$DIR/test-prompts.js"
node "$DIR/test-extractor.js"
node "$DIR/test-crawler.js"
node "$DIR/test-service-worker.js"
node "$DIR/test-dossier-compiler.js"
node "$DIR/test-sidepanel-dom.js"
node "$DIR/test-sidepanel-logic.js"

echo "==> All Chrome Extension tests passed!"
