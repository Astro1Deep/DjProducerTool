#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = REPO_ROOT / "lib"
if str(LIB_DIR) not in sys.path:
    sys.path.insert(0, str(LIB_DIR))

import djpt_chat_cli as chat_cli  # noqa: E402


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Ejecuta tareas vencidas del scheduler de DJPT Chat (one-shot)."
    )
    parser.add_argument(
        "--base-path",
        default=str(REPO_ROOT),
        help="Ruta base de DJProducerTools",
    )
    parser.add_argument(
        "--python-bin",
        default=None,
        help="Python del entorno DJPT (por defecto autodetección)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Salida JSON",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    base_path = Path(args.base_path).expanduser().resolve()
    python_bin = args.python_bin or chat_cli.get_python_bin(str(base_path))
    payload = chat_cli.run_due_chat_tasks(base_path, python_bin)

    if args.json:
        print(json.dumps(payload, ensure_ascii=False))
    else:
        print(f"[TASK-RUNNER] status={payload.get('status')} executed={payload.get('executed_count', 0)}")
        for item in payload.get("executed", []):
            print(
                f"  - {item.get('id')} rc={item.get('rc')} "
                f"{item.get('details', '')} :: {item.get('command', '')}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
