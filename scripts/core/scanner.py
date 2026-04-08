#!/usr/bin/env python3
"""Compatibility wrapper for the canonical scanner implementation."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

CANONICAL_SCANNER = ROOT / "core" / "scanner.py"
if not CANONICAL_SCANNER.exists():
    raise SystemExit(f"Canonical scanner not found: {CANONICAL_SCANNER}")

spec = importlib.util.spec_from_file_location("djpt_core_scanner", CANONICAL_SCANNER)
if spec is None or spec.loader is None:
    raise SystemExit(f"Unable to load canonical scanner: {CANONICAL_SCANNER}")
_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(_module)

# Keep Config bound to the currently imported package path (`core.*` or `scripts.core.*`)
# so tests and runtime overrides mutate the same class object.
try:
    from .config import Config as RuntimeConfig  # type: ignore
except Exception:
    try:
        from core.config import Config as RuntimeConfig  # type: ignore
    except Exception:
        from scripts.core.config import Config as RuntimeConfig  # type: ignore

_module.Config = RuntimeConfig

Scanner = _module.Scanner
parse_args = _module.parse_args
main = _module.main

__all__ = ["Scanner", "parse_args", "main"]


if __name__ == "__main__":
    raise SystemExit(main())
