import json
import os
import subprocess
import sys
from pathlib import Path


def _extract_json_payload(output: str) -> dict:
    start = output.find("{")
    end = output.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise AssertionError(f"No JSON object found in output:\n{output}")
    return json.loads(output[start:end + 1])


def test_enhanced_chat_cli_wrapper_context():
    this_file = Path(__file__).resolve()
    root = None
    for candidate in [this_file.parent, *this_file.parents]:
        if (candidate / "enhanced_chat_cli.py").exists() and (candidate / "scripts").is_dir():
            root = candidate
            break
    if root is None:
        root = this_file.parents[1]
    wrapper = root / "enhanced_chat_cli.py"
    assert wrapper.exists(), "Wrapper script missing"

    result = subprocess.run(
        [sys.executable, str(wrapper), "--context"],
        capture_output=True,
        text=True,
        env={**os.environ, "PYTHONUNBUFFERED": "1"},
    )
    assert result.returncode == 0, result.stderr

    payload = _extract_json_payload(result.stdout)
    assert isinstance(payload, dict)
    assert "system_info" in payload
    assert "available_scripts" in payload
    assert "ai_capabilities" in payload
    assert "recent_operations" in payload
    assert "user_preferences" in payload
