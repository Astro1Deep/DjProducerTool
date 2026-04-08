#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.lib.report_json import validate_payload, write_report

SCHEMA_PATH = ROOT / "config" / "schemas" / "external_review_response_v1.schema.json"


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _has_health_evidence(payload: dict) -> bool:
    direct = payload.get("evidence_refs", [])
    checks = payload.get("validated_checks", [])
    refs = list(direct)
    for item in checks:
        refs.extend(item.get("evidence_refs", []))
    return any("health_score_evidence" in ref for ref in refs)


def cmd_validate(input_path: Path, output_dir: Path) -> int:
    payload = _load_json(input_path)
    ok, errors = validate_payload(payload, SCHEMA_PATH)
    if not ok:
        print(json.dumps({"ok": False, "errors": errors}, ensure_ascii=False))
        return 2
    if payload.get("score_claims") and not _has_health_evidence(payload):
        print(json.dumps({"ok": False, "error": "missing health_score_evidence"}, ensure_ascii=False))
        return 2
    output_dir.mkdir(parents=True, exist_ok=True)
    validated_path = output_dir / f"validated_{input_path.name}"
    validated_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"ok": True, "validated_file": str(validated_path)}, ensure_ascii=False))
    return 0


def cmd_merge(swe_path: Path, gemini_path: Path, output_dir: Path) -> int:
    swe = _load_json(swe_path)
    gemini = _load_json(gemini_path)
    output_dir.mkdir(parents=True, exist_ok=True)

    merge_report = output_dir / "external_review_merge_report.json"
    continuity_backlog = output_dir / "external_review_continuity_backlog.json"

    merged = {
        "reviewers": [swe.get("reviewer_id"), gemini.get("reviewer_id")],
        "models": [swe.get("model_name"), gemini.get("model_name")],
        "merged_findings": swe.get("findings", []) + gemini.get("findings", []),
        "merged_risks": swe.get("risks", []) + gemini.get("risks", []),
        "recommended_actions": swe.get("recommended_actions", []) + gemini.get("recommended_actions", []),
        "evidence_refs": sorted(set(list(swe.get("evidence_refs", [])) + list(gemini.get("evidence_refs", [])))),
    }
    backlog = {
        "items": [
            {
                "title": "Consolidate external review findings",
                "owner": "DJPT-Core",
                "source_reviewers": [swe.get("reviewer_id"), gemini.get("reviewer_id")],
                "count": len(merged["merged_findings"]),
            }
        ]
    }
    write_report(merged, merge_report)
    write_report(backlog, continuity_backlog)
    print(json.dumps({"ok": True, "merge_report": str(merge_report), "continuity_backlog": str(continuity_backlog)}, ensure_ascii=False))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="External review merge/validate pipeline")
    sub = parser.add_subparsers(dest="command", required=True)

    validate = sub.add_parser("validate")
    validate.add_argument("--input", required=True)
    validate.add_argument("--output-dir", required=True)

    merge = sub.add_parser("merge")
    merge.add_argument("--swe", required=True)
    merge.add_argument("--gemini", required=True)
    merge.add_argument("--output-dir", required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.command == "validate":
        return cmd_validate(Path(args.input), Path(args.output_dir))
    if args.command == "merge":
        return cmd_merge(Path(args.swe), Path(args.gemini), Path(args.output_dir))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
