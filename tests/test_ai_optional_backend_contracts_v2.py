from __future__ import annotations

import json
from pathlib import Path

import ai_health
import ai_status_enhanced


ROOT = Path(__file__).resolve().parents[1]


def test_ai_health_marks_optional_local_backends_ok_when_disabled() -> None:
    payload, exit_code = ai_health.build_payload(ROOT)
    assert exit_code == 0
    assert payload["backends"]["transformers"]["status"] == "ok"
    assert payload["backends"]["openai_local"]["status"] == "ok"
    assert "desactivado" in payload["backends"]["transformers"]["details"].lower()
    assert "desactivado" in payload["backends"]["openai_local"]["details"].lower()


def test_ai_status_exposes_optional_backend_checks() -> None:
    payload = ai_status_enhanced.build_payload(ROOT / "ai" / "models")
    assert "transformers" in payload["checks"]
    assert "openai_local" in payload["checks"]
    assert payload["checks"]["transformers"]["status"] in {"ok", "warn", "fail"}
    assert payload["checks"]["openai_local"]["status"] in {"ok", "warn", "fail"}
