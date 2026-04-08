from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _seed(base: Path) -> None:
    (base / "music").mkdir(parents=True, exist_ok=True)
    (base / "docs").mkdir(parents=True, exist_ok=True)
    (base / "video").mkdir(parents=True, exist_ok=True)
    (base / "music" / "a.mp3").write_bytes(b"a" * 8)
    (base / "music" / "b.wav").write_bytes(b"b" * 8)
    (base / "video" / "c.mp4").write_bytes(b"c" * 8)
    (base / "docs" / "notes.txt").write_text("hello", encoding="utf-8")


def _run_scan(tmp_path: Path, only: str) -> dict:
    base = tmp_path / "library"
    _seed(base)
    env = os.environ.copy()
    env["DJPT_ALLOW_OUTSIDE"] = "1"
    env["DJPT_BASE_DIR"] = str(base)
    proc = subprocess.run(
        [sys.executable, str(ROOT / "cli.py"), "scan", str(base), "--only", only, "--quick"],
        capture_output=True,
        text=True,
        env=env,
        check=True,
    )
    out_line = next(line for line in proc.stdout.splitlines() if line.strip().startswith("- Salida:"))
    out_dir = Path(out_line.split(":", 1)[1].strip())
    manifest = json.loads((out_dir / "manifest.json").read_text(encoding="utf-8"))
    rows = (out_dir / "files_index.csv").read_text(encoding="utf-8").splitlines()[1:]
    return {"manifest": manifest, "rows": rows}


def test_cli_scan_can_filter_mp3(tmp_path: Path) -> None:
    result = _run_scan(tmp_path, "mp3")
    assert result["manifest"]["file_count"] == 1
    assert any("a.mp3" in row for row in result["rows"])



def test_cli_scan_can_filter_wav(tmp_path: Path) -> None:
    result = _run_scan(tmp_path, "wav")
    assert result["manifest"]["file_count"] == 1
    assert any("b.wav" in row for row in result["rows"])



def test_cli_scan_can_filter_other_files(tmp_path: Path) -> None:
    result = _run_scan(tmp_path, "other")
    assert result["manifest"]["file_count"] == 1
    assert any("notes.txt" in row for row in result["rows"])
