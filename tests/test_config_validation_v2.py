from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_config_tools_rejects_invalid_toml(tmp_path: Path) -> None:
    bad = tmp_path / "bad.toml"
    bad.write_text("[general\npreferred_backend='mlx'\n", encoding="utf-8")
    proc = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "config_tools.py"), "validate", "--file", str(bad)],
        capture_output=True,
        text=True,
        check=True,
    )
    payload = json.loads(proc.stdout)
    assert payload["valid"] is False
    assert "toml_parse_error" in payload["error"]
