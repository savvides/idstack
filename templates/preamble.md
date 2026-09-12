## Preamble: Interaction Conventions

idstack runs in Claude Code. Skill bodies use a few **concept names** for the tools they
lean on:

- **AskUserQuestion** — when a skill says "ask via AskUserQuestion" or "using AskUserQuestion",
  it means: present a single multiple-choice question (e.g., "Which of these best describes X?")
  and stop, waiting for the user's answer before proceeding. Ask **one** question at a time,
  never batch. This maps to the `AskUserQuestion` tool.
- **Agent (sub-task dispatch)** — when a skill says "if the Agent tool is available, dispatch
  X as a sub-task," that is a parallelization shortcut, never the definition of the work.
  The inline written-out steps that follow are; run them sequentially whenever dispatch is
  unavailable or fails. Four skills use it: accessibility-review, course-builder,
  course-quality-review, and red-team.
- **Skill (cross-skill invocation)** — used only by `/idstack:pipeline`, which invokes each
  child skill in-process via the `Skill` tool.
- **Skill invocation syntax in user-facing text** — every skill is invoked as
  `/idstack:<name>`. Always write the namespaced form: a bare `/<name>` is not a valid
  command. This applies in reports, manifests, and AskUserQuestion options as much as in
  chat output.

These are **directives to the model**, not magic words — interpret them as the protocol above.

## Preamble: Update Check

```bash
# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, then the Claude Code
# marketplace cache (highest version). Empty if none found; guard
# "$_IDSTACK/bin/..." calls accordingly.
# Canonical copy: templates/snippets/idstack-resolve.sh (the IDSTACK_RESOLVE
# placeholder in skill templates) — keep this block identical to it.
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
_UPD=$("$_IDSTACK/bin/idstack-update-check" 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD"
```

If the output contains `UPDATE_AVAILABLE`: tell the user "A newer version of idstack is available. Run `cd $_IDSTACK && git pull && ./setup` to update. (The `./setup` step is required — it cleans up legacy symlinks.)" Then continue normally.

## Preamble: Project Manifest

Before starting, check for an existing project manifest.

```bash
# (fresh shell — re-derive the install dir; see Preamble: Update Check)
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
if [ -f ".idstack/project.json" ]; then
  echo "MANIFEST_EXISTS"
  "$_IDSTACK/bin/idstack-migrate" .idstack/project.json 2>/dev/null || cat .idstack/project.json
else
  echo "NO_MANIFEST"
fi
```

**If MANIFEST_EXISTS:**
- Read the manifest. If the JSON is malformed, report the specific parse error to the
  user, offer to fix it, and STOP until it is valid. Never silently overwrite corrupt JSON.
- Preserve all existing sections when writing back.

**If NO_MANIFEST:**
- This skill will create or update the manifest during its workflow.

## Preamble: Preferences

```bash
if [ -f ".idstack/project.json" ] && command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
try:
    data = json.load(open('.idstack/project.json'))
    prefs = data.get('preferences', {})
    v = prefs.get('verbosity', 'normal')
    if v != 'normal':
        print(f'VERBOSITY:{v}')
except: pass
" 2>/dev/null || true
fi
```

**If VERBOSITY:concise:** Keep explanations brief. Skip evidence citations inline
(still follow evidence-based recommendations, just don't cite tier codes in output).
**If VERBOSITY:detailed:** Include full evidence citations, alternative approaches
considered, and rationale for each recommendation.
**If VERBOSITY:normal or not shown:** Default behavior — cite evidence tiers inline,
explain key decisions, skip exhaustive alternatives.

## Preamble: Designer Profile

```bash
_PROFILE="$HOME/.idstack/profile.yaml"
if [ -f "$_PROFILE" ]; then
  # Simple YAML parsing for experience_level (no dependency needed)
  _EXP=$(grep -E '^experience_level:' "$_PROFILE" 2>/dev/null | sed 's/experience_level:[[:space:]]*//' | tr -d '"' | tr -d "'")
  [ -n "$_EXP" ] && echo "EXPERIENCE:$_EXP"
else
  echo "NO_PROFILE"
fi
```

**If EXPERIENCE:novice:** Provide more context for recommendations. Explain WHY each
step matters, not just what to do. Define jargon on first use. Offer examples.
**If EXPERIENCE:intermediate:** Standard explanations. Assume familiarity with
instructional design concepts but explain idstack-specific patterns.
**If EXPERIENCE:expert:** Be concise. Skip basic explanations. Focus on evidence
tiers, edge cases, and advanced considerations. Trust the user's domain knowledge.
**If NO_PROFILE:** On first run, after the main workflow is underway (not before),
mention: "Tip: create `~/.idstack/profile.yaml` with `experience_level: novice|intermediate|expert`
to adjust how much detail idstack provides."

## Preamble: Evidence Engine & Consensus QA

Check whether a Consensus API key is configured for live literature grounding.

```bash
# Consensus key detection
# (fresh shell — re-derive the install dir; see Preamble: Update Check)
_IDSTACK=""
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _dir in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_dir" ] && [ -d "$_dir" ]; then _IDSTACK="${_dir%/}"; break; fi
done
_CONSENSUS_KEY=$("$_IDSTACK/bin/idstack-consensus" status 2>/dev/null | grep -q '"api_key_configured": true' && echo "CONFIGURED" || echo "UNCONFIGURED")
[ -n "$_CONSENSUS_KEY" ] && echo "CONSENSUS:$_CONSENSUS_KEY"
```

**If CONFIGURED:** Live literature grounding via Consensus API is active. Novel and
subject-specific pedagogical claims will be verified against peer-reviewed research.
**If UNCONFIGURED:** Running in zero-key mode using the curated evidence base. On first
run, after the main workflow is underway (not before), mention: "Tip: Set CONSENSUS_API_KEY
to enable live literature verification via Consensus."

## Preamble: Context Recovery

Check for session history and learnings from prior runs.

```bash
# Context recovery: timeline + learnings
# (fresh shell — re-derive the install dir; see Preamble: Update Check)
_IDSTACK=""
# Marketplace cache holds one dir per installed version. Sort the basenames by
# numeric version fields, not lexically — plain sort ranks 3.9.0.0 above
# 3.10.0.0 and would pick a stale install once the minor hits double digits.
_idstack_cache_root="$HOME/.claude/plugins/cache/idstack/idstack"
_idstack_cache=""
if [ -d "$_idstack_cache_root" ]; then
  _idstack_v=$(ls "$_idstack_cache_root" 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
  [ -n "$_idstack_v" ] && _idstack_cache="$_idstack_cache_root/$_idstack_v"
fi
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
_HAS_TIMELINE=0
_HAS_LEARNINGS=0
if [ -f ".idstack/timeline.jsonl" ]; then
  _HAS_TIMELINE=1
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
lines = open('.idstack/timeline.jsonl').readlines()[-200:]
events = []
for line in lines:
    try: events.append(json.loads(line))
    except: pass
if not events:
    sys.exit(0)

# Quality score trend
scores = [e for e in events if e.get('skill') == 'course-quality-review' and 'score' in e]
if scores:
    trend = ' -> '.join(str(s['score']) for s in scores[-5:])
    print(f'QUALITY_TREND: {trend}')
    last = scores[-1]
    dims = last.get('dimensions', {})
    if dims:
        tp = dims.get('teaching_presence', '?')
        sp = dims.get('social_presence', '?')
        cp = dims.get('cognitive_presence', '?')
        print(f'LAST_PRESENCE: T={tp} S={sp} C={cp}')

# Skills completed
completed = set()
for e in events:
    if e.get('event') == 'completed':
        completed.add(e.get('skill', ''))
# No f-string here: nesting same-type quotes in a replacement field is a
# SyntaxError before Python 3.12, and macOS system python3 is 3.9.
print('SKILLS_COMPLETED: ' + ','.join(sorted(completed)))

# Last skill run
last_completed = [e for e in events if e.get('event') == 'completed']
if last_completed:
    last = last_completed[-1]
    print(f'LAST_SKILL: {last.get(\"skill\",\"?\")} at {last.get(\"ts\",\"?\")}')

# Pipeline progression. course-import is the alternative entry point — it
# joins the chain before learning-objectives.
pipeline = [
    ('needs-analysis', 'learning-objectives'),
    ('course-import', 'learning-objectives'),
    ('learning-objectives', 'assessment-design'),
    ('assessment-design', 'course-builder'),
    ('course-builder', 'course-quality-review'),
    ('course-quality-review', 'accessibility-review'),
    ('accessibility-review', 'red-team'),
    ('red-team', 'course-export'),
]
for prev, nxt in pipeline:
    if prev in completed and nxt not in completed:
        print(f'SUGGESTED_NEXT: {nxt}')
        break
" 2>/dev/null || true
  else
    # No python3: show last 3 skill names only
    tail -3 .idstack/timeline.jsonl 2>/dev/null | grep -o '"skill":"[^"]*"' | sed 's/"skill":"//;s/"//' | while read s; do echo "RECENT_SKILL: $s"; done
  fi
fi
if [ -f ".idstack/learnings.jsonl" ]; then
  _HAS_LEARNINGS=1
  _LEARN_COUNT=$(wc -l < .idstack/learnings.jsonl 2>/dev/null | tr -d ' ')
  echo "LEARNINGS: $_LEARN_COUNT"
  if [ "$_LEARN_COUNT" -gt 0 ] 2>/dev/null; then
    "$_IDSTACK/bin/idstack-learnings-search" --limit 3 2>/dev/null || true
  fi
fi
```

**If QUALITY_TREND is shown:** Synthesize a welcome-back message. Example: "Welcome back.
Quality score trend: 62 -> 68 -> 72 over 3 reviews. Last skill: /idstack:learning-objectives."
Keep it to 2-3 sentences. If any dimension in LAST_PRESENCE is consistently below 5/10,
mention it as a recurring pattern with its evidence citation.

**If LAST_SKILL is shown but no QUALITY_TREND:** Just mention the last skill run.
Example: "Welcome back. Last session you ran /idstack:course-import."

**If SUGGESTED_NEXT is shown:** Mention the suggested next skill naturally.
Example: "Based on your progress, /idstack:assessment-design is the natural next step."

**If LEARNINGS > 0:** Mention relevant learnings if they apply to this skill's domain.
Example: "Reminder: this Canvas instance uses custom rubric formatting (discovered during import)."

---
