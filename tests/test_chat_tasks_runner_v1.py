import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import chat_tasks_runner  # noqa: E402


def test_chat_tasks_runner_emits_json(monkeypatch, capsys, tmp_path):
    monkeypatch.setattr(
        chat_tasks_runner.chat_cli,
        "run_due_chat_tasks",
        lambda base_path, python_bin: {"status": "ok", "executed_count": 2, "executed": []},
    )
    monkeypatch.setattr(chat_tasks_runner.chat_cli, "get_python_bin", lambda base: "/tmp/python3")

    rc = chat_tasks_runner.main(["--base-path", str(tmp_path), "--json"])

    assert rc == 0
    output = capsys.readouterr().out.strip()
    payload = json.loads(output)
    assert payload["status"] == "ok"
    assert payload["executed_count"] == 2


def test_chat_tasks_runner_text_mode(monkeypatch, capsys, tmp_path):
    monkeypatch.setattr(
        chat_tasks_runner.chat_cli,
        "run_due_chat_tasks",
        lambda base_path, python_bin: {
            "status": "ok",
            "executed_count": 1,
            "executed": [{"id": "t1", "rc": 0, "details": "ok", "command": "rag status"}],
        },
    )
    monkeypatch.setattr(chat_tasks_runner.chat_cli, "get_python_bin", lambda base: "/tmp/python3")

    rc = chat_tasks_runner.main(["--base-path", str(tmp_path)])

    assert rc == 0
    output = capsys.readouterr().out
    assert "[TASK-RUNNER] status=ok executed=1" in output
    assert "rag status" in output
