#!/usr/bin/env python3
"""Compatibility wrapper for the canonical root-level CLI."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def _error_payload(*, code: str, message: str, hint: str) -> dict[str, str]:
    return {"code": code, "message": message, "hint": hint}


def _emit_error(*, code: str, message: str, hint: str, exit_code: int = 2) -> int:
    payload = _error_payload(code=code, message=message, hint=hint)
    sys.stderr.write(json.dumps(payload) + "\n")
    return exit_code


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    cli_path = root / "cli.py"

    try:
        proc = subprocess.run([sys.executable, str(cli_path), *sys.argv[1:]], cwd=root)
    except Exception as exc:
        return _emit_error(
            code="cli_import_error",
            message=str(exc),
            hint="Use the repository root as working directory and install CLI dependencies.",
        )

    return int(proc.returncode)


if __name__ == "__main__":
    raise SystemExit(main())
