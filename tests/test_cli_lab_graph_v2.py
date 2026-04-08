from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "cli.py"


def test_lab_graph_hidden_command_creates_real_artifacts(tmp_path: Path) -> None:
    (tmp_path / "audio").mkdir(parents=True, exist_ok=True)
    (tmp_path / "audio" / "track.mp3").write_bytes(b"A" * 2048)
    (tmp_path / "clips").mkdir(parents=True, exist_ok=True)
    (tmp_path / "clips" / "video.mov").write_bytes(b"B" * 4096)
    env = os.environ.copy()
    env["DJPT_BASE_DIR"] = str(tmp_path)
    env["DJPT_LAB_TS"] = "20260331_000000"
    proc = subprocess.run(
        [sys.executable, str(CLI), "lab", "graph"],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout.strip().splitlines()[-1])
    json_path = Path(payload["json"])
    mmd_path = Path(payload["mermaid"])
    assert json_path.exists()
    assert mmd_path.exists()
    report = json.loads(json_path.read_text(encoding="utf-8"))
    assert report["summary"]["audio_files"] == 1
    assert report["summary"]["video_files"] == 1
    assert "graph LR" in mmd_path.read_text(encoding="utf-8")
