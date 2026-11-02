"""Check repository Markdown links locally. No network or hardware access."""

from pathlib import Path
from urllib.parse import unquote, urlsplit
import html
import os
import re
import sys

ROOT = Path(__file__).resolve().parents[2]


def visible(text):
    lines = []
    fence = None
    for line in text.splitlines():
        match = re.match(r"^\s*(`{3,}|~{3,})", line)
        if match:
            char = match[1][0]
            if fence is None:
                fence = char
            elif fence == char:
                fence = None
            lines.append("")
        else:
            lines.append(line if fence is None else "")
    return "\n".join(lines)


def anchors(text):
    used = {}
    result = set(re.findall(r'<a\s+id=["\']([^"\']+)["\']', text))
    for heading in re.findall(r"^#{1,6}\s+(.+?)\s*#*$", visible(text), re.M):
        heading = (
            re.sub(r"<[^>]+>", "", html.unescape(heading)).lower().replace("`", "")
        )
        slug = re.sub(r"[^\w\- ]", "", heading).replace(" ", "-")
        count = used.get(slug, 0)
        used[slug] = count + 1
        result.add(slug + ("-" + str(count) if count else ""))
    return result


def main():
    files = [
        ROOT / "README.md",
        ROOT / "AGENTS.md",
        ROOT / "CONTRIBUTING.md",
        *sorted((ROOT / "docs").glob("*.md")),
        *sorted((ROOT / "tools").glob("*.md")),
    ]
    failures = []
    checked = 0
    cache = {}
    for source in files:
        body = visible(source.read_text(encoding="utf-8"))
        for match in re.finditer(
            r'!?\[[^\]\n]*\]\((<[^>]+>|[^\s)]+)(?:\s+"[^"]*")?\)', body
        ):
            raw = match[1].strip("<>")
            url = urlsplit(raw)
            if url.scheme or url.netloc:
                continue
            path = unquote(url.path)
            target = (
                (ROOT / path.lstrip("/"))
                if path.startswith("/")
                else (source.parent / path)
            )
            target = target.resolve() if path else source.resolve()
            checked += 1
            reason = None
            if not target.is_relative_to(ROOT):
                reason = "link escapes repository"
            elif target.is_relative_to(ROOT / "local"):
                reason = "public link points to private local material"
            elif not target.exists():
                reason = "missing target"
            elif path:
                # Windows accepts filename case that GitHub/Linux do not.
                candidate = (
                    (ROOT / path.lstrip("/"))
                    if path.startswith("/")
                    else (source.parent / path)
                )
                relative = Path(os.path.normpath(str(candidate))).relative_to(ROOT)
                cursor = ROOT
                for part in relative.parts:
                    if part not in {entry.name for entry in cursor.iterdir()}:
                        reason = "filename case differs from repository"
                        break
                    cursor /= part
            if (
                reason is None
                and target.exists()
                and url.fragment
                and target.suffix.lower() == ".md"
            ):
                if target not in cache:
                    cache[target] = anchors(target.read_text(encoding="utf-8"))
                if unquote(url.fragment) not in cache[target]:
                    reason = "missing section"
            if reason:
                line = body[: match.start()].count("\n") + 1
                failures.append(f"{source.relative_to(ROOT)}:{line}: {reason}: {raw}")
    if failures:
        print("\n".join(failures))
        return 1
    print(
        f"Checked {checked} local links across {len(files)} Markdown files. No network requests."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
