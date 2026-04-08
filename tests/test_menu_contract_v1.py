from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MENU_CONTRACT_TOOL = ROOT / "scripts" / "menu_contract_tools.py"


def _run_validate_json() -> dict:
    proc = subprocess.run(
        [sys.executable, str(MENU_CONTRACT_TOOL), "validate-json"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(proc.stdout)


def test_menu_contract_parity_and_anti_ghost() -> None:
    report = _run_validate_json()

    parity = report["parity"]
    assert parity["missing_numeric_in_en"] == []
    assert parity["mismatch_numeric_in_en"] == []
    assert parity["missing_alias_in_en"] == []
    assert parity["mismatch_alias_in_en"] == []

    ghosts = report["ghost_options"]
    assert ghosts["es_missing_handlers"] == []
    assert ghosts["en_missing_handlers"] == []

    assert report["registry_dispatch_drift"] == []


def test_menu_contract_counts_are_stable_v1() -> None:
    report = _run_validate_json()
    counts = report["counts"]

    assert counts["contract_numeric"] == 91
    assert counts["es_numeric"] == 91
    assert counts["en_numeric"] == 91
    assert counts["contract_alias"] >= 7
