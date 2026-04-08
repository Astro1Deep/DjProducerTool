from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "scripts" / "cli.py"


def test_cli_error_contract_helpers_exist() -> None:
    text = CLI.read_text(encoding="utf-8", errors="ignore")
    assert "def _error_payload(" in text
    assert "def _emit_error(" in text
    assert '"code"' in text and '"message"' in text and '"hint"' in text
