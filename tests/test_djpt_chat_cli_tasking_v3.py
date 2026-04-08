import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = ROOT / "lib"
if str(LIB_DIR) not in sys.path:
    sys.path.insert(0, str(LIB_DIR))

import djpt_chat_cli as chat_cli  # noqa: E402


def test_detect_conversation_intent_extended_ops():
    assert chat_cli.detect_conversation_intent("programa tarea cada 10m") == "schedule"
    assert chat_cli.detect_conversation_intent("quiero usar rag para consultar") == "rag_ops"
    assert chat_cli.detect_conversation_intent("sincroniza modelo huggingface") == "hf_ops"
    assert chat_cli.detect_conversation_intent("estudia web https://example.com para aprender") == "study_web"


def test_study_web_page_saves_local_knowledge(monkeypatch, tmp_path):
    html = """
    <html><head><title>Test</title></head>
    <body><h1>DJPT</h1><p>Aprendizaje operativo con IA local y control modular para tareas reales en biblioteca media.
    Este bloque extiende contenido para superar umbral mínimo de validación del extractor web.</p></body></html>
    """
    monkeypatch.setattr(chat_cli, "fetch_web_page", lambda url, timeout=20: html)

    result = chat_cli.study_web_page("https://example.com/page", tmp_path, sys.executable, index_rag=False)

    assert result["status"] == "ok"
    saved = Path(result["path"])
    assert saved.exists()
    content = saved.read_text(encoding="utf-8")
    assert "https://example.com/page" in content
    assert "Aprendizaje operativo" in content


def test_study_web_page_can_index_rag(monkeypatch, tmp_path):
    html = "<html><body><p>" + ("contenido " * 30) + "</p></body></html>"
    monkeypatch.setattr(chat_cli, "fetch_web_page", lambda url, timeout=20: html)
    monkeypatch.setattr(chat_cli, "run_cli_bridge", lambda *args, **kwargs: (0, "indexed", ""))

    result = chat_cli.study_web_page("https://example.com/docs", tmp_path, sys.executable, index_rag=True)

    assert result["status"] == "ok"
    assert result["rag_index"]["ok"] is True
    assert result["rag_index"]["rc"] == 0


def test_chat_tasks_create_and_run_due(monkeypatch, tmp_path):
    task = chat_cli.create_chat_task(tmp_path, "10m", "rag status")
    payload = chat_cli.load_chat_tasks(tmp_path)
    assert len(payload["tasks"]) == 1
    assert payload["tasks"][0]["id"] == task["id"]

    seen = {}

    def fake_runner(command_line, python_bin, base_path):
        seen["command"] = command_line
        seen["python_bin"] = python_bin
        seen["base_path"] = str(base_path)
        return 0, "ok"

    now_ts = float(task["next_run_ts"]) + 1
    result = chat_cli.run_due_chat_tasks(tmp_path, sys.executable, now_ts=now_ts, runner=fake_runner)

    assert result["executed_count"] == 1
    assert seen["command"] == "rag status"
    updated = chat_cli.load_chat_tasks(tmp_path)["tasks"][0]
    assert updated["run_count"] == 1
    assert updated["last_rc"] == 0
    assert float(updated["next_run_ts"]) > now_ts


def test_execute_scheduled_command_routes_hf(monkeypatch, tmp_path):
    monkeypatch.setattr(chat_cli, "handle_hf_command", lambda args, python_bin, base_path, emit=False: 0)

    rc, details = chat_cli.execute_scheduled_command("hf status", sys.executable, tmp_path)

    assert rc == 0
    assert details == "hf-sync"
