#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = ROOT / "lib"
for candidate in (str(LIB_DIR), str(ROOT)):
    if candidate not in sys.path:
        sys.path.insert(0, candidate)

from ml_mlx import main


if __name__ == "__main__":
    raise SystemExit(main())
