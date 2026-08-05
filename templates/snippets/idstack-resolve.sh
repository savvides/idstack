# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, Codex-style symlinks, then
# the Claude Code marketplace cache (highest version). Empty if none found;
# guard "$_IDSTACK/bin/..." calls accordingly.
_IDSTACK=""
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$HOME/.agents/plugins/idstack" "$HOME/.agents/skills/idstack" "$(ls -d "$HOME"/.claude/plugins/cache/idstack/idstack/*/ 2>/dev/null | sort | tail -1)"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
