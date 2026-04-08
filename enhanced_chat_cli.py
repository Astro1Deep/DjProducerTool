#!/usr/bin/env python3
"""Canonical Enhanced Chat CLI wrapper.

Provides a stable root-level entrypoint for menu dispatch, tests, and deployed
copies of DJProducerTools. Runtime chat execution is delegated to the canonical
`lib/djpt_chat_cli.py` implementation.
"""

from __future__ import annotations

import json
import os
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
CANONICAL_CHAT = ROOT / "lib" / "djpt_chat_cli.py"
STATE_DIR = ROOT / "state"
REPORTS_DIR = STATE_DIR / "reports"
CONFIG_DIR = STATE_DIR / "config"


def _tail_lines(path: Path, limit: int = 5) -> list[str]:
    if not path.exists():
        return []
    try:
        lines = [line.strip() for line in path.read_text(encoding="utf-8", errors="ignore").splitlines()]
    except OSError:
        return []
    return [line for line in lines if line][-limit:]


def _recent_files(path: Path, limit: int = 5) -> list[str]:
    if not path.exists():
        return []
    files = [item for item in path.iterdir() if item.is_file()]
    files.sort(key=lambda item: item.stat().st_mtime, reverse=True)
    return [item.name for item in files[:limit]]


def _load_key_value_config(path: Path) -> dict[str, str]:
    payload: dict[str, str] = {}
    if not path.exists():
        return payload
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        payload[key.strip()] = value.strip().strip('"').strip("'")
    return payload


def _load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8", errors="ignore"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def _build_context() -> dict[str, Any]:
    config = _load_key_value_config(ROOT / "djpt.conf")
    ai_capabilities = _load_json(STATE_DIR / "ai_capabilities.json") or {
        "chat_cli": CANONICAL_CHAT.exists(),
        "enhanced_wrapper": (ROOT / "scripts" / "chat" / "enhanced_chat_cli.py").exists(),
        "ai_health": (ROOT / "ai_health.py").exists(),
        "ai_status": (ROOT / "ai_status_enhanced.py").exists(),
        "ai_models_config": (ROOT / "config" / "ai_model_params.toml").exists(),
        "selected_backend": os.environ.get("DJPT_CHAT_BACKEND", "auto"),
    }
    available_scripts = [
        rel for rel in [
            "cli.py",
            "enhanced_chat_cli.py",
            "scripts/chat/enhanced_chat_cli.py",
            "lib/djpt_chat_cli.py",
            "ai_health.py",
            "ai_status_enhanced.py",
            "scripts/DJProducerTools_MultiScript_ES.sh",
        ]
        if (ROOT / rel).exists()
    ]
    user_preferences = {
        "base_path": os.environ.get("BASE_PATH") or config.get("BASE_PATH") or str(ROOT),
        "safe_mode": os.environ.get("SAFE_MODE") or config.get("SAFE_MODE") or "0",
        "dry_run": os.environ.get("DRY_RUN") or config.get("DRY_RUN") or "0",
        "ui_mode": os.environ.get("DJPT_UI_MODE") or config.get("DJPT_UI_MODE") or "interactive",
        "chat_backend": os.environ.get("DJPT_CHAT_BACKEND", "auto"),
    }
    recent_operations = {
        "recent_reports": _recent_files(REPORTS_DIR),
        "base_history": _tail_lines(CONFIG_DIR / "base_history.txt"),
        "general_history": _tail_lines(CONFIG_DIR / "general_history.txt"),
    }
    return {
        "system_info": {
            "project_root": str(ROOT),
            "cwd": os.getcwd(),
            "python_executable": sys.executable,
            "python_version": sys.version.split()[0],
            "platform": platform.platform(),
            "venv_active": os.environ.get("VIRTUAL_ENV") or "",
        },
        "available_scripts": available_scripts,
        "ai_capabilities": ai_capabilities,
        "recent_operations": recent_operations,
        "user_preferences": user_preferences,
    }


def _delegate(argv: list[str], extra_env: dict[str, str] | None = None) -> int:
    if not CANONICAL_CHAT.exists():
        sys.stderr.write(json.dumps({
            "code": "chat_cli_missing",
            "message": f"Canonical chat CLI not found at {CANONICAL_CHAT}",
            "hint": "Restore lib/djpt_chat_cli.py in the project root.",
        }) + "\n")
        return 2

    env = os.environ.copy()
    env.setdefault("BASE_PATH", str(ROOT))
    env.setdefault("DJPT_CANONICAL_ROOT", str(ROOT))
    env.setdefault("PYTHONUNBUFFERED", "1")
    env.setdefault("PYTHON_BIN", sys.executable)
    env.setdefault("DJPT_PYTHON_BIN", sys.executable)
    env.setdefault("VENV_DIR", str(Path(sys.executable).resolve().parent.parent))
    if extra_env:
        env.update(extra_env)

    proc = subprocess.run([sys.executable, str(CANONICAL_CHAT), *argv], cwd=ROOT, env=env)
    return int(proc.returncode)


def main() -> int:
    argv = sys.argv[1:]
    if argv and argv[0] == "--context":
        print(json.dumps(_build_context(), indent=2, ensure_ascii=False))
        return 0
    if argv and argv[0] == "--insights":
        payload = _build_context()
        print("=== Enhanced Chat CLI Insights ===")
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0
    if argv and argv[0] == "--chat":
        extra_env: dict[str, str] = {}
        forward = argv[1:]
        if forward and not forward[0].startswith("-"):
            extra_env["DJPT_CHAT_BACKEND"] = forward[0]
            forward = forward[1:]
        return _delegate(forward, extra_env=extra_env)
    return _delegate(argv)


if __name__ == "__main__":
    raise SystemExit(main())
