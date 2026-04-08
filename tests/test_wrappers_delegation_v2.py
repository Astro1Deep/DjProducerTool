from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_ai_status_wrapper_delegates() -> None:
    text = (ROOT / "scripts" / "ai_status.py").read_text(encoding="utf-8", errors="ignore")
    assert "from scripts.ai_status_enhanced import main" in text


def test_chat_wrapper_delegates_to_canonical_chat_cli() -> None:
    text = (ROOT / "scripts" / "chat" / "enhanced_chat_cli.py").read_text(encoding="utf-8", errors="ignore")
    assert "djpt_chat_cli.py" in text
    assert "subprocess.run" in text
