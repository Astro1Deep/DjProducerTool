import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import launchd_chat_tasks  # noqa: E402


def test_render_plist_contains_required_fields(tmp_path):
    text = launchd_chat_tasks.render_plist(
        label="com.djpt.test",
        program_args=["/usr/bin/python3", "/tmp/chat_tasks_runner.py", "--json"],
        start_interval=600,
        stdout_path=tmp_path / "out.log",
        stderr_path=tmp_path / "err.log",
        working_directory=tmp_path,
    )
    assert "<key>Label</key>" in text
    assert "<string>com.djpt.test</string>" in text
    assert "<key>StartInterval</key>" in text
    assert "<integer>600</integer>" in text
    assert "/tmp/chat_tasks_runner.py" in text
    assert "<key>ProgramArguments</key>" in text


def test_install_agent_dry_run_writes_plist(tmp_path):
    plist_path = tmp_path / "com.djpt.test.plist"
    rc = launchd_chat_tasks.install_agent(
        label="com.djpt.test",
        plist_path=plist_path,
        program_args=["/usr/bin/python3", "/tmp/chat_tasks_runner.py", "--json"],
        start_interval=300,
        apply=False,
    )
    assert rc == 0
    assert plist_path.exists()
    content = plist_path.read_text(encoding="utf-8")
    assert "com.djpt.test" in content
    assert "chat_tasks_runner.py" in content


def test_build_program_args_uses_runner_path(tmp_path):
    args = launchd_chat_tasks._build_program_args(tmp_path, "/usr/bin/python3")
    assert args[0] == "/usr/bin/python3"
    assert "chat_tasks_runner.py" in args[1]
    assert "--base-path" in args
    assert str(tmp_path) in args
