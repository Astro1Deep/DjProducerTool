#!/usr/bin/env python3
"""Tests for MCP environment manager utility."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MGR = ROOT / "scripts" / "mcp_env_manager.py"


def _run(*args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(MGR), *args],
        cwd=str(ROOT),
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_mcp_manager_status_json_schema() -> None:
    proc = _run("status", "--json")
    assert proc.returncode in (0, 1)
    data = json.loads(proc.stdout)
    assert isinstance(data["mcp_module_available"], bool)
    assert isinstance(data["mcp_server_available"], bool)
    assert isinstance(data["mcp_fetch_module_available"], bool)
    assert "mcp_fetch_module_version" in data
    assert isinstance(data["mcp_fetch_enabled"], bool)
    assert "recommended_fetch_install" in data
    assert "python_bin" in data
    assert "recommended_install" in data


def test_mcp_manager_smoke_json_schema() -> None:
    proc = _run("smoke", "--json")
    assert proc.returncode in (0, 1)
    data = json.loads(proc.stdout)
    assert "ok" in data
    if data["ok"]:
        assert data.get("tool_count", 0) >= 1


def test_mcp_manager_pair_writes_env_file(tmp_path: Path) -> None:
    env_file = tmp_path / "mcp.env"
    proc = _run("pair", "--write-env", str(env_file), "--json")
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    assert data["ok"] is True
    assert env_file.exists()

    content = env_file.read_text(encoding="utf-8")
    assert "DJPT_MCP_ENABLED" in content
    assert "DJPT_MCP_SERVER_ENTRY" in content


def test_mcp_manager_install_with_fetch_contract() -> None:
    env = os.environ.copy()
    env["PIP_NO_INDEX"] = "1"
    env["PIP_DISABLE_PIP_VERSION_CHECK"] = "1"

    proc = _run("install", "--with-fetch", "--json", env=env)
    assert proc.returncode in (0, 1)
    data = json.loads(proc.stdout)
    assert "command" in data
    assert "mcp-server-fetch" in data["command"]
    assert "status_after" in data
