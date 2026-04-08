from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "ai_status_enhanced.py"
ALLOWED = {"ok", "warn", "fail"}


def test_ai_status_v2_backend_severity_fields() -> None:
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), "--models-dir", str(ROOT / "ai" / "models"), "--format", "json"],
        capture_output=True,
        text=True,
        check=True,
    )
    payload = json.loads(proc.stdout)

    for key in ("mlx_llm", "embeddings", "asr", "ollama"):
        backend = payload[key]
        assert backend["severity"] in ALLOWED
        assert isinstance(backend.get("details"), str)

    for check in payload["checks"].values():
        assert check["status"] in ALLOWED
        if check["status"] in {"warn", "fail"}:
            assert "suggestion" in check
