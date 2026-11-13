#!/usr/bin/env python3
"""Validate documentation accuracy: version strings, the manifest schema version, scripts/ and test/ path references, removed date fields, and the landing page's search tags, headings, text size and that it gives no number of studies.

Usage: check-doc-accuracy.py <repo-root>
Prints diagnostic lines and exits 1 on mismatch; prints nothing and exits 0 when clean.
"""

import html
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

    plugin_json = os.path.join(root, ".claude-plugin", "plugin.json")
    if os.path.isfile(plugin_json):
        with open(plugin_json, "r", encoding="utf-8") as f:
            content = f.read()
            if ('"version": "%s"' % version) not in content:
                problems.append(".claude-plugin/plugin.json version does not match VERSION (%s)" % version)
    else:
        problems.append("missing .claude-plugin/plugin.json file")

    readme = os.path.join(root, "README.md")
    if os.path.isfile(readme):
        with open(readme, "r", encoding="utf-8") as f:
            content = f.read()
            if ("v%s" % version) not in content:
                problems.append("README.md does not reference current version v%s" % version)
    else:
        problems.append("missing README.md file")

    index_html = os.path.join(root, "docs", "index.html")
    if os.path.isfile(index_html):
        with open(index_html, "r", encoding="utf-8") as f:
            content = f.read()
            if ("v%s" % version) not in content:
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

    # Look for scripts/ paths referenced in README
    bin_refs = set(re.findall(r"\bscripts/(?:[a-zA-Z0-9_-]+/)*[a-zA-Z0-9_-]+(?:\.[a-z]+)?", text))
    for ref in sorted(bin_refs):
        full_path = os.path.join(root, ref)
        if not os.path.isfile(full_path):
            problems.append("README.md references missing binary or file: %s" % ref)
        elif not ref.startswith("scripts/lib/") and not os.access(full_path, os.X_OK):
            problems.append("README.md references non-executable binary: %s" % ref)


def check_no_stale_dates(root, problems):
    """Assert two deleted date fields have not come back.

    docs/index.html carried a JSON-LD "dateModified" and docs/sitemap.xml a
    <lastmod>. Both were deleted rather than corrected: no CI check can assert
    such a date is current without failing on commits that did not introduce
    the defect (a PR left open a week, a merge dated after the docs edit), and
    a check that cries wolf is one people learn to bypass. Absence is the only
    assertion here that cannot false-positive.
    """
    index_html = os.path.join(root, "docs", "index.html")
    if os.path.isfile(index_html):
        with open(index_html, "r", encoding="utf-8") as f:
            if "dateModified" in f.read():
                problems.append(
                    "docs/index.html reintroduced dateModified; it was removed "
                    "because it cannot be kept accurate (spec D2)"
                )

    sitemap = os.path.join(root, "docs", "sitemap.xml")
    if os.path.isfile(sitemap):
        with open(sitemap, "r", encoding="utf-8") as f:
            if "lastmod" in f.read():
                problems.append(
                    "docs/sitemap.xml reintroduced lastmod; it was removed "
                    "because it cannot be kept accurate (spec D2)"
                )


def check_public_surfaces(root, problems):
    v_file = os.path.join(root, "VERSION")
    if not os.path.isfile(v_file):
        problems.append("missing VERSION file")
        return
    with open(v_file, "r", encoding="utf-8") as f:
        version = f.read().strip()

    expected_ver = "v%s" % version
    expected_software_ver = '"softwareVersion": "%s"' % version

    index_html = os.path.join(root, "docs", "index.html")
    if os.path.isfile(index_html):
        with open(index_html, "r", encoding="utf-8") as f:
            content = f.read()
            if expected_ver not in content:
                problems.append("docs/index.html does not carry version %s" % expected_ver)
            if expected_software_ver not in content:
                problems.append("docs/index.html LD+JSON metadata does not match softwareVersion %s" % version)
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


def check_landing_page(root, problems):
    """Assert the search and readability facts of docs/index.html, docs/404.html and docs/llms.txt.

    The font-size check reads only a plain number in rem or px, such as
    "0.7rem" or "11px". A value in em, clamp(), max() or % depends on its
    parent or the viewport, so a static check cannot find its real size: it
    is skipped. The font shorthand is skipped too.
    """
    index_html = os.path.join(root, "docs", "index.html")
    if not os.path.isfile(index_html):
        return  # check_versions reports the missing file
    with open(index_html, "r", encoding="utf-8") as f:
        page = f.read()

    def first(pattern):
        m = re.search(pattern, page, re.S)
        return html.unescape(m.group(1)) if m else None

    title = first(r"<title>(.*?)</title>")
    description = first(r'<meta name="description" content="([^"]*)"')
    og_title = first(r'<meta property="og:title" content="([^"]*)"')
    tw_title = first(r'<meta name="twitter:title" content="([^"]*)"')

    h1s = re.findall(r"<h1\b[^>]*>(.*?)</h1>", page, re.S)
    if len(re.findall(r"<h1\b", page)) != 1 or len(h1s) != 1:
        problems.append("docs/index.html must have exactly one <h1>")
    elif "instructional design" not in re.sub(r"<[^>]+>", "", h1s[0]).lower():
        problems.append('docs/index.html <h1> does not contain "instructional design"')

    if title is None or len(title) > 65:
        problems.append("docs/index.html <title> is missing or over 65 characters")
    if description is None or len(description) > 160:
        problems.append("docs/index.html meta description is missing or over 160 characters")
    if not (title is not None and title == og_title == tw_title):
        problems.append("docs/index.html <title>, og:title and twitter:title are not equal")
    if '<meta name="keywords"' in page:
        problems.append("docs/index.html has a keywords meta tag; it was removed on purpose")

    # No number of studies: a literature review changes the numbers.
    body = re.search(r"<body\b[^>]*>(.*)</body>", page, re.S)
    body = re.sub(r"<(script|style)\b.*?</\1>|<!--.*?-->", " ", body.group(1) if body else "", flags=re.S | re.I)
    visible = [re.sub(r"<[^>]+>", " ", body), title or ""]
    visible += re.findall(r'<meta (?:name="description"|property="og:[^"]*"|name="twitter:[^"]*") content="([^"]*)"', page)
    for text in visible:
        m = re.search(r"\b\d[\d,]*\s+(?:peer-reviewed\s+)?(?:studies|references|papers)\b", html.unescape(text), re.I)
        if m:
            problems.append('docs/index.html gives a number of studies: "%s"' % m.group(0))

    for size, unit in re.findall(r"font-size:\s*([\d.]+)(rem|px)\b", page):
        if float(size) < (0.75 if unit == "rem" else 12):
            problems.append("docs/index.html has font-size %s%s, below 12px (0.75rem)" % (size, unit))

    install, pipeline = page.find('id="install"'), page.find('id="pipeline"')
    if not 0 <= install < pipeline:
        problems.append('docs/index.html: id="install" must come before id="pipeline"')

    for name in ("404.html", "llms.txt"):
        if not os.path.isfile(os.path.join(root, "docs", name)):
            problems.append("missing docs/%s file" % name)
    not_found = os.path.join(root, "docs", "404.html")
    if os.path.isfile(not_found):
        with open(not_found, "r", encoding="utf-8") as f:
            if "noindex" not in f.read():
                problems.append("docs/404.html has no noindex robots tag")


def check_developer_surfaces(root, problems):
    dev_files = ["CLAUDE.md", "DESIGN.md", "CONTRIBUTING.md", "ROADMAP.md"]
    for f in dev_files:
        p = os.path.join(root, f)
        if not os.path.isfile(p):
            problems.append("missing developer surface file: %s" % f)

    claude_md = os.path.join(root, "CLAUDE.md")
    if os.path.isfile(claude_md):
        with open(claude_md, "r", encoding="utf-8") as f:
            content = f.read()
            if "353 assertions" in content:
                problems.append("CLAUDE.md contains stale assertion count (353 assertions)")

            required_commands = [
                "test/smoke-test.sh",
                "test/mutation-test.sh",
                "test/check-evidence-cards.py",
                "test/check-doc-accuracy.py",
            ]
            for cmd in required_commands:
                if cmd not in content:
                    problems.append("CLAUDE.md missing test command reference: %s" % cmd)

            test_refs = set(re.findall(r"\btest/[a-zA-Z0-9_-]+\.(?:sh|py|js)\b", content))
            for ref in sorted(test_refs):
                if not os.path.isfile(os.path.join(root, ref)):
                    problems.append("CLAUDE.md references missing test file: %s" % ref)

    contributing_md = os.path.join(root, "CONTRIBUTING.md")
    if os.path.isfile(contributing_md):
        with open(contributing_md, "r", encoding="utf-8") as f:
            content = f.read()
            required_commands = [
                "test/smoke-test.sh",
                "test/mutation-test.sh",
                "test/check-evidence-cards.py",
                "test/check-doc-accuracy.py",
            ]
            for cmd in required_commands:
                if cmd not in content:
                    problems.append("CONTRIBUTING.md missing test command reference: %s" % cmd)

            test_refs = set(re.findall(r"\btest/[a-zA-Z0-9_-]+\.(?:sh|py|js)\b", content))
            for ref in sorted(test_refs):
                if not os.path.isfile(os.path.join(root, ref)):
                    problems.append("CONTRIBUTING.md references missing test file: %s" % ref)

    design_md = os.path.join(root, "DESIGN.md")
    if os.path.isfile(design_md):
        with open(design_md, "r", encoding="utf-8") as f:
            content = f.read()
            required_paths = [
                "docs/index.html",
                "templates/report.md.tmpl",
                "templates/index.md.tmpl",
            ]
            for path_ref in required_paths:
                if path_ref not in content:
                    problems.append("DESIGN.md missing path reference: %s" % path_ref)
                elif not os.path.isfile(os.path.join(root, path_ref)):
                    problems.append("DESIGN.md references missing file: %s" % path_ref)


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
    check_no_stale_dates(root, problems)
    check_landing_page(root, problems)
    check_developer_surfaces(root, problems)

    for p in problems:
        print(p)

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

