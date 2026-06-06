#!/usr/bin/env bash
# Unit tests for bin/idstack-gen-skills.
# Run from the repo root (or sourced by smoke-test.sh).

set -e

PASS=0
FAIL=0
TOTAL=0

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN_SKILLS="$REPO_ROOT/bin/idstack-gen-skills"

assert() {
  TOTAL=$((TOTAL + 1))
  if eval "$2" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    echo "  PASS: $1"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $1"
  fi
}

if [ ! -x "$GEN_SKILLS" ]; then
  echo "test-gen-skills: $GEN_SKILLS missing or not executable"
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

seed_workspace() {
  # Clean existing items before seeding to avoid permission issues or stale files
  rm -rf "$WORK"/* "$WORK"/.??* 2>/dev/null || true
  mkdir -p "$WORK/bin" "$WORK/templates/assets" "$WORK/skills/test-skill"
  cp "$GEN_SKILLS" "$WORK/bin/"

  echo "PREAMBLE CONTENT" > "$WORK/templates/preamble.md"
  echo "SCHEMA CONTENT" > "$WORK/templates/manifest-schema.md"
  touch "$WORK/templates/report.html.tmpl"
  touch "$WORK/templates/index.html.tmpl"
  touch "$WORK/templates/assets/idstack.css"
  echo "AGENT CONTEXT" > "$WORK/templates/agent-context.md"

  cat > "$WORK/skills/test-skill/SKILL.md.tmpl" <<'INNER_EOF'
---
name: test-skill
allowed-tools:
  - tool1
  - tool2
description: test
---
{{PREAMBLE}}
some content
{{MANIFEST_SCHEMA}}
INNER_EOF
}

echo "test-gen-skills"
echo ""

# --- Test 1: Missing templates fail ---
seed_workspace
rm "$WORK/templates/preamble.md"
set +e
"$WORK/bin/idstack-gen-skills" --target claude >/dev/null 2>&1
EC=$?
set -e
assert "missing template exits 1" "[ $EC -eq 1 ]"

# --- Test 2: claude target generation ---
seed_workspace
"$WORK/bin/idstack-gen-skills" --target claude >/dev/null 2>&1
assert "claude target creates SKILL.md" "[ -f \"$WORK/skills/test-skill/SKILL.md\" ]"
assert "claude target substitutes PREAMBLE" "grep -q 'PREAMBLE CONTENT' \"$WORK/skills/test-skill/SKILL.md\""
assert "claude target substitutes MANIFEST_SCHEMA" "grep -q 'SCHEMA CONTENT' \"$WORK/skills/test-skill/SKILL.md\""
assert "claude target preserves allowed-tools" "grep -q 'allowed-tools:' \"$WORK/skills/test-skill/SKILL.md\""
assert "claude target injects auto-generated header" "grep -q 'AUTO-GENERATED' \"$WORK/skills/test-skill/SKILL.md\""
assert "codex target NOT created" "[ ! -f \"$WORK/dist/codex/skills/idstack-test-skill/SKILL.md\" ]"
assert "AGENTS.md NOT created" "[ ! -f \"$WORK/AGENTS.md\" ]"

# --- Test 3: codex target generation ---
seed_workspace
"$WORK/bin/idstack-gen-skills" --target codex >/dev/null 2>&1
assert "codex target creates SKILL.md" "[ -f \"$WORK/dist/codex/skills/idstack-test-skill/SKILL.md\" ]"
assert "codex target substitutes PREAMBLE" "grep -q 'PREAMBLE CONTENT' \"$WORK/dist/codex/skills/idstack-test-skill/SKILL.md\""
assert "codex target strips allowed-tools" "! grep -q 'allowed-tools:' \"$WORK/dist/codex/skills/idstack-test-skill/SKILL.md\""
assert "AGENTS.md is created" "[ -f \"$WORK/AGENTS.md\" ]"
assert "claude target NOT created" "[ ! -f \"$WORK/skills/test-skill/SKILL.md\" ]"

# --- Test 4: all target generation ---
seed_workspace
"$WORK/bin/idstack-gen-skills" >/dev/null 2>&1
assert "all target creates claude SKILL.md" "[ -f \"$WORK/skills/test-skill/SKILL.md\" ]"
assert "all target creates codex SKILL.md" "[ -f \"$WORK/dist/codex/skills/idstack-test-skill/SKILL.md\" ]"
assert "all target creates AGENTS.md" "[ -f \"$WORK/AGENTS.md\" ]"

# --- Test 5: --dry-run behavior ---
seed_workspace
"$WORK/bin/idstack-gen-skills" --target claude >/dev/null 2>&1
assert "dry-run passes when fresh" "$WORK/bin/idstack-gen-skills --dry-run --target claude >/dev/null 2>&1"
echo "stale" >> "$WORK/skills/test-skill/SKILL.md"
set +e
"$WORK/bin/idstack-gen-skills" --dry-run --target claude >/dev/null 2>&1
EC=$?
set -e
assert "dry-run exits 1 when stale" "[ $EC -eq 1 ]"

# --- Test 6: Invalid target ---
seed_workspace
set +e
"$WORK/bin/idstack-gen-skills" --target bogus >/dev/null 2>&1
EC=$?
set -e
assert "invalid target exits 2" "[ $EC -eq 2 ]"

echo ""
echo "test-gen-skills: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
