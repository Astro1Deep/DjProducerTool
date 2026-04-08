from __future__ import annotations

import json
from pathlib import Path

from scripts.lib.report_json import validate_payload

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / "config" / "schemas" / "external_review_response_v1.schema.json"


def test_external_review_schema_accepts_minimal_pending_payload() -> None:
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
        "verdict": "pending",
        "score_claims": {"v1": 100.0, "v2": 100.0, "headroom": 20.0},
        "validated_checks": [],
        "findings": [],
        "risks": [],
        "recommended_actions": [],
        "evidence_refs": ["state/reports/health_score_evidence_20260220_235124.json"],
        "confidence": 0.5,
        "limitations": ["pending execution"],
    }
    ok, errors = validate_payload(payload, SCHEMA)
    assert ok, errors


def test_external_review_packet_contract_fields_present() -> None:
    packet = json.loads((ROOT / "config" / "contracts" / "external_review_packet_v1.json").read_text(encoding="utf-8"))
    required = {
        "packet_version",
        "repo_root",
        "canonical_paths",
        "baseline_scores",
        "required_commands",
        "evidence_files",
        "acceptance_rules",
        "response_schema_ref",
    }
    assert required.issubset(set(packet.keys()))
