#!/usr/bin/env python3
"""Check local Markdown link targets, control characters, and SVG XML syntax."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
errors = []
count = 0
for path in sorted(ROOT.rglob("*.md")):
    if ".git" in path.parts or "build" in path.relative_to(ROOT).parts:
        continue
    text = path.read_text(encoding="utf-8")
    if any(ord(c) < 32 and c not in "\n\r\t" for c in text):
        errors.append(f"{path.relative_to(ROOT)}: unexpected control character")
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for target in re.findall(r"\]\(([^)]+)\)", text):
        target = target.strip().strip("<>")
        if urlsplit(target).scheme or target.startswith("#"):
            continue
        target = unquote(target.split("#", 1)[0])
        if target and not (path.parent / target).exists():
            errors.append(f"{path.relative_to(ROOT)}: missing target {target}")
        count += 1
for path in (ROOT / "docs" / "assets").glob("*.svg"):
    try:
        ET.parse(path)
    except ET.ParseError as exc:
        errors.append(f"{path.relative_to(ROOT)}: {exc}")
if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f"Documentation check passed ({count} local links).")
