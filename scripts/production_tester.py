#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "production_tester.py"


def _load() -> ModuleType:
    spec = importlib.util.spec_from_file_location("djpt_production_tester_impl", TARGET)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Target script not found: {TARGET}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_IMPL = _load()
run_production_test = _IMPL.run_production_test
main = _IMPL.main


if __name__ == "__main__":
    raise SystemExit(main())
