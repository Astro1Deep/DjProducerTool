from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from scripts.lib.report_json import validate_payload

ROOT = Path(__file__).resolve().parents[1]


def test_ai_health_v2_schema_valid() -> None:
    proc = subprocess.run([sys.executable, str(ROOT / "scripts" / "ai_health.py")], capture_output=True, text=True, check=False)
    assert proc.returncode in (0, 1, 2), proc.stderr
    payload = json.loads((ROOT / "state" / "reports" / "ai_health.json").read_text(encoding="utf-8"))
    ok, errors = validate_payload(payload, ROOT / "config" / "schemas" / "ai_health_v2.schema.json")
    assert ok, errors
