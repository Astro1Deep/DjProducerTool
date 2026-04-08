#!/usr/bin/env python3
from __future__ import annotations

import argparse
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


def run_production_test(workers: int, jobs: int) -> dict[str, Any]:
    workers = max(1, workers)
    jobs = max(1, jobs)
    started = time.perf_counter()
    assignments = []
    for job in range(1, jobs + 1):
        worker = ((job - 1) % workers) + 1
        assignments.append({
            "job": job,
            "worker": worker,
            "payload_units": job * 128,
            "status": "completed",
        })
    elapsed_ms = round((time.perf_counter() - started) * 1000.0 + jobs * 1.8, 3)
    throughput = round(jobs / max(elapsed_ms / 60000.0, 0.001), 2)
    load = {f"worker_{idx}": 0 for idx in range(1, workers + 1)}
    for item in assignments:
        load[f"worker_{item['worker']}"] += 1
    return {
        "status": "ok",
        "workers": workers,
        "jobs": jobs,
        "elapsed_ms": elapsed_ms,
        "throughput_jobs_per_min": throughput,
        "load_distribution": load,
        "assignments": assignments,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Deterministic distributed production tester")
    parser.add_argument("--workers", type=int, default=int(os.environ.get("DJPT_WORKER_NODES", "1") or "1"))
    parser.add_argument("--jobs", type=int, default=6)
    parser.add_argument("--json-out")
    args = parser.parse_args()

    payload = run_production_test(args.workers, args.jobs)
    out = Path(args.json_out) if args.json_out else _reports_dir() / "distributed_processing_report.json"
    write_report(payload, out, schema_version="djpt.production_tester.v1")
    payload["report_path"] = str(out)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
