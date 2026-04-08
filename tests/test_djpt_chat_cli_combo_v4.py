import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = ROOT / "lib"
if str(LIB_DIR) not in sys.path:
    sys.path.insert(0, str(LIB_DIR))

import djpt_chat_cli as chat_cli  # noqa: E402


class _Diag:
    def summary(self):
        return "diag=ok"


class _Backends:
    def summary(self):
        return "ollama=active, openai=configured"


class _ChatCtx:
    def diagnose_system(self):
        return _Diag()

    def monitor_backends(self):
        return _Backends()

    def auto_heal_issues(self):
        return chat_cli.HealResult(success=True, actions=["ensure_ai_structure"])


def test_combo_status_integrates_rag_hf_module_and_tasks(monkeypatch, tmp_path):
    monkeypatch.setattr(chat_cli, "handle_rag_command", lambda *args, **kwargs: 0)
    monkeypatch.setattr(chat_cli, "handle_hf_command", lambda *args, **kwargs: 0)
    monkeypatch.setattr(chat_cli, "handle_module_command", lambda *args, **kwargs: 0)
    monkeypatch.setattr(chat_cli, "load_chat_tasks", lambda base_path: {"tasks": [{"id": "a"}, {"id": "b"}]})

    payload, rc = chat_cli.run_combined_pipeline("status", [], sys.executable, tmp_path, chat_context=_ChatCtx())

    assert rc == 0
    assert payload["status"] == "ok"
    assert payload["details"]["diagnostic"] == "diag=ok"
    assert payload["details"]["tasks_count"] == 2
    assert [s["step"] for s in payload["steps"]] == [
        "rag_status",
        "hf_status",
        "module_list",
        "tasks_inventory",
    ]


def test_combo_learn_requires_url(tmp_path):
    payload, rc = chat_cli.run_combined_pipeline("learn", [], sys.executable, tmp_path, chat_context=_ChatCtx())
    assert rc == 2
    assert payload["status"] == "fail"
    assert "Falta URL" in payload["details"]


def test_combo_learn_runs_web_capture_and_status(monkeypatch, tmp_path):
    monkeypatch.setattr(
        chat_cli,
        "study_web_page",
        lambda url, base_path, python_bin, index_rag=True: {
            "status": "ok",
            "details": "Contenido web capturado",
            "url": url,
            "path": str(tmp_path / "kb" / "raw" / "web.md"),
        },
    )
    monkeypatch.setattr(chat_cli, "handle_rag_command", lambda *args, **kwargs: 0)
    monkeypatch.setattr(chat_cli, "handle_hf_command", lambda *args, **kwargs: 0)

    payload, rc = chat_cli.run_combined_pipeline(
        "learn",
        ["https://huggingface.co/models"],
        sys.executable,
        tmp_path,
        chat_context=_ChatCtx(),
    )

    assert rc == 0
    assert payload["status"] == "ok"
    assert payload["details"]["study"]["status"] == "ok"
    assert [s["step"] for s in payload["steps"]] == ["study_web", "rag_status", "hf_status"]


def test_combo_optimize_runs_safe_chain(monkeypatch, tmp_path):
    monkeypatch.setattr(chat_cli, "handle_module_command", lambda *args, **kwargs: 0)
    monkeypatch.setattr(chat_cli, "handle_rag_command", lambda *args, **kwargs: 0)
    monkeypatch.setattr(chat_cli, "handle_hf_command", lambda *args, **kwargs: 0)
    monkeypatch.setattr(
        chat_cli,
        "run_due_chat_tasks",
        lambda base_path, python_bin: {"status": "ok", "executed_count": 3, "executed": []},
    )

    payload, rc = chat_cli.run_combined_pipeline("optimize", [], sys.executable, tmp_path, chat_context=_ChatCtx())

    assert rc == 0
    assert payload["status"] == "ok"
    assert payload["details"]["executed_tasks"] == 3
    assert [s["step"] for s in payload["steps"]] == [
        "autoheal",
        "module_doctor",
        "tasks_run",
        "rag_status",
        "hf_status",
    ]
