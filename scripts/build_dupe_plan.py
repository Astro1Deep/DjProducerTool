#!/usr/bin/env python3
import argparse
import collections
from pathlib import Path


def parse_hash_index(path):
    entries = collections.defaultdict(list)
    with path.open("r", encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            h = parts[0]
            full = parts[2]
            entries[h].append(full)
    return entries


def parse_external(path):
    entries = collections.defaultdict(list)
    with path.open("r", encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t", 1)
            if len(parts) != 2:
                continue
            h, full = parts
            entries[h].append(full)
    return entries


def write_plan(entries, plan_path):
    with plan_path.open("w", encoding="utf-8") as plan:
        for h, paths in entries.items():
            if len(paths) < 2:
                continue
            for idx, p in enumerate(paths):
                action = "KEEP" if idx == 0 else "QUARANTINE"
                plan.write(f"{h}\t{action}\t{p}\n")


def write_tmp(entries, tmp_path):
    with tmp_path.open("w", encoding="utf-8") as tmp:
        for h, paths in entries.items():
            for p in paths:
                tmp.write(f"{h}\t{p}\n")


def main():
    parser = argparse.ArgumentParser(description="Regenerate duplicate plan + report.")
    parser.add_argument(
        "--hash-index",
        type=Path,
        required=True,
        help="hash_index.tsv (BASE_PATH)",
    )
    parser.add_argument(
        "--external",
        type=Path,
        required=True,
        help="external_hashes.tsv",
    )
    parser.add_argument(
        "--plan",
        type=Path,
        required=True,
        help="Output plan path",
    )
    parser.add_argument(
        "--tmp",
        type=Path,
        required=True,
        help="General hashes tmp storage",
    )
    parser.add_argument(
        "--report",
        type=Path,
        required=True,
        help="Report path",
    )

    args = parser.parse_args()
    base_entries = parse_hash_index(args.hash_index)
    external_entries = parse_external(args.external)

    merged = collections.defaultdict(list)
    for h, paths in base_entries.items():
        merged[h].extend(paths)
    for h, paths in external_entries.items():
        merged[h].extend(paths)

    write_tmp(merged, args.tmp)
    write_plan(merged, args.plan)

    dupe_hashes = [h for h, p in merged.items() if len(p) > 1]
    processed = sum(len(p) for p in merged.values())

    with args.report.open("w", encoding="utf-8") as report:
        report.write("HASH_DUPES_REPORT\n")
        report.write(f"Roots: {args.external.parents[0]}\n")
        report.write(f"Archivos procesados: {processed}\n")
        report.write(f"Hashes con duplicados: {len(dupe_hashes)}\n")
        report.write(f"Plan: {args.plan}\n")

    print(f"[OK] Plan duplicados: {args.plan}")
    print(f"[OK] Reporte: {args.report}")


if __name__ == "__main__":
    main()
