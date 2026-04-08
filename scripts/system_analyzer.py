#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.lib.report_json import write_report


class SystemAnalyzer:
    def __init__(self, base_path: Path) -> None:
        self.base_path = base_path.resolve()
        self.script_path = self.base_path / "scripts" / "DJProducerTools_MultiScript_ES.sh"

    def check_efficient_inventory(self) -> dict[str, Any]:
        artifacts = {
            "smart_analyzer": (self.base_path / "smart_analyzer.py").exists(),
            "snapshot_builder": (self.base_path / "snapshot_builder.py").exists(),
            "workspace_scan_action": self.script_path.exists() and "action_6_scan_workspace" in self.script_path.read_text(encoding="utf-8", errors="ignore"),
        }
        ok = all(artifacts.values())
        return {"name": "efficient_inventory", "ok": ok, "artifacts": artifacts}

    def check_command_line_args(self) -> dict[str, Any]:
        root_wrapper = self.base_path / "DJProducerTools_MultiScript_ES.sh"
        cli = self.base_path / "cli.py"
        root_text = root_wrapper.read_text(encoding="utf-8", errors="ignore") if root_wrapper.exists() else ""
        cli_text = cli.read_text(encoding="utf-8", errors="ignore") if cli.exists() else ""
        checks = {
            "root_wrapper_run_flag": "--run" in root_text,
            "root_wrapper_help_flag": "--help" in root_text,
            "cli_entrypoint": "def main" in cli_text or "app =" in cli_text,
        }
        return {"name": "command_line_args", "ok": all(checks.values()), "checks": checks}

    def check_dependency_management(self) -> dict[str, Any]:
        checks = {
            "pyproject": (self.base_path / "pyproject.toml").exists(),
            "venv_manager": (self.base_path / "venv_manager.py").exists() or (self.base_path / "lib" / "venv_manager.py").exists(),
            "ai_model_params": (self.base_path / "config" / "ai_model_params.toml").exists(),
        }
        return {"name": "dependency_management", "ok": all(checks.values()), "checks": checks}

    def check_safe_execution(self) -> dict[str, Any]:
        script_text = self.script_path.read_text(encoding="utf-8", errors="ignore") if self.script_path.exists() else ""
        checks = {
            "safe_mode": "SAFE_MODE" in script_text,
            "safe_lock": "DJ_SAFE_LOCK" in script_text,
            "ensure_under_base": "ensure_under_base" in script_text,
        }
        return {"name": "safe_execution", "ok": all(checks.values()), "checks": checks}

    def build_report(self) -> dict[str, Any]:
        new_features = {
            "efficient_inventory": self.check_efficient_inventory(),
            "command_line_args": self.check_command_line_args(),
            "dependency_management": self.check_dependency_management(),
            "safe_execution": self.check_safe_execution(),
        }
        failing = [name for name, payload in new_features.items() if not payload.get("ok")]
        status = "ok" if not failing else "warn"
        return {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "base_path": str(self.base_path),
            "status": status,
            "new_features": new_features,
            "implementation_summary": {
                "checks_total": len(new_features),
                "checks_ok": len(new_features) - len(failing),
                "checks_warn": len(failing),
                "warnings": failing,
            },
        }


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze DJProducerTools system hardening features")
    parser.add_argument("--base-path", default=str(ROOT))
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--json-out")
    args = parser.parse_args()

    analyzer = SystemAnalyzer(Path(args.base_path))
    payload = analyzer.build_report()
    if args.json_out:
        write_report(payload, args.json_out, schema_version="djpt.system_analyzer.v1")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
