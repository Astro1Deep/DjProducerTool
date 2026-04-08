from __future__ import annotations

import json
from pathlib import Path

import hf_model_sync


def _write_config(repo_root: Path, content: str) -> Path:
    cfg = repo_root / "config" / "ai_model_params.toml"
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text(content, encoding="utf-8")
    return cfg


def test_hf_status_disabled_is_ok(tmp_path: Path) -> None:
    _write_config(
        tmp_path,
        """
[huggingface]
enabled = false
model = "sentence-transformers/all-MiniLM-L6-v2"
""".strip()
        + "\n",
    )
    payload, rc = hf_model_sync.run("status", tmp_path)
    assert rc == 0
    assert payload["status"] == "ok"
    assert "desactivado" in payload["details"].lower()


def test_hf_sync_requires_remote_enable(tmp_path: Path) -> None:
    _write_config(
        tmp_path,
        """
[huggingface]
enabled = true
model = "sentence-transformers/all-MiniLM-L6-v2"
allow_remote = false
""".strip()
        + "\n",
    )
    payload, rc = hf_model_sync.run("sync", tmp_path)
    assert rc == 2
    assert payload["status"] == "warn"
    assert "red deshabilitada" in payload["details"].lower()


def test_hf_sync_applies_transformers_binding(tmp_path: Path, monkeypatch) -> None:
    _write_config(
        tmp_path,
        """
[transformers]
enabled = false
local_files_only = true

[huggingface]
enabled = true
model = "sentence-transformers/all-MiniLM-L6-v2"
revision = "main"
local_dir = "state/models/huggingface/all-MiniLM-L6-v2"
allow_remote = true
require_token = false
verify_remote = true
apply_to_transformers = true
enable_transformers_after_sync = false
""".strip()
        + "\n",
    )

    class _Info:
        id = "sentence-transformers/all-MiniLM-L6-v2"
        sha = "abc123"
        last_modified = "2026-04-08T00:00:00Z"

    class _FakeApi:
        def __init__(self, token=None):
            self.token = token

        def model_info(self, model, revision, token=None):
            assert model == "sentence-transformers/all-MiniLM-L6-v2"
            assert revision == "main"
            return _Info()

    def _fake_snapshot_download(**kwargs):
        local_dir = Path(kwargs["local_dir"])
        local_dir.mkdir(parents=True, exist_ok=True)
        (local_dir / "config.json").write_text("{}", encoding="utf-8")
        return str(local_dir)

    monkeypatch.setattr(hf_model_sync, "_get_hf_clients", lambda: (_FakeApi, _fake_snapshot_download))
    monkeypatch.setattr(hf_model_sync, "_probe_internet", lambda: True)

    payload, rc = hf_model_sync.run("sync", tmp_path)
    assert rc == 0
    assert payload["status"] == "ok"
    assert payload["remote"]["sha"] == "abc123"
    assert payload["transformers_binding"]["applied"] is True

    binding_path = tmp_path / "state" / "config" / "ai_backends.json"
    data = json.loads(binding_path.read_text(encoding="utf-8"))
    assert data["backends"]["transformers"]["model_path"].endswith("state/models/huggingface/all-MiniLM-L6-v2")


def test_hf_sync_can_force_enable_even_if_disabled(tmp_path: Path, monkeypatch) -> None:
    _write_config(
        tmp_path,
        """
[huggingface]
enabled = false
model = "sentence-transformers/all-MiniLM-L6-v2"
allow_remote = true
""".strip()
        + "\n",
    )

    class _Info:
        id = "sentence-transformers/all-MiniLM-L6-v2"
        sha = "abc123"
        last_modified = "2026-04-08T00:00:00Z"

    class _FakeApi:
        def __init__(self, token=None):
            self.token = token

        def model_info(self, model, revision, token=None):
            return _Info()

    def _fake_snapshot_download(**kwargs):
        local_dir = Path(kwargs["local_dir"])
        local_dir.mkdir(parents=True, exist_ok=True)
        (local_dir / "config.json").write_text("{}", encoding="utf-8")
        return str(local_dir)

    monkeypatch.setattr(hf_model_sync, "_get_hf_clients", lambda: (_FakeApi, _fake_snapshot_download))
    monkeypatch.setattr(hf_model_sync, "_probe_internet", lambda: True)

    payload, rc = hf_model_sync.run("sync", tmp_path, force_enable_override=True)
    assert rc == 0
    assert payload["status"] == "ok"


def test_hf_sync_fails_when_internet_probe_is_offline(tmp_path: Path, monkeypatch) -> None:
    _write_config(
        tmp_path,
        """
[huggingface]
enabled = true
model = "sentence-transformers/all-MiniLM-L6-v2"
allow_remote = true
""".strip()
        + "\n",
    )
    monkeypatch.setattr(hf_model_sync, "_probe_internet", lambda: False)
    payload, rc = hf_model_sync.run("sync", tmp_path)
    assert rc == 2
    assert payload["status"] == "fail"
    assert "internet" in payload["details"].lower()
