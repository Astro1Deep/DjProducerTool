from __future__ import annotations

import csv
import importlib.util
from pathlib import Path


def _load_ml_tf_module():
    module_path = (
        Path(__file__).resolve().parents[1]
        / "scripts"
        / "ai"
        / "ml_tf.py"
    )
    spec = importlib.util.spec_from_file_location("djpt_ml_tf", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ml_tf = _load_ml_tf_module()


def test_backend_resolution_priority(monkeypatch) -> None:
    monkeypatch.setenv("DJPT_STEMS_BACKEND", "hpss")
    assert ml_tf.resolve_requested_backend(None) == "hpss"
    assert ml_tf.resolve_requested_backend("demucs") == "demucs"
    assert ml_tf.resolve_requested_backend("INVALID") == "auto"


def test_auto_backend_resolves_by_demucs_availability() -> None:
    assert ml_tf.resolve_effective_backend("auto", {"module": True, "cli": False}) == "demucs"
    assert ml_tf.resolve_effective_backend("auto", {"module": False, "cli": True}) == "demucs"
    assert ml_tf.resolve_effective_backend("auto", {"module": False, "cli": False}) == "hpss"
    assert ml_tf.resolve_effective_backend("hpss", {"module": True, "cli": True}) == "hpss"


def test_demucs_failure_falls_back_to_hpss(monkeypatch, tmp_path: Path) -> None:
    audio = tmp_path / "track.wav"
    audio.write_bytes(b"RIFFTEST")
    out_root = tmp_path / "reports"

    def _fake_demucs(*_args, **_kwargs):
        return {
            "status": "error",
            "output_dir": str(out_root / "demucs"),
            "backend_used": "demucs",
            "error": "demucs unavailable",
        }

    def _fake_hpss(*_args, **_kwargs):
        return {
            "status": "ok",
            "output_dir": str(out_root / "track_stems"),
            "backend_used": "hpss",
            "error": "",
        }

    monkeypatch.setattr(ml_tf, "run_demucs_stems", _fake_demucs)
    monkeypatch.setattr(ml_tf, "run_hpss_stems", _fake_hpss)

    row = ml_tf.process_stems_file(
        audio_path=audio,
        out_root=out_root,
        effective_backend="demucs",
        demucs_model="htdemucs",
        demucs_device="auto",
        timeout_sec=30,
    )

    assert row["status"] == "ok"
    assert row["backend_used"] == "hpss"
    assert "demucs_failed" in row["error"]


def test_manifest_schema_columns(tmp_path: Path) -> None:
    rows = [
        {
            "input_path": "/tmp/song.wav",
            "backend_used": "hpss",
            "status": "ok",
            "output_dir": "/tmp/out",
            "error": "",
        }
    ]
    manifest = ml_tf.write_manifest(rows, tmp_path)
    assert manifest.exists()

    with manifest.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        assert reader.fieldnames == ml_tf.MANIFEST_COLUMNS
        parsed = list(reader)

    assert len(parsed) == 1
    assert parsed[0]["backend_used"] == "hpss"
