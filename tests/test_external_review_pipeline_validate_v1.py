from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PIPE = ROOT / "scripts" / "external_review_pipeline.py"


def test_validate_rejects_score_claim_without_health_evidence(tmp_path: Path) -> None:
    payload = {
        "reviewer_id": "swe15",
        "model_name": "SWE-1.5",
        "timestamp": "2026-02-21T00:00:00Z",
        "scope": {
            "repo_root": str(ROOT),
            "packet_version": "external_review_packet_v1",
            "mode": "read_only",
            "target_gate": "scripts/tests/test_phase1_high_priority_gate.sh",
        },
        "verdict": "warn",
        "score_claims": {"v1": 100.0, "v2": 100.0, "headroom": 20.0},
        "validated_checks": [
            {"check_id": "gate", "status": "warn", "evidence_refs": ["state/reports/phase1_release_report_20260220_235028.md"]}
        ],
        "findings": [],
        "risks": [],
        "recommended_actions": [],
        "evidence_refs": ["state/reports/phase1_release_report_20260220_235028.md"],
        "confidence": 0.8,
        "limitations": ["test payload"],
    }
    src = tmp_path / "bad.json"
    src.write_text(json.dumps(payload), encoding="utf-8")
    proc = subprocess.run(
        [sys.executable, str(PIPE), "validate", "--input", str(src), "--output-dir", str(tmp_path)],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 2
    assert "health_score_evidence" in proc.stdout
