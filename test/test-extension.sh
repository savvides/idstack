#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

# The tests import the shipped extension modules directly. extension/ has no
# package.json (Chrome needs none), so Node must detect ES module syntax in .js
# files itself: on by default from Node 20.19 and 22.7.
if ! node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=7)||(a===20&&b>=19)?0:1)'; then
  echo "test-extension.sh needs Node >= 20.19 or >= 22.7 (found $(node --version))" >&2
  exit 1
fi

# Test the shipped file, never a copy: hand-maintained .cjs twins let the tests
# pass against code the extension never ran.
if find "$DIR/../extension" -name '*.cjs' | grep .; then
  echo "extension/ must not contain .cjs copies; tests import the shipped .js" >&2
  exit 1
fi

echo "==> Running idstack Chrome Extension test suite..."
node "$DIR/test-manifest.js"
node "$DIR/test-sidepanel-dom.js"
for t in "$DIR"/test-*.mjs; do
  node "$t"
done

echo "==> All Chrome Extension tests passed!"
