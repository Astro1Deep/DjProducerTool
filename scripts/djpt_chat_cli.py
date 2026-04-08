#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "lib" / "djpt_chat_cli.py"
BLOCKED_DESTRUCTIVE_ACTIONS = {"apply", "apply_real", "delete", "purge", "quarantine", "reset"}
DJPT_ALLOW_DESTRUCTIVE = "DJPT_ALLOW_DESTRUCTIVE"


def _load_target_module():
    spec = importlib.util.spec_from_file_location("djpt_chat_cli_target", TARGET)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"No se pudo cargar el chat CLI canónico: {TARGET}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def run_action_safe(argv: Iterable[str]) -> int:
    args = list(argv)
    if args and args[0] == "run" and len(args) > 1:
        action = args[1].strip().lower()
        if action in BLOCKED_DESTRUCTIVE_ACTIONS and os.environ.get(DJPT_ALLOW_DESTRUCTIVE) != "1":
            print(
                f"[ERR] Acción destructiva bloqueada: {action}. "
                f"Exporta {DJPT_ALLOW_DESTRUCTIVE}=1 para permitir run <id|keyword>."
            )
            return 2
    return 0


_TARGET_MODULE = _load_target_module()
_TARGET_MODULE.BLOCKED_DESTRUCTIVE_ACTIONS = BLOCKED_DESTRUCTIVE_ACTIONS
_TARGET_MODULE.DJPT_ALLOW_DESTRUCTIVE = DJPT_ALLOW_DESTRUCTIVE
_TARGET_MODULE.run_action_safe = run_action_safe


def main() -> int:
    gate = run_action_safe(sys.argv[1:])
    if gate != 0:
        return gate
    return int(_TARGET_MODULE.main() or 0)


if __name__ != "__main__":
    sys.modules[__name__] = _TARGET_MODULE


if __name__ == "__main__":
    raise SystemExit(main())
