from __future__ import annotations

from pathlib import Path

import core.mcp_server_fixed as core_mcp
import mcp_server
import mcp_server_fixed


ROOT = Path(__file__).resolve().parents[1]


def test_mcp_wrappers_delegate_to_canonical_app() -> None:
    assert mcp_server.app is core_mcp.app
    assert mcp_server_fixed.app is core_mcp.app


def test_mcp_wrappers_delegate_to_canonical_main() -> None:
    assert mcp_server.main is core_mcp.main
    assert mcp_server_fixed.main is core_mcp.main


def test_wrapper_sources_pin_core_canonical_import() -> None:
    wrapper_files = [ROOT / "mcp_server.py", ROOT / "mcp_server_fixed.py"]
    for wrapper in wrapper_files:
        content = wrapper.read_text(encoding="utf-8")
        assert "from core.mcp_server_fixed import *" in content

