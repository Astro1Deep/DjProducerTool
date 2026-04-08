from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_config_backup_restore_roundtrip(tmp_path: Path) -> None:
    cfg = tmp_path / "cfg.toml"
    cfg.write_text("[general]\npreferred_backend='auto'\n", encoding="utf-8")

    backup_proc = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "config_tools.py"), "backup", "--file", str(cfg)],
        capture_output=True,
        text=True,
        check=True,
    )
    backup_info = json.loads(backup_proc.stdout)
    backup_file = Path(backup_info["backup_file"])
    assert backup_file.exists()

    cfg.write_text("[general]\npreferred_backend='mlx'\n", encoding="utf-8")

    restore_proc = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "config_tools.py"), "restore", "--file", str(cfg), "--backup", str(backup_file)],
        capture_output=True,
        text=True,
        check=True,
    )
    restore_info = json.loads(restore_proc.stdout)
    assert restore_info["ok"] is True
    assert "auto" in cfg.read_text(encoding="utf-8")
