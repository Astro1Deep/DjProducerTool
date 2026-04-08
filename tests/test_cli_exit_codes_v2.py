from __future__ import annotations

import subprocess
import sys


def test_cli_health_exit_code_contract() -> None:
    proc = subprocess.run(
        [sys.executable, "-m", "scripts.cli", "health"],
        capture_output=True,
        text=True,
    )
    assert proc.returncode in (0, 1, 2), proc.stderr
