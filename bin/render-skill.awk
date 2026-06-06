BEGIN {
  after_frontmatter = 0
  frontmatter_count = 0
  in_allowed_tools = 0
}
/^---$/ {
  frontmatter_count++
  print
  if (frontmatter_count == 2) {
    print header
    print header2
    print ""
  }
  in_allowed_tools = 0
  next
}
# Strip the `allowed-tools:` block from frontmatter for codex target.
# The block runs from `allowed-tools:` until the next non-indented sibling
# key or the closing `---`. Match is case-insensitive and rejects leading
# whitespace so a stray indented duplicate cannot bypass the strip.
frontmatter_count == 1 && target == "codex" {
  if (in_allowed_tools) {
    if ($0 ~ /^[^ \t-]/) {
      in_allowed_tools = 0
      # fall through to print this line (the next sibling key)
    } else {
      next  # still inside allowed-tools list, skip
    }
  }
  if (tolower($0) ~ /^allowed-tools:[[:space:]]*$/) {
    in_allowed_tools = 1
    next
  }
}
/\{\{PREAMBLE\}\}/ {
  while ((getline line < preamble_file) > 0) print line
  close(preamble_file)
  next
}
/\{\{MANIFEST_SCHEMA\}\}/ {
  while ((getline line < schema_file) > 0) print line
  close(schema_file)
  next
}
{ print }
