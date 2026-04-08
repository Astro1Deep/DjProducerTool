import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = ROOT / "lib"
if str(LIB_DIR) not in sys.path:
    sys.path.insert(0, str(LIB_DIR))

import djpt_chat_cli as chat_cli  # noqa: E402


def _make_executable(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    path.chmod(path.stat().st_mode | 0o111)


def _set_fake_module_root(monkeypatch, repo_root: Path) -> None:
    fake_module = repo_root / "lib" / "djpt_chat_cli.py"
    fake_module.parent.mkdir(parents=True, exist_ok=True)
    fake_module.write_text("# test module path\n", encoding="utf-8")
    monkeypatch.setattr(chat_cli, "__file__", str(fake_module))


def test_get_python_bin_prefers_python_bin_env(monkeypatch, tmp_path):
    explicit = tmp_path / "custom" / "python3"
    _make_executable(explicit)

    monkeypatch.setenv("PYTHON_BIN", str(explicit))
    monkeypatch.delenv("VENV_DIR", raising=False)

    found = chat_cli.get_python_bin(str(tmp_path))
    assert found == str(explicit)


def test_get_python_bin_uses_venv_dir_with_python_fallback(monkeypatch, tmp_path):
    venv_dir = tmp_path / "venv_from_env"
    py = venv_dir / "bin" / "python"
    _make_executable(py)

    monkeypatch.delenv("PYTHON_BIN", raising=False)
    monkeypatch.setenv("VENV_DIR", str(venv_dir))

    found = chat_cli.get_python_bin(str(tmp_path))
    assert found == str(py)


def test_get_python_bin_uses_candidate_dirs_order(monkeypatch, tmp_path):
    expected = tmp_path / "djpt_venv" / "bin" / "python3"
    _make_executable(expected)

    lower_priority = tmp_path / ".venv" / "bin" / "python3"
    _make_executable(lower_priority)

    monkeypatch.delenv("PYTHON_BIN", raising=False)
    monkeypatch.delenv("VENV_DIR", raising=False)

    found = chat_cli.get_python_bin(str(tmp_path))
    assert found == str(expected)


def test_get_python_bin_prefers_repo_djpt_venv(monkeypatch, tmp_path):
    monkeypatch.delenv("PYTHON_BIN", raising=False)
    monkeypatch.delenv("VENV_DIR", raising=False)

    fake_repo = tmp_path / "repo_root"
    _set_fake_module_root(monkeypatch, fake_repo)
    expected = fake_repo / "djpt_venv" / "bin" / "python3"
    _make_executable(expected)

    found = chat_cli.get_python_bin(str(tmp_path / "base_without_venv"))
    assert found == str(expected)


def test_get_python_bin_prefers_running_djpt_venv_over_legacy_state_venv(monkeypatch, tmp_path):
    monkeypatch.delenv("PYTHON_BIN", raising=False)
    monkeypatch.delenv("DJPT_PYTHON_BIN", raising=False)
    monkeypatch.delenv("VENV_DIR", raising=False)

    legacy = tmp_path / "base" / "state" / "venv" / "bin" / "python3"
    _make_executable(legacy)

    current = tmp_path / "djpt_venv" / "bin" / "python3"
    _make_executable(current)
    (tmp_path / "djpt_venv" / "pyvenv.cfg").write_text("home = test\n", encoding="utf-8")

    _set_fake_module_root(monkeypatch, tmp_path / "repo_without_venv")
    monkeypatch.setattr(sys, "executable", str(current))

    found = chat_cli.get_python_bin(str(tmp_path / "base"))
    assert found == str(current)


def test_get_python_bin_falls_back_to_sys_executable(monkeypatch, tmp_path):
    monkeypatch.delenv("PYTHON_BIN", raising=False)
    monkeypatch.delenv("VENV_DIR", raising=False)
    _set_fake_module_root(monkeypatch, tmp_path / "repo_without_venv")

    found = chat_cli.get_python_bin(str(tmp_path))
    assert found == sys.executable


def test_is_virtualenv_python_true_with_pyvenv_cfg(tmp_path):
    venv_python = tmp_path / "x" / "bin" / "python3"
    _make_executable(venv_python)
    (tmp_path / "x" / "pyvenv.cfg").write_text("home = /tmp\n", encoding="utf-8")

    assert chat_cli.is_virtualenv_python(str(venv_python)) is True


def test_is_virtualenv_python_true_with_marker_in_path(tmp_path):
    marker_python = tmp_path / ".venv" / "bin" / "python3"
    _make_executable(marker_python)

    assert chat_cli.is_virtualenv_python(str(marker_python)) is True


def test_is_virtualenv_python_false_for_missing_binary(tmp_path):
    missing = tmp_path / "missing" / "bin" / "python3"
    assert chat_cli.is_virtualenv_python(str(missing)) is False
