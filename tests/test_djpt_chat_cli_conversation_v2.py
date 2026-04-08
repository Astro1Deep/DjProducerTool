import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = ROOT / "lib"
if str(LIB_DIR) not in sys.path:
    sys.path.insert(0, str(LIB_DIR))

import djpt_chat_cli as chat_cli  # noqa: E402


def _make_chat(monkeypatch, tmp_path):
    monkeypatch.setattr(chat_cli, "BACKENDS_AVAILABLE", False)
    monkeypatch.setattr(chat_cli, "ADVANCED_CHAT_AVAILABLE", False)
    return chat_cli.ChatCLI(tmp_path, {"venv": str(tmp_path / "djpt_venv" / "bin" / "python3")})


def test_detect_conversation_intent_understands_spanish_greeting():
    assert chat_cli.detect_conversation_intent("hola") == "greeting"
    assert chat_cli.detect_conversation_intent("qué me recomiendas ahora") == "recommendations"
    assert chat_cli.detect_conversation_intent("revisa el sistema") == "status"
    assert chat_cli.detect_conversation_intent("quiero organizar por genero") == "organize_audio"


def test_interpret_conversation_greeting_is_system_aware(monkeypatch, tmp_path):
    cli = _make_chat(monkeypatch, tmp_path)

    result = cli.interpret_conversation("hola")

    assert result["handled"] is True
    assert result["action"] is None
    assert "Base activa" in result["reply"] or "conectado a" in result["reply"]
    assert "Backends IA" in result["reply"]


def test_interpret_conversation_explicit_execution_maps_to_scan(monkeypatch, tmp_path):
    cli = _make_chat(monkeypatch, tmp_path)

    result = cli.interpret_conversation("ejecuta scan")

    assert result["handled"] is True
    assert result["scan_request"]["only"] == "media"
    assert "CLI real del scanner" in result["reply"]


def test_interpret_conversation_builds_real_scan_request(monkeypatch, tmp_path):
    cli = _make_chat(monkeypatch, tmp_path)

    result = cli.interpret_conversation("escanea la librería")

    assert result["handled"] is True
    assert result["action"] is None
    assert result["scan_request"]["only"] == "media"
    assert result["scan_request"]["path"] == tmp_path


def test_interpret_conversation_understands_scan_filters(monkeypatch, tmp_path):
    cli = _make_chat(monkeypatch, tmp_path)

    mp3 = cli.interpret_conversation("escanea solo mp3")
    wav = cli.interpret_conversation("escanea wav")
    other = cli.interpret_conversation("revisa otros archivos que no sean audio y video")

    assert mp3["scan_request"]["only"] == "mp3"
    assert wav["scan_request"]["only"] == "wav"
    assert other["scan_request"]["only"] == "other"


def test_interpret_conversation_guides_audio_organization(monkeypatch, tmp_path):
    cli = _make_chat(monkeypatch, tmp_path)

    result = cli.interpret_conversation("quiero organizar por genero")

    assert result["handled"] is True
    assert result["action"] is None
    assert "organizar" in result["reply"].lower()
    assert "/ruta" in result["reply"]


def test_resolve_engine_script_prefers_root_es_wrapper(tmp_path):
    es = tmp_path / "DJProducerTools_MultiScript_ES.sh"
    en = tmp_path / "DJProducerTools_MultiScript_EN.sh"
    es.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
    en.write_text("#!/usr/bin/env bash\n", encoding="utf-8")

    resolved = chat_cli.resolve_engine_script(tmp_path)

    assert resolved == es


def test_run_engine_uses_resolved_script_and_base_env(monkeypatch, tmp_path):
    script = tmp_path / "DJProducerTools_MultiScript_ES.sh"
    script.write_text("#!/usr/bin/env bash\n", encoding="utf-8")

    seen = {}

    def fake_run(cmd, check=False, env=None):
        seen["cmd"] = cmd
        seen["env"] = env
        class Result:
            returncode = 0
        return Result()

    monkeypatch.setattr(chat_cli, "resolve_engine_script", lambda base_path=None: script)
    monkeypatch.setattr(chat_cli, "is_virtualenv_python", lambda path: True)
    monkeypatch.setattr(chat_cli.subprocess, "run", fake_run)

    chat_cli.run_engine("backup", tmp_path)

    assert seen["cmd"] == ["bash", str(script), "--run", "backup"]
    assert seen["env"]["BASE_PATH"] == str(tmp_path)
    assert "PYTHON_BIN" in seen["env"]
