from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HEALTH_AUDIT = ROOT / "scripts" / "health_score_audit.py"


def _run_health_json(write: bool = False) -> dict:
    cmd = [sys.executable, str(HEALTH_AUDIT), "--json"]
    if write:
        cmd.append("--write")
    proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return json.loads(proc.stdout)


def test_health_score_reaches_v1_target() -> None:
    report = _run_health_json(write=False)
    assert report["max_score"] == 100
    assert report["total_score"] == 100.0
    assert report["normalized_score"] == 100.0


def test_health_score_is_deterministic_across_two_runs() -> None:
    first = _run_health_json(write=False)
    second = _run_health_json(write=False)

    assert first["total_score"] == second["total_score"]
    assert first["normalized_score"] == second["normalized_score"]

    first_comp = {k: v["score"] for k, v in first["components"].items()}
    second_comp = {k: v["score"] for k, v in second["components"].items()}
    assert first_comp == second_comp


def test_health_score_writes_evidence_file() -> None:
    report = _run_health_json(write=True)
    evidence = report.get("evidence_file")
    assert evidence, "health audit did not return evidence_file"
    evidence_path = Path(evidence)
    assert evidence_path.exists(), f"missing evidence file: {evidence_path}"
    assert evidence_path.name.startswith("health_score_evidence_")
