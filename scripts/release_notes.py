#!/usr/bin/env python3
"""Extract a release's section from CHANGELOG.md as markdown.

The release workflow feeds this same markdown into two places:
- the GitHub release body, and
- the Sparkle appcast <description sparkle:format="markdown">, which Sparkle
  2.9+ renders natively in the in-app updater (no HTML conversion needed).

Usage:
    release_notes.py md <version>   # e.g. 0.1.3 or v0.1.3

Prints nothing (exit 0) when the version has no section, so the workflow can
fall back gracefully instead of failing the release.
"""

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


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] != "md":
        print("usage: release_notes.py md <version>", file=sys.stderr)
        return 2
    version = sys.argv[2]
    version = version[1:] if version.startswith("v") else version
    sys.stdout.write(extract(version))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
