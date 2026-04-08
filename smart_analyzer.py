#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from argparse import ArgumentParser
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _extension_key(path: Path) -> str:
    suffix = path.suffix.lower().lstrip(".")
    return suffix or "[no_extension]"


def analyze(base_path: str, out_path: str) -> dict[str, Any]:
    root = Path(base_path)
    output = Path(out_path)
    by_type: Counter[str] = Counter()
    total_size_bytes = 0
    files_count = 0
    directories_count = 0

    if root.exists():
        for current_root, dirnames, filenames in os.walk(root):
            directories_count += len(dirnames)
            current = Path(current_root)
            for name in sorted(filenames):
                path = current / name
                files_count += 1
                by_type[_extension_key(path)] += 1
                try:
                    total_size_bytes += path.stat().st_size
                except OSError:
                    continue

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "base_path": str(root),
        "files_count": files_count,
        "directories_count": directories_count,
        "total_size_bytes": total_size_bytes,
        "analysis_type": "SMART_ANALYSIS",
        "analysis_type_legacy": "SMART_ANALYSIS_LEGACY",
        "by_type": dict(sorted(by_type.items())),
        "top_extensions": [
            {"extension": extension, "count": count}
            for extension, count in sorted(by_type.items(), key=lambda item: (-item[1], item[0]))[:10]
        ],
    }

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    parser = ArgumentParser(description="Generate a lightweight SMART_ANALYSIS report")
    parser.add_argument("legacy_base", nargs="?", help="Legacy positional base path")
    parser.add_argument("legacy_out", nargs="?", help="Legacy positional output path")
    parser.add_argument("--base", dest="base", help="Directory to analyze")
    parser.add_argument("--out", dest="out", help="Destination JSON report")
    args = parser.parse_args()
    base = args.base or args.legacy_base
    out = args.out or args.legacy_out
    if not base or not out:
        parser.error("the following arguments are required: --base/legacy_base and --out/legacy_out")
    analyze(base, out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
