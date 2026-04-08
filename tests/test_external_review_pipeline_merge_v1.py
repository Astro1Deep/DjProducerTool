from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PIPE = ROOT / "scripts" / "external_review_pipeline.py"


def _payload(reviewer: str, model: str) -> dict[str, object]:
    return {
        "reviewer_id": reviewer,
        "model_name": model,
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
            {
                "check_id": "score_dual",
                "status": "warn",
                "evidence_refs": ["state/reports/health_score_evidence_20260220_235124.json"],
            }
        ],
        "findings": [
            {
                "id": f"{reviewer}_F001",
                "severity": "non_blocking",
                "summary": "Wrapper stability should remain monitored",
                "evidence_refs": ["scripts/chat/enhanced_chat_cli.py"],
                "recommended_fix": {
                    "file": "scripts/chat/enhanced_chat_cli.py",
                    "function": "main",
                    "command": "python3 -m pytest tests/test_wrappers_delegation_v2.py -q",
                },
            }
        ],
        "risks": [
            {
                "id": f"{reviewer}_R001",
                "severity": "non_blocking",
                "description": "Potential doc drift",
                "mitigation": "Run periodic doc parity checks",
                "evidence_refs": ["ANALYSIS_COMPLETE_FINAL.md"],
            }
        ],
        "recommended_actions": [
            {
                "priority": "P1",
                "action": "Add periodic external review gate run",
                "owner": "DJPT-Core",
                "target_files": ["scripts/tests/test_phase1_high_priority_gate.sh"],
                "acceptance_criteria": "Gate run documented with latest evidence file",
            }
        ],
        "evidence_refs": ["state/reports/health_score_evidence_20260220_235124.json"],
        "confidence": 0.85,
        "limitations": ["Synthetic test payload"],
    }


def test_merge_generates_reports(tmp_path: Path) -> None:
    swe = tmp_path / "swe.json"
    gem = tmp_path / "gem.json"
    swe.write_text(json.dumps(_payload("swe15", "SWE-1.5")), encoding="utf-8")
    gem.write_text(json.dumps(_payload("gemini", "Gemini")), encoding="utf-8")

    proc = subprocess.run(
        [
            sys.executable,
            str(PIPE),
            "merge",
            "--swe",
            str(swe),
            "--gemini",
            str(gem),
            "--output-dir",
            str(tmp_path),
        ],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stderr
    out = json.loads(proc.stdout)
    assert Path(out["merge_report"]).exists()
    assert Path(out["continuity_backlog"]).exists()
