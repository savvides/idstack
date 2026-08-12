#!/usr/bin/env python3
"""Validate documentation accuracy across version strings, manifest schemas, binaries, and links.

Usage: check-doc-accuracy.py <repo-root>
Prints diagnostic lines and exits 1 on mismatch; prints nothing and exits 0 when clean.
"""

import os
import re
import sys


def check_versions(root, problems):
    v_file = os.path.join(root, "VERSION")
    if not os.path.isfile(v_file):
        problems.append("missing VERSION file")
        return
    with open(v_file, "r", encoding="utf-8") as f:
        version = f.read().strip()

    ver3 = ".".join(version.split(".")[:3])

    plugin_json = os.path.join(root, ".claude-plugin", "plugin.json")
    if os.path.isfile(plugin_json):
        with open(plugin_json, "r", encoding="utf-8") as f:
            content = f.read()
            if ('"version": "%s"' % version) not in content and ('"version": "%s"' % ver3) not in content:
                problems.append(".claude-plugin/plugin.json version does not match VERSION (%s)" % version)
    else:
        problems.append("missing .claude-plugin/plugin.json file")

    readme = os.path.join(root, "README.md")
    if os.path.isfile(readme):
        with open(readme, "r", encoding="utf-8") as f:
            content = f.read()
            if ("v%s" % version) not in content and ("v%s" % ver3) not in content and version not in content:
                problems.append("README.md does not reference current version v%s" % version)
    else:
        problems.append("missing README.md file")

    index_html = os.path.join(root, "docs", "index.html")
    if os.path.isfile(index_html):
        with open(index_html, "r", encoding="utf-8") as f:
            content = f.read()
            if ("v%s" % version) not in content and ("v%s" % ver3) not in content:
                problems.append("docs/index.html does not reference current version v%s" % version)
    else:
        problems.append("missing docs/index.html file")


def check_manifest_schema_version(root, problems):
    schema_file = os.path.join(root, "templates", "manifest-schema.md")
    if os.path.isfile(schema_file):
        with open(schema_file, "r", encoding="utf-8") as f:
            content = f.read()
            if '"version": "1.4"' not in content:
                problems.append("templates/manifest-schema.md does not specify version 1.4")
    else:
        problems.append("missing templates/manifest-schema.md file")


def check_binaries_and_flags(root, problems):
    readme = os.path.join(root, "README.md")
    if not os.path.isfile(readme):
        return
    with open(readme, "r", encoding="utf-8") as f:
        text = f.read()

    # Look for bin/ paths referenced in README
    bin_refs = set(re.findall(r"\bbin/(?:[a-zA-Z0-9_-]+/)*[a-zA-Z0-9_-]+(?:\.[a-z]+)?", text))
    for ref in sorted(bin_refs):
        full_path = os.path.join(root, ref)
        if not os.path.isfile(full_path):
            problems.append("README.md references missing binary or file: %s" % ref)
        elif not ref.startswith("bin/lib/") and not os.access(full_path, os.X_OK):
            problems.append("README.md references non-executable binary: %s" % ref)


def check_public_surfaces(root, problems):
    v_file = os.path.join(root, "VERSION")
    if not os.path.isfile(v_file):
        problems.append("missing VERSION file")
        return
    with open(v_file, "r", encoding="utf-8") as f:
        version = f.read().strip()

    expected_ver = "v%s" % version

    index_html = os.path.join(root, "docs", "index.html")
    if os.path.isfile(index_html):
        with open(index_html, "r", encoding="utf-8") as f:
            content = f.read()
            if expected_ver not in content:
                problems.append("docs/index.html does not carry version %s" % expected_ver)
    else:
        problems.append("missing docs/index.html file")

    readme = os.path.join(root, "README.md")
    if os.path.isfile(readme):
        with open(readme, "r", encoding="utf-8") as f:
            content = f.read()
            header = "\n".join(content.splitlines()[:10])
            if expected_ver not in header:
                problems.append("README.md badge/header does not carry version %s" % expected_ver)
    else:
        problems.append("missing README.md file")


def main():
    if len(sys.argv) != 2:
        print("usage: check-doc-accuracy.py <repo-root>")
        return 2

    root = os.path.abspath(sys.argv[1])
    if not os.path.isdir(root):
        print("error: repository root directory not found: %s" % root)
        return 2

    problems = []
    check_versions(root, problems)
    check_manifest_schema_version(root, problems)
    check_binaries_and_flags(root, problems)
    check_public_surfaces(root, problems)

    for p in problems:
        print(p)

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

