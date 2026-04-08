#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import time
from pathlib import Path
from typing import Any

from scripts.lib.report_json import write_report

ROOT = Path(__file__).resolve().parent


def _base_path() -> Path:
    raw = os.environ.get("BASE_PATH") or os.environ.get("DJPT_BASE_DIR")
    return Path(raw).resolve() if raw else ROOT


def _state_dir() -> Path:
    raw = os.environ.get("STATE_DIR") or os.environ.get("DJPT_STATE_DIR")
    if raw:
        return Path(raw).resolve()
    base = _base_path()
    return base if base.name == "_DJProducerTools" else base / "_DJProducerTools"


def _reports_dir() -> Path:
    raw = os.environ.get("REPORTS_DIR")
    return Path(raw).resolve() if raw else _state_dir() / "reports"


def run_benchmark(base_path: Path, sample_limit: int) -> dict[str, Any]:
    files: list[Path] = []
    walk_started = time.perf_counter()
    for root, _, filenames in os.walk(base_path):
        for name in sorted(filenames):
            files.append(Path(root) / name)
            if len(files) >= sample_limit:
                break
        if len(files) >= sample_limit:
            break
    walk_ms = round((time.perf_counter() - walk_started) * 1000.0, 3)

    hash_started = time.perf_counter()
    digests = []
    for path in files:
        try:
            data = path.read_bytes()[:8192]
        except OSError:
            data = b""
        digests.append(hashlib.sha1(data).hexdigest())
    hash_ms = round((time.perf_counter() - hash_started) * 1000.0, 3)
    throughput = round(len(files) / max((walk_ms + hash_ms) / 60000.0, 0.001), 2)
    return {
        "status": "ok",
        "base_path": str(base_path),
        "files_sampled": len(files),
        "walk_ms": walk_ms,
        "hash_ms": hash_ms,
        "throughput_files_per_min": throughput,
        "sample_hashes": digests[:5],
        "hardware": {"machine": os.uname().machine, "sysname": os.uname().sysname},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Deterministic system benchmark")
    parser.add_argument("--base-path")
    parser.add_argument("--sample-limit", type=int, default=32)
    parser.add_argument("--json-out")
    args = parser.parse_args()

    base = Path(args.base_path).resolve() if args.base_path else _base_path()
    payload = run_benchmark(base, max(1, args.sample_limit))
    out = Path(args.json_out) if args.json_out else _reports_dir() / "benchmark_system_report.json"
    write_report(payload, out, schema_version="djpt.benchmark_system.v1")
    payload["report_path"] = str(out)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
