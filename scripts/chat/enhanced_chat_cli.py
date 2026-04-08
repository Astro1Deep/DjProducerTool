#!/usr/bin/env python3
"""Compatibility wrapper for the canonical DJPT chat CLI."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CANONICAL_CHAT = ROOT / "lib" / "djpt_chat_cli.py"


def main() -> int:
    if not CANONICAL_CHAT.exists():
        sys.stderr.write(f"[ERR] Missing canonical chat CLI: {CANONICAL_CHAT}\n")
        return 2

    env = os.environ.copy()
    env.setdefault("BASE_PATH", str(ROOT))
    env.setdefault("DJPT_CANONICAL_ROOT", str(ROOT))
    env.setdefault("PYTHON_BIN", sys.executable)
    env.setdefault("DJPT_PYTHON_BIN", sys.executable)
    env.setdefault("VENV_DIR", str(Path(sys.executable).resolve().parent.parent))
    proc = subprocess.run([sys.executable, str(CANONICAL_CHAT), *sys.argv[1:]], cwd=ROOT, env=env)
    return int(proc.returncode)


if __name__ == "__main__":
    raise SystemExit(main())
