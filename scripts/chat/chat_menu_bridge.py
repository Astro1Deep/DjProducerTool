from __future__ import annotations

import json
from pathlib import Path
from typing import Any, List


class ChatMenuBridge:
    def __init__(self, state_dir: str | Path):
        self.state_dir = Path(state_dir)
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.command_file = self.state_dir / ".chat_cmd"
        self.result_file = self.state_dir / ".chat_result"
        self.state_file = self.state_dir / ".chat_state.json"

    def request_action(self, slot: str) -> bool:
        self.command_file.write_text(f"CMD:JUMP:{slot}", encoding="utf-8")
        return True

    def request_exit(self) -> bool:
        self.command_file.write_text("CMD:EXIT", encoding="utf-8")
        return True

    def save_chat_state(self, history: List[dict[str, Any]]) -> None:
        self.state_file.write_text(json.dumps(history, ensure_ascii=False, indent=2), encoding="utf-8")

    def load_chat_state(self) -> List[dict[str, Any]]:
        if not self.state_file.exists():
            return []
        return json.loads(self.state_file.read_text(encoding="utf-8"))

    def get_last_result(self) -> str:
        if not self.result_file.exists():
            return ""
        payload = self.result_file.read_text(encoding="utf-8")
        self.result_file.unlink()
        return payload
