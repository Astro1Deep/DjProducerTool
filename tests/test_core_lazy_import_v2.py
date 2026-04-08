import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_blocking_peewee(script: str) -> subprocess.CompletedProcess[str]:
    env = dict(os.environ)
    env["PYTHONPATH"] = str(ROOT)
    return subprocess.run(
        [sys.executable, "-c", script],
        text=True,
        capture_output=True,
        env=env,
        cwd=ROOT,
    )


def test_core_config_import_does_not_require_peewee():
    script = r"""
import importlib.abc

class BlockPeewee(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if fullname == "peewee":
            raise ModuleNotFoundError("blocked peewee")
        return None

import sys
sys.meta_path.insert(0, BlockPeewee())
from core.config import Config
print(Config.BASE_DIR)
"""
    result = run_blocking_peewee(script)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip()


def test_scripts_core_scanner_help_does_not_require_peewee():
    script = r"""
import importlib.abc
import runpy
import sys

class BlockPeewee(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if fullname == "peewee":
            raise ModuleNotFoundError("blocked peewee")
        return None

sys.meta_path.insert(0, BlockPeewee())
sys.argv = ["scripts.core.scanner", "--help"]
try:
    runpy.run_module("scripts.core.scanner", run_name="__main__")
except SystemExit as exc:
    raise SystemExit(0 if exc.code in (None, 0) else exc.code)
"""
    result = run_blocking_peewee(script)
    assert result.returncode == 0, result.stderr
    assert "DJPT Scanner" in result.stdout
