#!/usr/bin/env python3
"""Extract a release's section from CHANGELOG.md, as markdown or HTML.

The release workflow uses this to feed real "what's new" notes into two places:
- the GitHub release body (markdown), and
- the Sparkle appcast <description> (HTML, shown in the in-app updater).

Usage:
    release_notes.py md   <version>   # e.g. 0.1.3 or v0.1.3
    release_notes.py html <version>

Prints nothing (exit 0) when the version has no section, so the workflow can
fall back gracefully instead of failing the release.
"""

import html
import re
import sys
from pathlib import Path

CHANGELOG = Path(__file__).resolve().parent.parent / "CHANGELOG.md"


def extract(version: str) -> str:
    """Return the markdown under '## [<version>] ...', without that header line."""
    lines = CHANGELOG.read_text(encoding="utf-8").splitlines()
    header = re.compile(r"^## \[" + re.escape(version) + r"\]")
    start = next((i + 1 for i, line in enumerate(lines) if header.match(line)), None)
    if start is None:
        return ""
    body = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        body.append(line)
    return "\n".join(body).strip("\n")


def inline(text: str) -> str:
    """Render inline markdown (links, bold, code) to HTML, escaping everything else."""
    text = html.escape(text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return text


def to_html(md: str) -> str:
    """Convert our changelog subset (### headers + bullet lists) to HTML.

    Bullets may wrap onto continuation lines indented by two spaces; join those
    back onto the bullet before rendering.
    """
    joined: list[str] = []
    for line in md.splitlines():
        if line[:2] == "  " and joined and joined[-1].lstrip().startswith("- "):
            joined[-1] = joined[-1].rstrip() + " " + line.strip()
        else:
            joined.append(line)

    out: list[str] = []
    in_list = False

    def close_list() -> None:
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    for line in joined:
        stripped = line.strip()
        if stripped.startswith("### "):
            close_list()
            out.append(f"<h3>{inline(stripped[4:])}</h3>")
        elif stripped.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(stripped[2:])}</li>")
        elif stripped:
            close_list()
            out.append(f"<p>{inline(stripped)}</p>")
    close_list()
    return "\n".join(out)


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in {"md", "html"}:
        print("usage: release_notes.py {md|html} <version>", file=sys.stderr)
        return 2
    mode = sys.argv[1]
    version = sys.argv[2]
    version = version[1:] if version.startswith("v") else version
    md = extract(version)
    sys.stdout.write(to_html(md) if mode == "html" else md)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
