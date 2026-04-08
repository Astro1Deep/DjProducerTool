#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.lib.report_json import write_report


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


def _status_payload() -> dict[str, Any]:
    state_dir = _state_dir()
    rollbacks_dir = state_dir / "rollbacks"
    points = sorted(p.name for p in rollbacks_dir.glob("*") if p.is_file()) if rollbacks_dir.exists() else []
    auto_healing = str(os.environ.get("DJPT_AUTO_HEALING", "0")).strip() in {"1", "true", "yes", "on"}
    return {
        "status": "ok",
        "auto_healing": auto_healing,
        "rollback_points": points,
        "state_dir": str(state_dir),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def _monitor_payload() -> dict[str, Any]:
    payload = _status_payload()
    payload.update(
        {
            "mode": "monitor",
            "watch_targets": ["state", "reports", "logs"],
            "health": "stable" if payload["auto_healing"] else "manual_observation",
        }
    )
    return payload


def _report_payload() -> tuple[dict[str, Any], Path]:
    payload = _status_payload()
    payload.update(
        {
            "mode": "report",
            "recommendations": [
                "Enable auto-healing for automatic retries" if not payload["auto_healing"] else "Auto-healing already enabled",
                "Keep rollback points before destructive maintenance",
            ],
        }
    )
    out = _reports_dir() / "error_recovery_report.json"
    write_report(payload, out, schema_version="djpt.error_recovery.v1")
    payload["report_path"] = str(out)
    return payload, out


def _test_error_payload(error_type: str) -> dict[str, Any]:
    mapping = {
        "memory_error": "Reduce concurrency and free caches",
        "permission_error": "Review ownership and SAFE_MODE paths",
        "network_error": "Retry only optional network tasks",
        "dependency_error": "Rebuild djpt_venv and reinstall missing packages",
    }
    action = mapping.get(error_type, "Inspect structured logs and fallback to safe mode")
    return {
        "status": "ok",
        "mode": "test_error",
        "simulated_error": error_type,
        "recovery_action": action,
        "auto_healing_enabled": str(os.environ.get("DJPT_AUTO_HEALING", "0")).strip() in {"1", "true", "yes", "on"},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Deterministic enhanced error recovery surface")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--monitor", action="store_true")
    group.add_argument("--report", action="store_true")
    group.add_argument("--status", action="store_true")
    group.add_argument("--test-error")
    args = parser.parse_args()

    if args.monitor:
        payload = _monitor_payload()
    elif args.report:
        payload, _ = _report_payload()
    elif args.status:
        payload = _status_payload()
    else:
        payload = _test_error_payload(args.test_error)

    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
