#!/usr/bin/env python3
import argparse
import hashlib
import os
import sys
from pathlib import Path


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(
        description="Hash a root path and append results to an external hashes index."
    )
    parser.add_argument("--root", required=True, type=Path, help="External directory root.")
    parser.add_argument(
        "--external-file",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "_DJProducerTools" / "external_hashes.tsv",
        help="Path to external hashes TSV.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit the number of files hashed this run (0 = no limit).",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="Print progress for each hashed file."
    )
    args = parser.parse_args()

    root = args.root.expanduser()
    if not root.is_dir():
        print(f"[ERROR] root '{root}' is not a directory.", file=sys.stderr)
        sys.exit(1)
    existing = set()
    if args.external_file.exists():
        with args.external_file.open("r", encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t", 1)
                if len(parts) == 2:
                    existing.add(parts[1])

    hashed = 0
    encoded_limit = args.limit
    with args.external_file.open("a", encoding="utf-8") as out:
        for dirpath, _, filenames in os.walk(root):
            for name in filenames:
                path = os.path.join(dirpath, name)
                if path in existing:
                    continue
                try:
                    digest = sha256_file(path)
                except PermissionError:
                    continue
                out.write(f"{digest}\t{path}\n")
                hashed += 1
                if args.verbose:
                    print(f"[HASHED] {path}")
                if encoded_limit > 0 and hashed >= encoded_limit:
                    print(f"[INFO] Limit reached ({encoded_limit}). Files hashed: {hashed}")
                    sys.exit(2)
    if hashed == 0:
        print(f"[INFO] No new files hashed under '{root}'.")
        sys.exit(0)
    print(f"[INFO] Root '{root}' hashed {hashed} files.")
    sys.exit(0)


if __name__ == "__main__":
    main()
