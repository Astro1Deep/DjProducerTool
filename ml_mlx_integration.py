#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import platform
from pathlib import Path
from typing import Any

from scripts.lib.report_json import write_report

ROOT = Path(__file__).resolve().parent


def _module_available(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


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


def analyze_stack() -> dict[str, Any]:
    backends = {
        "mlx": _module_available("mlx"),
        "tensorflow": _module_available("tensorflow"),
        "torch": _module_available("torch"),
        "coremltools": _module_available("coremltools"),
    }
    active = [name for name, available in backends.items() if available]
    status = "ok" if active else "degraded"
    return {
        "status": status,
        "analysis": "quantum_processing",
        "machine": platform.machine(),
        "platform": platform.platform(),
        "backends": backends,
        "active_backends": active,
        "recommendation": "Use MLX on Apple Silicon when available" if backends["mlx"] else "Install MLX or TensorFlow for heavier experimental analysis",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Experimental MLX/TensorFlow integration probe")
    parser.add_argument("--analyze", action="store_true")
    parser.add_argument("--json-out")
    args = parser.parse_args()
    payload = analyze_stack()
    out = Path(args.json_out) if args.json_out else _reports_dir() / "quantum_processing_report.json"
    write_report(payload, out, schema_version="djpt.quantum_processing.v1")
    payload["report_path"] = str(out)
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0 if payload["status"] == "ok" else 0


if __name__ == "__main__":
    raise SystemExit(main())
