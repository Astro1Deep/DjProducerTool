#!/usr/bin/env python3
"""Compatibility wrapper for the canonical enhanced AI status entrypoint."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai_status_enhanced import main


if __name__ == "__main__":
    raise SystemExit(main())
