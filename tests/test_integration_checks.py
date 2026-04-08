#!/usr/bin/env python3
"""Deterministic tests for integration_checks.py."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "integration_checks.py"


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args, "--json"],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        check=False,
    )


def test_serato_schema() -> None:
    proc = _run("serato")
    assert proc.returncode in (0, 1)
    data = json.loads(proc.stdout)
    assert "serato" in data
    assert "status" in data["serato"]
    assert "parser_available" in data["serato"]
    assert "tools_available" in data["serato"]


def test_spotify_not_configured_is_actionable() -> None:
    proc = _run("spotify", "--spotify-client-id", "", "--spotify-client-secret", "")
    assert proc.returncode == 1
    data = json.loads(proc.stdout)
    assert data["spotify"]["status"] == "not_configured"
    assert "Client ID/Secret" in data["spotify"]["message"]


def test_mcp_schema() -> None:
    proc = _run("mcp")
    assert proc.returncode in (0, 1)
    data = json.loads(proc.stdout)
    assert "mcp" in data
    assert "status" in data["mcp"]


def test_all_schema() -> None:
    proc = _run("all", "--spotify-client-id", "", "--spotify-client-secret", "")
    assert proc.returncode in (0, 1)
    data = json.loads(proc.stdout)
    assert "overall_ok_core" in data
    assert "overall_ok_strict" in data
    assert "serato" in data
    assert "spotify" in data
    assert "musicbrainz" in data
    assert "mcp" in data
