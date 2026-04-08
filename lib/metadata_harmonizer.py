#!/usr/bin/env python3
import argparse
import os
import re
from pathlib import Path

WEB_PATTERNS = ("http://", "https://", "www.", "soundcloud", "youtube")


def _iter_candidates(base: Path, limit: int = 2000):
    count = 0
    for root, dirs, files in os.walk(base):
        dirs.sort()
        files.sort()
        for name in files:
            full = Path(root) / name
            yield full
            count += 1
            if count >= limit:
                return


def harmonize(out: str, lang: str = "en") -> int:
    out_path = Path(out).expanduser().resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    base = Path(os.environ.get("BASE_PATH", ".")).expanduser().resolve()
    if not base.exists() or not base.is_dir():
        base = Path.cwd()

    rows = []

    for path in _iter_candidates(base):
        name = path.name
        rel = path.relative_to(base) if path.is_relative_to(base) else path

        if any(tag in name.lower() for tag in WEB_PATTERNS):
            rows.append(
                (
                    "filename",
                    f"web_tag_detected ({rel})",
                    "remove web/source tags from filename",
                )
            )

        if "  " in name:
            rows.append(
                (
                    "filename",
                    f"double_spaces ({rel})",
                    "collapse duplicate spaces",
                )
            )

        if re.search(r"\s+[-_]\s+", name):
            rows.append(
                (
                    "filename",
                    f"inconsistent_separator ({rel})",
                    "use single separator pattern",
                )
            )

        if not Path(name).suffix:
            rows.append(
                (
                    "extension",
                    f"missing_extension ({rel})",
                    "verify and append correct extension",
                )
            )

    if not rows:
        rows.append(
            (
                "global",
                "no_major_issues_detected",
                "keep current naming policy",
            )
        )

    with out_path.open("w", encoding="utf-8") as fh:
        fh.write("Field\tIssue\tAction\n")
        for field, issue, action in rows:
            fh.write(f"{field}\t{issue}\t{action}\n")

    print(f"Plan saved to {out_path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate metadata harmonization plan.")
    parser.add_argument("--out", required=True)
    parser.add_argument("--lang", default="en")
    args = parser.parse_args()
    return harmonize(args.out, args.lang)


if __name__ == "__main__":
    raise SystemExit(main())
