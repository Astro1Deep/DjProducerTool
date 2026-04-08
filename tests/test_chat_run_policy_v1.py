from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHAT_CLI = ROOT / "scripts" / "djpt_chat_cli.py"


def test_chat_cli_has_safe_run_policy_contract() -> None:
    text = CHAT_CLI.read_text(encoding="utf-8", errors="ignore")

    assert "BLOCKED_DESTRUCTIVE_ACTIONS" in text
    assert "DJPT_ALLOW_DESTRUCTIVE" in text
    assert "def run_action_safe(" in text
    assert "run <id>" in text or "run <id|keyword>" in text
