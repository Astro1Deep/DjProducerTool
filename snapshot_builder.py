#!/usr/bin/env python3
"""Generate a fast integrity snapshot for a library tree."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path

MEDIA_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg", ".mp4", ".mov", ".avi"}


def quick_fingerprint(path: Path) -> str:
    digest = hashlib.sha1()
    with path.open("rb") as handle:
        digest.update(handle.read(65536))
    return digest.hexdigest()[:16]


def build_snapshot(base: Path, out: Path) -> int:
    base = base.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    rows = 0
    with out.open("w", encoding="utf-8") as handle:
        for root, dirs, files in os.walk(base):
            dirs[:] = [entry for entry in dirs if not entry.startswith(".") and entry != "_DJProducerTools"]
            for name in sorted(files):
                full = Path(root) / name
                if full.suffix.lower() not in MEDIA_EXTS:
                    continue
                stat = full.stat()
                rel = full.relative_to(base)
                handle.write(
                    f"{rel}\t{full}\t{stat.st_size}\t{int(stat.st_mtime)}\t{quick_fingerprint(full)}\n"
                )
                rows += 1

    print(f"[OK] Snapshot saved to {out} ({rows} rows)")
    return 0


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Build a fast DJPT snapshot TSV.")
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    return build_snapshot(Path(args.base), Path(args.out))


if __name__ == "__main__":
    raise SystemExit(main())
