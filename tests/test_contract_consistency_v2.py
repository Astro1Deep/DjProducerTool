from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_menu_contract_no_drift_and_no_ghost() -> None:
    proc = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "menu_contract_tools.py"), "validate-json"],
        capture_output=True,
        text=True,
        check=True,
    )
    report = json.loads(proc.stdout)
    assert report["parity"]["missing_numeric_in_en"] == []
    assert report["parity"]["mismatch_numeric_in_en"] == []
    assert report["ghost_options"]["es_missing_handlers"] == []
    assert report["ghost_options"]["en_missing_handlers"] == []
    assert report["registry_dispatch_drift"] == []
    assert report["registry_toml_dispatch_drift"] == []
