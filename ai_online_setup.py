from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any

import hf_model_sync
from scripts.lib.report_json import dump_report, write_report


SCHEMA_VERSION = "ai_online_setup_v1"


def _probe(url: str, timeout: float = 2.0) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=timeout):
            return True
    except Exception:
        return False


def _pip_install(repo_root: Path, requirements: Path) -> tuple[int, str]:
    proc = subprocess.run(
        [sys.executable, "-m", "pip", "install", "-r", str(requirements)],
        cwd=str(repo_root),
        capture_output=True,
        text=True,
    )
    details = (proc.stdout + "\n" + proc.stderr).strip()
    return proc.returncode, details[-4000:]


def run(
    *,
    repo_root: Path,
    apply: bool,
    install_optional_deps: bool,
    hf_sync: bool,
    hf_dry_run: bool,
    hf_force_enable: bool,
) -> tuple[dict[str, Any], int]:
    start = time.perf_counter()
    internet = _probe("https://huggingface.co")
    payload: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "internet": {"online": internet, "target": "https://huggingface.co"},
        "actions": {
            "apply": apply,
            "install_optional_deps": install_optional_deps,
            "hf_sync": hf_sync,
            "hf_dry_run": hf_dry_run,
            "hf_force_enable": hf_force_enable,
        },
        "steps": [],
        "status": "ok",
        "details": "Diagnóstico de setup online completado",
    }

    if not apply:
        payload["steps"].append(
            {
                "step": "preview",
                "status": "ok",
                "details": "Modo preview: usa --apply para ejecutar instalaciones/sync",
            }
        )
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 0

    if not internet:
        payload["status"] = "warn"
        payload["details"] = "Sin internet: setup online no puede aplicar cambios remotos"
        payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
        return payload, 2

    if install_optional_deps:
        req_file = repo_root / "requirements-optional-backends.txt"
        if not req_file.exists():
            payload["steps"].append({"step": "install_optional_deps", "status": "fail", "details": "requirements-optional-backends.txt no existe"})
            payload["status"] = "fail"
        else:
            rc, details = _pip_install(repo_root, req_file)
            payload["steps"].append(
                {
                    "step": "install_optional_deps",
                    "status": "ok" if rc == 0 else "fail",
                    "details": details,
                    "returncode": rc,
                }
            )
            if rc != 0:
                payload["status"] = "fail"

    if hf_sync:
        sync_payload, sync_rc = hf_model_sync.run(
            action="sync",
            repo_root=repo_root,
            allow_remote_override=True,
            force_enable_override=hf_force_enable,
            require_internet_probe=True,
            verify_remote_override=True,
            apply_transformers_override=True,
            enable_transformers_override=False,
            dry_run=hf_dry_run,
        )
        payload["steps"].append(
            {
                "step": "hf_sync",
                "status": "ok" if sync_rc == 0 else "fail",
                "details": sync_payload.get("details"),
                "result": sync_payload,
                "returncode": sync_rc,
            }
        )
        if sync_rc != 0:
            payload["status"] = "fail"

    payload["execution_ms"] = round((time.perf_counter() - start) * 1000, 3)
    if payload["status"] == "ok":
        payload["details"] = "Setup online aplicado correctamente"
        return payload, 0
    return payload, 2


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Setup online asistido para DJProducerTools")
    parser.add_argument("--apply", action="store_true", help="Aplica cambios reales")
    parser.add_argument("--install-optional-deps", action="store_true", help="Instala requirements-optional-backends.txt")
    parser.add_argument("--hf-sync", action="store_true", help="Ejecuta sync de modelo HuggingFace")
    parser.add_argument("--hf-dry-run", action="store_true", help="Sync HF en modo dry-run")
    parser.add_argument("--hf-force-enable", action="store_true", help="Permite sync HF aunque esté disabled en config")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    args = parser.parse_args(argv)

    repo_root = Path(__file__).resolve().parent
    payload, rc = run(
        repo_root=repo_root,
        apply=args.apply,
        install_optional_deps=args.install_optional_deps,
        hf_sync=args.hf_sync,
        hf_dry_run=args.hf_dry_run,
        hf_force_enable=args.hf_force_enable,
    )

    report_path = repo_root / "state" / "reports" / "ai_online_setup.json"
    write_report(payload, report_path, schema_version=SCHEMA_VERSION, execution_ms=payload.get("execution_ms"))

    if args.format == "json":
        print(dump_report(payload, schema_version=SCHEMA_VERSION, execution_ms=payload.get("execution_ms")), end="")
    else:
        print(f"[SETUP] status={payload.get('status')}")
        print(f"[SETUP] details={payload.get('details')}")
        print(f"[SETUP] internet_online={payload.get('internet', {}).get('online')}")
        for step in payload.get("steps", []):
            print(f"[SETUP] {step.get('step')}: {step.get('status')} ({step.get('details')})")

    return rc


if __name__ == "__main__":
    raise SystemExit(main())
