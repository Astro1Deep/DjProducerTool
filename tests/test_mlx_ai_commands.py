from __future__ import annotations

import json
import math
import struct
import subprocess
import sys
import wave
from pathlib import Path


def _write_test_tone(path: Path, freq_hz: float = 440.0, duration_s: float = 0.25, sr: int = 22050) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    n_samples = int(duration_s * sr)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        for i in range(n_samples):
            sample = int(0.25 * 32767 * math.sin(2.0 * math.pi * freq_hz * (i / sr)))
            wf.writeframes(struct.pack("<h", sample))


def _run_cmd(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, text=True)


def test_mlx_asr_generates_structured_report(tmp_path: Path) -> None:
    audio_dir = tmp_path / "Audio Library"
    _write_test_tone(audio_dir / "Kick 01.wav", freq_hz=110.0)
    _write_test_tone(audio_dir / "Synth Lead.wav", freq_hz=880.0)

    out = tmp_path / "mlx_asr_report.json"
    cmd = [
        sys.executable,
        str(Path(__file__).resolve().parents[1] / "scripts" / "ml_mlx.py"),
        "asr",
        "--base",
        str(audio_dir),
        "--out",
        str(out),
    ]
    proc = _run_cmd(cmd)

    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert out.exists()

    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload["summary"]["processed_files"] == 2
    assert len(payload["results"]) == 2
    row = payload["results"][0]
    assert "mfcc_mean" in row
    assert "spectral_centroid_mean" in row
    assert "zero_crossing_rate_mean" in row
    assert "backend" in row


def test_mlx_metadata_generates_expected_fields(tmp_path: Path) -> None:
    audio_dir = tmp_path / "Music"
    _write_test_tone(audio_dir / "Ambient Pad.wav", freq_hz=220.0)

    out = tmp_path / "mlx_metadata_report.json"
    cmd = [
        sys.executable,
        str(Path(__file__).resolve().parents[1] / "scripts" / "ml_mlx.py"),
        "metadata",
        "--base",
        str(audio_dir),
        "--out",
        str(out),
    ]
    proc = _run_cmd(cmd)

    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert out.exists()

    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload["summary"]["processed_files"] == 1
    row = payload["results"][0]
    for key in ("tempo", "key", "energy", "brightness", "genre", "mood", "quality"):
        assert key in row
