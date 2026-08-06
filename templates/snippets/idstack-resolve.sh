# Resolve the idstack install dir. Re-derived at the top of every bash block —
# blocks run in separate shells, so a value derived in an earlier block is not
# available here. Priority: explicit env overrides, Codex-style symlinks, then
# the Claude Code marketplace cache. Empty if none found; guard
# "$_IDSTACK/bin/..." calls accordingly.
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
for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${IDSTACK_HOME:-}" "$HOME/.agents/plugins/idstack" "$HOME/.agents/skills/idstack" "$_idstack_cache"; do
  if [ -n "$_p" ] && [ -d "$_p" ]; then _IDSTACK="${_p%/}"; break; fi
done
