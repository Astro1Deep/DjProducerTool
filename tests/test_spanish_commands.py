#!/usr/bin/env python3
"""
Spanish Voice Commands Test for DJProducerTools.
Canonical pytest-style tests with optional CLI runner compatibility.
"""

import asyncio
import os
import sys
import tempfile
from pathlib import Path

import pytest

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

try:
    from ai.mlx_audio_integration import MLXAudioIntegration
    from ai.voice_control import VoiceControl

    AUDIO_AVAILABLE = True
except ImportError:
    AUDIO_AVAILABLE = False


def _require_audio_components() -> None:
    if not AUDIO_AVAILABLE:
        pytest.skip("Audio components not available")


def test_spanish_command_parsing():
    """Test Spanish command parsing."""
    _require_audio_components()

    integration = MLXAudioIntegration()

    spanish_commands = [
        ("reproducir siguiente", "play", {"track": "next"}),
        ("reproducir anterior", "play", {"track": "previous"}),
        ("reproducir actual", "play", {"track": "current"}),
        ("parar música", "stop", {}),
        ("analizar canción", "analyze", {"target": "track"}),
        ("analizar bpm", "analyze", {"target": "bpm"}),
        ("analizar clave", "analyze", {"target": "key"}),
        ("convertir a mp3", "convert", {"format": "mp3"}),
        ("convertir a wav", "convert", {"format": "wav"}),
        ("estado del sistema", "status", {}),
        ("ayuda", "help", {}),
        ("qué comandos hay", "help", {}),
    ]

    failures = []
    for command_text, expected_action, expected_params in spanish_commands:
        command = integration._parse_command(command_text, "general")
        if command.get("action") != expected_action:
            failures.append(f"{command_text}: expected action={expected_action}, got={command.get('action')}")
            continue
        for key, value in expected_params.items():
            if command.get("parameters", {}).get(key) != value:
                failures.append(
                    f"{command_text}: expected parameter {key}={value}, got={command.get('parameters', {}).get(key)}"
                )

    assert not failures, " ; ".join(failures)


def test_spanish_responses():
    """Test Spanish response generation."""
    _require_audio_components()

    integration = MLXAudioIntegration()

    spanish_test_cases = [
        {
            "command": {"action": "play", "parameters": {"track": "next"}, "language": "spanish"},
            "expected_text": "Reproduciendo next",
        },
        {
            "command": {"action": "stop", "parameters": {}, "language": "spanish"},
            "expected_text": "Reproducción detenida",
        },
        {
            "command": {"action": "analyze", "parameters": {"target": "bpm"}, "language": "spanish"},
            "expected_text": "Analizando bpm",
        },
        {
            "command": {"action": "convert", "parameters": {"format": "mp3"}, "language": "spanish"},
            "expected_text": "Convirtiendo audio a formato mp3",
        },
        {
            "command": {"action": "help", "parameters": {}, "language": "spanish"},
            "expected_text": "Comandos de voz disponibles",
        },
        {
            "command": {"action": "unknown", "parameters": {}, "language": "spanish"},
            "expected_text": "No entendí ese comando",
        },
    ]

    failures = []
    for case in spanish_test_cases:
        command = case["command"]
        expected_text = case["expected_text"]
        response = integration._generate_response(command, "test transcription")
        if expected_text not in response:
            failures.append(f"{command['action']}: expected text '{expected_text}' in '{response}'")

    assert not failures, " ; ".join(failures)


def test_language_detection():
    """Test language detection."""
    _require_audio_components()

    integration = MLXAudioIntegration()

    language_test_cases = [
        ("reproducir música", "spanish"),
        ("play music", "english"),
        ("analizar canción", "spanish"),
        ("analyze song", "english"),
        ("convertir a mp3", "spanish"),
        ("convert to mp3", "english"),
        ("estado del sistema", "spanish"),
        ("system status", "english"),
        ("ayuda por favor", "spanish"),
        ("help please", "english"),
    ]

    failures = []
    for text, expected_language in language_test_cases:
        command = integration._parse_command(text, "general")
        detected_language = command.get("language", "unknown")
        if detected_language != expected_language:
            failures.append(f"{text}: expected={expected_language}, got={detected_language}")

    assert not failures, " ; ".join(failures)


def test_voice_control_spanish():
    """Test voice control with Spanish commands."""
    _require_audio_components()

    voice_control = VoiceControl()

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
        tmp_file.write(b"fake spanish voice data")
        tmp_file_path = tmp_file.name

    try:
        result = asyncio.run(voice_control.process_command(tmp_file_path, "general"))
        assert isinstance(result, dict)
        assert "success" in result

        spanish_command = {
            "action": "play",
            "parameters": {"track": "siguiente"},
            "language": "spanish",
            "confidence": 0.8,
        }
        response = asyncio.run(voice_control.generate_response(spanish_command))
        assert isinstance(response, str)
        assert len(response) > 0
    finally:
        if os.path.exists(tmp_file_path):
            os.unlink(tmp_file_path)


def run_spanish_tests() -> bool:
    """Run all Spanish language tests manually (legacy CLI mode)."""
    print("Testing Spanish Voice Commands for DJProducerTools")
    print("=" * 60)

    tests = [
        ("Spanish Command Parsing", test_spanish_command_parsing),
        ("Spanish Response Generation", test_spanish_responses),
        ("Language Detection", test_language_detection),
        ("Voice Control Spanish", test_voice_control_spanish),
    ]

    passed = 0
    failed = 0
    skipped = 0

    for test_name, test_func in tests:
        print(f"\nRunning {test_name}...")
        try:
            test_func()
            passed += 1
            print(f"PASS {test_name}")
        except pytest.skip.Exception as exc:  # type: ignore[attr-defined]
            skipped += 1
            print(f"SKIP {test_name}: {exc}")
        except Exception as exc:
            failed += 1
            print(f"FAIL {test_name}: {exc}")

    print("\n" + "=" * 60)
    print(f"Passed: {passed}")
    print(f"Skipped: {skipped}")
    print(f"Failed: {failed}")
    print(f"Total:  {passed + skipped + failed}")
    return failed == 0


if __name__ == "__main__":
    success = run_spanish_tests()
    sys.exit(0 if success else 1)
