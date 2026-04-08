#!/usr/bin/env python3
"""MCP environment manager for DJProducerTools.

Capabilities:
- status: inspect MCP stack and Serato pairing
- smoke: run a fast MCP server smoke test
- install: install `mcp` package (and optional `mcp-server-fetch`) in current Python env
- pair: write an MCP env profile for the current workspace
"""

from __future__ import annotations

import argparse
import asyncio
import importlib.metadata
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PAIR_FILE = PROJECT_ROOT / "state" / "config" / "mcp.env"
sys.path.insert(0, str(PROJECT_ROOT))


def detect_serato_root() -> str | None:
    candidates = [
        Path.home() / "Music" / "_Serato_",
        Path("/Volumes/SeaGate2TB/_Serato_"),
        Path("/Volumes/SeaGate2TB") / "_Serato_",
    ]
    env_candidates = [
        "DJPT_SERATO_ROOT",
        "SERATO_ROOT",
    ]
    for key in env_candidates:
        value = Path(str(v).strip()) if (v := os.environ.get(key)) else None
        if value and value.is_dir():
            return str(value)
    for candidate in candidates:
        if candidate.is_dir():
            return str(candidate)
    return None


def check_mcp_module() -> tuple[bool, str | None]:
    if importlib.util.find_spec("mcp") is None:
        return False, None
    try:
        return True, importlib.metadata.version("mcp")
    except importlib.metadata.PackageNotFoundError:
        return True, None


def check_fetch_module() -> tuple[bool, str | None]:
    try:
        version = importlib.metadata.version("mcp-server-fetch")
        return True, version
    except importlib.metadata.PackageNotFoundError:
        return False, None


def env_flag_enabled(name: str, default: bool = False) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def load_mcp_app() -> tuple[bool, str, Any]:
    try:
        from core.mcp_server_fixed import app  # pylint: disable=import-error

        return True, "", app
    except Exception as exc:  # pragma: no cover - defensive
        return False, str(exc), None


async def run_smoke_internal() -> dict[str, Any]:
    available, error, app = load_mcp_app()
    if not available or app is None:
        return {
            "ok": False,
            "error": f"Cannot import core.mcp_server_fixed: {error}",
        }

    try:
        tools = await app.list_tools()
        tool_count = len(tools) if isinstance(tools, list) else 0
        status_payload = await app.call_tool("system_status", {"detail_level": "basic"})
        status_ok = bool(status_payload) and isinstance(status_payload, list)
        return {
            "ok": tool_count >= 1 and status_ok,
            "tool_count": tool_count,
            "status_payload_items": len(status_payload) if isinstance(status_payload, list) else 0,
        }
    except Exception as exc:  # pragma: no cover - defensive
        return {
            "ok": False,
            "error": str(exc),
        }


def collect_status() -> dict[str, Any]:
    mcp_available, mcp_version = check_mcp_module()
    fetch_available, fetch_version = check_fetch_module()
    server_available, server_error, app = load_mcp_app()

    tool_count = 0
    smoke_ok = False
    smoke_error = ""
    if server_available and app is not None:
        smoke_data = asyncio.run(run_smoke_internal())
        smoke_ok = bool(smoke_data.get("ok"))
        smoke_error = str(smoke_data.get("error", ""))
        tool_count = int(smoke_data.get("tool_count", 0))

    serato_root = detect_serato_root()
    status = {
        "ok": bool(server_available and smoke_ok),
        "python_bin": sys.executable,
        "python_version": sys.version.split()[0],
        "project_root": str(PROJECT_ROOT),
        "mcp_module_available": mcp_available,
        "mcp_module_version": mcp_version,
        "mcp_fetch_module_available": fetch_available,
        "mcp_fetch_module_version": fetch_version,
        "mcp_fetch_enabled": env_flag_enabled("DJPT_MCP_FETCH_ENABLED", default=False),
        "mcp_server_available": server_available,
        "mcp_server_error": server_error,
        "mcp_smoke_ok": smoke_ok,
        "mcp_smoke_error": smoke_error,
        "mcp_tools_count": tool_count,
        "serato_root": serato_root,
        "serato_root_exists": bool(serato_root),
        "recommended_install": f"{sys.executable} -m pip install mcp",
        "recommended_fetch_install": f"{sys.executable} -m pip install mcp-server-fetch",
        "recommended_pair_file": str(DEFAULT_PAIR_FILE),
    }
    return status


def print_payload(data: dict[str, Any], as_json: bool) -> None:
    if as_json:
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return
    for key, value in data.items():
        print(f"{key}: {value}")


def cmd_status(args: argparse.Namespace) -> int:
    status = collect_status()
    print_payload(status, args.json)
    # status is informational; callers should inspect `ok` in payload.
    return 0


def cmd_smoke(args: argparse.Namespace) -> int:
    smoke = asyncio.run(run_smoke_internal())
    smoke.setdefault("ok", False)
    print_payload(smoke, args.json)
    return 0 if smoke.get("ok") else 1


def cmd_install(args: argparse.Namespace) -> int:
    cmd = [sys.executable, "-m", "pip", "install", "mcp"]
    if args.with_fetch:
        cmd.append("mcp-server-fetch")
    proc = subprocess.run(cmd, capture_output=True, text=True, cwd=str(PROJECT_ROOT))

    payload = {
        "command": " ".join(cmd),
        "returncode": proc.returncode,
        "stdout_tail": "\n".join(proc.stdout.splitlines()[-20:]),
        "stderr_tail": "\n".join(proc.stderr.splitlines()[-20:]),
    }
    payload["status_after"] = collect_status()
    print_payload(payload, args.json)
    return 0 if proc.returncode == 0 else 1


def cmd_pair(args: argparse.Namespace) -> int:
    serato_root = args.serato_root or detect_serato_root() or ""
    env_file = Path(args.write_env).expanduser()
    env_file.parent.mkdir(parents=True, exist_ok=True)

    entries = {
        "DJPT_MCP_ENABLED": "1",
        "DJPT_MCP_TRANSPORT": args.transport,
        "DJPT_MCP_SERVER_PY": sys.executable,
        "DJPT_MCP_SERVER_ENTRY": str(PROJECT_ROOT / "mcp_server_fixed.py"),
        "DJPT_MCP_ROOT": str(PROJECT_ROOT),
        "DJPT_MCP_SERATO_ROOT": serato_root,
    }

    lines = [
        "# Auto-generated by scripts/mcp_env_manager.py",
        *[f'{k}="{v}"' for k, v in entries.items()],
        "",
    ]
    env_file.write_text("\n".join(lines), encoding="utf-8")

    payload = {
        "ok": True,
        "env_file": str(env_file),
        "entries": entries,
    }
    print_payload(payload, args.json)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="DJPT MCP environment manager")
    sub = parser.add_subparsers(dest="command", required=True)

    p_status = sub.add_parser("status", help="Show MCP stack status")
    p_status.add_argument("--json", action="store_true", help="Output JSON")
    p_status.set_defaults(func=cmd_status)

    p_smoke = sub.add_parser("smoke", help="Run fast MCP smoke test")
    p_smoke.add_argument("--json", action="store_true", help="Output JSON")
    p_smoke.set_defaults(func=cmd_smoke)

    p_install = sub.add_parser("install", help="Install MCP package in current env")
    p_install.add_argument("--with-fetch", action="store_true", help="Install optional mcp-server-fetch package")
    p_install.add_argument("--json", action="store_true", help="Output JSON")
    p_install.set_defaults(func=cmd_install)

    p_pair = sub.add_parser("pair", help="Write MCP pairing env file")
    p_pair.add_argument("--write-env", default=str(DEFAULT_PAIR_FILE))
    p_pair.add_argument("--serato-root", default="")
    p_pair.add_argument("--transport", default="stdio", choices=["stdio"])
    p_pair.add_argument("--json", action="store_true", help="Output JSON")
    p_pair.set_defaults(func=cmd_pair)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
