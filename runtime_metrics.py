#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import platform
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent


def _base_path() -> Path:
    raw = os.environ.get("BASE_PATH") or os.environ.get("DJPT_BASE_DIR")
    return Path(raw).resolve() if raw else ROOT


def _memory_percent() -> float:
    if sys.platform == "darwin":
        vm = subprocess.run(["vm_stat"], capture_output=True, text=True, check=False)
        if vm.returncode == 0:
            page_size = 4096
            stats: dict[str, int] = {}
            for line in vm.stdout.splitlines():
                if ":" not in line:
                    continue
                key, value = line.split(":", 1)
                value = value.strip().rstrip(".")
                value = value.replace(".", "")
                if value.isdigit():
                    stats[key.strip()] = int(value)
            total = sum(stats.values())
            free = stats.get("Pages free", 0) + stats.get("Pages speculative", 0)
            used = max(total - free, 0)
            if total:
                return round((used / total) * 100.0, 2)
    elif Path("/proc/meminfo").exists():
        meminfo = {}
        for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            token = value.strip().split()[0]
            if token.isdigit():
                meminfo[key] = int(token)
        total = meminfo.get("MemTotal", 0)
        available = meminfo.get("MemAvailable", meminfo.get("MemFree", 0))
        if total:
            return round(((total - available) / total) * 100.0, 2)
    return 0.0


def _cpu_percent() -> float:
    try:
        load1 = os.getloadavg()[0]
        cores = os.cpu_count() or 1
        return round((load1 / cores) * 100.0, 2)
    except OSError:
        return 0.0


def _throughput_files_per_min(base: Path, sample_limit: int) -> float:
    started = time.perf_counter()
    count = 0
    for _, _, files in os.walk(base):
        count += len(files)
        if count >= sample_limit:
            count = sample_limit
            break
    elapsed = max(time.perf_counter() - started, 0.001)
    return round(count / (elapsed / 60.0), 2)


def collect_metrics(base: Path) -> dict[str, Any]:
    return {
        "status": "ok",
        "base_path": str(base),
        "cpu_percent": _cpu_percent(),
        "memory_percent": _memory_percent(),
        "throughput_files_per_min": _throughput_files_per_min(base, 512),
        "machine": platform.machine(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Collect lightweight runtime metrics")
    parser.add_argument("--base-path")
    args = parser.parse_args()
    base = Path(args.base_path).resolve() if args.base_path else _base_path()
    print(json.dumps(collect_metrics(base), indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
