from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_ai_health_degrades_gracefully_when_path_restricted() -> None:
    env = dict(os.environ)
    env["PATH"] = "/usr/bin:/bin"  # usually excludes ollama path
    proc = subprocess.run([sys.executable, str(ROOT / "scripts" / "ai_health.py")], capture_output=True, text=True, env=env, check=False)
    assert proc.returncode in (0, 1, 2)
    payload = json.loads((ROOT / "state" / "reports" / "ai_health.json").read_text(encoding="utf-8"))
    assert payload["schema_version"] == "ai_health_v2"
    assert payload["summary"]["overall_status"] in {"ok", "warn", "fail"}
    assert "backends" in payload and "ollama" in payload["backends"]
