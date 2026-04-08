from __future__ import annotations

from pathlib import Path

import ai_health


class _FakeStatus:
    ollama_ready = True
    openai_ready = False
    hf_ready = False
    mlx_available = True
    tf_available = True
    messages = [
        "Falta OPENAI_API_KEY en entorno",
        "Falta HUGGINGFACE_TOKEN/HF_TOKEN para modelos HF",
    ]


class _FakeManager:
    def __init__(self, base_path: Path):
        self.base_path = base_path

    def status(self) -> _FakeStatus:
        return _FakeStatus()


def test_ai_health_treats_remote_tokens_as_optional_local_first(monkeypatch) -> None:
    monkeypatch.setattr(ai_health, "IABackendManager", _FakeManager)
    monkeypatch.setattr(ai_health, "find_spec", lambda name: object() if name == "sklearn" else None)
    monkeypatch.delenv("DJPT_REQUIRE_OPENAI", raising=False)
    monkeypatch.delenv("DJPT_REQUIRE_HF", raising=False)

    payload, exit_code = ai_health.build_payload(Path.cwd())

    assert exit_code == 0
    assert payload["summary"]["overall_status"] == "ok"
    assert payload["backends"]["openai"]["status"] == "ok"
    assert payload["backends"]["huggingface"]["status"] == "ok"
    assert not any("OPENAI_API_KEY" in message for message in payload["messages"])
    assert not any("HUGGINGFACE_TOKEN" in message for message in payload["messages"])


def test_ai_health_can_require_remote_tokens_explicitly(monkeypatch) -> None:
    monkeypatch.setattr(ai_health, "IABackendManager", _FakeManager)
    monkeypatch.setattr(ai_health, "find_spec", lambda name: object() if name == "sklearn" else None)
    monkeypatch.setenv("DJPT_REQUIRE_OPENAI", "1")
    monkeypatch.setenv("DJPT_REQUIRE_HF", "1")

    payload, exit_code = ai_health.build_payload(Path.cwd())

    assert exit_code == 1
    assert payload["summary"]["overall_status"] == "warn"
    assert payload["backends"]["openai"]["status"] == "warn"
    assert payload["backends"]["huggingface"]["status"] == "warn"
