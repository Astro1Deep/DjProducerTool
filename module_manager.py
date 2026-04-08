from __future__ import annotations

import argparse
import json
import os
import py_compile
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import tomllib

from scripts.lib.report_json import dump_report, write_report


SCHEMA_VERSION = "module_manager_v1"


@dataclass
class ModuleLayout:
    repo_root: Path
    modules_root: Path
    quarantine_root: Path
    reports_root: Path


def _layout(repo_root: Path) -> ModuleLayout:
    return ModuleLayout(
        repo_root=repo_root,
        modules_root=repo_root / "state" / "modules",
        quarantine_root=repo_root / "state" / "quarantine" / "modules",
        reports_root=repo_root / "state" / "reports",
    )


def _sanitize_name(name: str) -> str:
    safe = "".join(ch for ch in name.strip() if ch.isalnum() or ch in ("-", "_"))
    if not safe:
        raise ValueError("Nombre de módulo inválido")
    return safe.lower()


def _manifest_path(module_dir: Path) -> Path:
    return module_dir / "module.toml"


def _load_manifest(module_dir: Path) -> dict[str, Any]:
    path = _manifest_path(module_dir)
    if not path.exists():
        return {}
    with path.open("rb") as fh:
        return tomllib.load(fh)


def _disabled_marker(module_dir: Path) -> Path:
    return module_dir / ".disabled"


def _validate_module(module_dir: Path) -> tuple[bool, str, dict[str, Any]]:
    manifest = _load_manifest(module_dir)
    mod = manifest.get("module", {})
    name = str(mod.get("name", "")).strip()
    entry = str(mod.get("entrypoint", "main.py")).strip() or "main.py"
    version = str(mod.get("version", "")).strip()
    enabled = bool(mod.get("enabled", True))

    if not name:
        return False, "Falta module.name en manifest", {"entrypoint": entry}
    if not version:
        return False, "Falta module.version en manifest", {"entrypoint": entry}

    entry_path = module_dir / entry
    if not entry_path.exists():
        return False, f"Entrypoint no existe: {entry}", {"entrypoint": entry}

    try:
        py_compile.compile(str(entry_path), doraise=True)
    except Exception as exc:
        return False, f"Entrypoint no compila: {exc}", {"entrypoint": entry}

    if _disabled_marker(module_dir).exists():
        return False, "Módulo marcado como deshabilitado por doctor", {"entrypoint": entry, "enabled": False}

    if not enabled:
        return False, "Módulo deshabilitado en manifest", {"entrypoint": entry, "enabled": False}

    return True, "ok", {"entrypoint": entry, "enabled": True}


def _iter_modules(layout: ModuleLayout) -> list[Path]:
    if not layout.modules_root.exists():
        return []
    return sorted(p for p in layout.modules_root.iterdir() if p.is_dir())


def action_init(layout: ModuleLayout, name: str) -> tuple[dict[str, Any], int]:
    safe_name = _sanitize_name(name)
    module_dir = layout.modules_root / safe_name
    if module_dir.exists():
        return {"status": "warn", "details": f"El módulo ya existe: {safe_name}", "module": safe_name}, 2

    module_dir.mkdir(parents=True, exist_ok=False)
    manifest = module_dir / "module.toml"
    entrypoint = module_dir / "main.py"
    manifest.write_text(
        "\n".join(
            [
                "[module]",
                f'name = "{safe_name}"',
                'version = "0.1.0"',
                'entrypoint = "main.py"',
                "enabled = true",
                "",
                "[runtime]",
                "timeout_seconds = 60",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    entrypoint.write_text(
        "\n".join(
            [
                "from __future__ import annotations",
                "",
                "import json",
                "import sys",
                "",
                "",
                "def main(argv: list[str] | None = None) -> int:",
                "    args = argv if argv is not None else sys.argv[1:]",
                f'    payload = {{"module": "{safe_name}", "args": args, "status": "ok"}}',
                "    print(json.dumps(payload, ensure_ascii=False))",
                "    return 0",
                "",
                "",
                'if __name__ == "__main__":',
                "    raise SystemExit(main())",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return {
        "status": "ok",
        "details": "Módulo inicializado",
        "module": safe_name,
        "path": str(module_dir),
    }, 0


def action_list(layout: ModuleLayout) -> tuple[dict[str, Any], int]:
    items = []
    for module_dir in _iter_modules(layout):
        ok, detail, meta = _validate_module(module_dir)
        items.append(
            {
                "name": module_dir.name,
                "status": "ok" if ok else "warn",
                "details": detail,
                **meta,
            }
        )
    return {
        "status": "ok",
        "details": "Listado generado",
        "count": len(items),
        "modules": items,
    }, 0


def action_check(layout: ModuleLayout) -> tuple[dict[str, Any], int]:
    checked = []
    has_warn = False
    for module_dir in _iter_modules(layout):
        ok, detail, meta = _validate_module(module_dir)
        has_warn = has_warn or (not ok)
        checked.append(
            {
                "name": module_dir.name,
                "status": "ok" if ok else "warn",
                "details": detail,
                **meta,
            }
        )
    return {
        "status": "warn" if has_warn else "ok",
        "details": "Validación completada",
        "modules": checked,
    }, 0 if not has_warn else 2


def action_run(layout: ModuleLayout, name: str, args: list[str], timeout: int) -> tuple[dict[str, Any], int]:
    safe_name = _sanitize_name(name)
    module_dir = layout.modules_root / safe_name
    if not module_dir.exists():
        return {"status": "fail", "details": f"Módulo no encontrado: {safe_name}"}, 2

    ok, detail, meta = _validate_module(module_dir)
    if not ok:
        return {"status": "fail", "details": f"Módulo inválido: {detail}", "module": safe_name}, 2

    entrypoint = module_dir / str(meta["entrypoint"])
    env = os.environ.copy()
    env["DJPT_MODULE_MODE"] = "1"
    env["DJPT_MODULE_NAME"] = safe_name
    proc = subprocess.run(
        [os.environ.get("PYTHON_BIN", "python3"), str(entrypoint), *args],
        cwd=str(module_dir),
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )
    return {
        "status": "ok" if proc.returncode == 0 else "fail",
        "details": "Ejecución completada" if proc.returncode == 0 else f"Falló con rc={proc.returncode}",
        "module": safe_name,
        "stdout": proc.stdout.strip(),
        "stderr": proc.stderr.strip(),
        "returncode": proc.returncode,
    }, proc.returncode


def action_doctor(layout: ModuleLayout) -> tuple[dict[str, Any], int]:
    layout.quarantine_root.mkdir(parents=True, exist_ok=True)
    quarantined = []
    for module_dir in _iter_modules(layout):
        ok, detail, _meta = _validate_module(module_dir)
        if ok:
            continue
        marker = _disabled_marker(module_dir)
        marker.write_text(
            f"disabled_at={time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\nreason={detail}\n",
            encoding="utf-8",
        )
        quarantined.append({"module": module_dir.name, "reason": detail, "marker": str(marker)})

    return {
        "status": "ok",
        "details": "Doctor aplicado sobre módulos inválidos",
        "quarantined": quarantined,
        "quarantined_count": len(quarantined),
    }, 0


def run(
    *,
    action: str,
    repo_root: Path,
    name: str | None = None,
    args: list[str] | None = None,
    timeout: int = 60,
) -> tuple[dict[str, Any], int]:
    start = time.perf_counter()
    layout = _layout(repo_root)
    layout.modules_root.mkdir(parents=True, exist_ok=True)

    payload: dict[str, Any]
    rc = 0
    if action == "init":
        if not name:
            payload, rc = {"status": "fail", "details": "Falta --name para init"}, 2
        else:
            payload, rc = action_init(layout, name)
    elif action == "list":
        payload, rc = action_list(layout)
    elif action == "check":
        payload, rc = action_check(layout)
    elif action == "run":
        if not name:
            payload, rc = {"status": "fail", "details": "Falta --name para run"}, 2
        else:
            payload, rc = action_run(layout, name, args or [], timeout)
    elif action == "doctor":
        payload, rc = action_doctor(layout)
    else:
        payload, rc = {"status": "fail", "details": f"Acción no soportada: {action}"}, 2

    payload.update(
        {
            "schema_version": SCHEMA_VERSION,
            "action": action,
            "modules_root": str(layout.modules_root),
            "execution_ms": round((time.perf_counter() - start) * 1000, 3),
        }
    )
    return payload, rc


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Gestor de módulos aislados DJProducerTools")
    parser.add_argument("action", choices=["init", "list", "check", "run", "doctor"])
    parser.add_argument("--name", help="Nombre del módulo")
    parser.add_argument("--arg", action="append", default=[], help="Argumento para el módulo (repetible)")
    parser.add_argument("--timeout", type=int, default=60, help="Timeout en segundos para run")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    args = parser.parse_args(argv)

    repo_root = Path(__file__).resolve().parent
    payload, rc = run(
        action=args.action,
        repo_root=repo_root,
        name=args.name,
        args=args.arg,
        timeout=args.timeout,
    )

    report_path = repo_root / "state" / "reports" / "module_manager.json"
    write_report(payload, report_path, schema_version=SCHEMA_VERSION, execution_ms=payload.get("execution_ms"))

    if args.format == "json":
        print(dump_report(payload, schema_version=SCHEMA_VERSION, execution_ms=payload.get("execution_ms")), end="")
    else:
        print(f"[MODULE] action={args.action} status={payload.get('status')}")
        print(f"[MODULE] details={payload.get('details')}")
        if args.action in {"list", "check"}:
            print(f"[MODULE] count={len(payload.get('modules', []))}")
        if args.action == "doctor":
            print(f"[MODULE] quarantined={payload.get('quarantined_count', 0)}")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
