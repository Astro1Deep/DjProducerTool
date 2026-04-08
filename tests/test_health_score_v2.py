from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_health_score_v2_and_headroom_present() -> None:
    proc = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "health_score_audit.py"),
            "--contract",
            str(ROOT / "config" / "health" / "health_score_v2.json"),
            "--json",
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    report = json.loads(proc.stdout)
    assert report["max_score"] == 100
    assert "headroom_index" in report
    assert "excellence_score" in report
