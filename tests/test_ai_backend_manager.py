#!/usr/bin/env python3
"""
Tests for ia_backend_manager: skip controls, safe auto-heal, CLI JSON output.
Uses unittest to avoid external dependencies.
"""

import json
import os
import subprocess
import tempfile
import unittest
from contextlib import contextmanager
from pathlib import Path

import ia_backend_manager


@contextmanager
def temp_env(**env):
    original = {k: os.environ.get(k) for k in env}
    os.environ.update({k: str(v) for k, v in env.items()})
    try:
        yield
    finally:
        for k, v in original.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


class TestIABackendManager(unittest.TestCase):
    def test_status_respects_skip_env(self):
        """Setting DJPT_SKIP_* forces modules to be treated as unavailable with message."""
        with tempfile.TemporaryDirectory() as td, temp_env(DJPT_SKIP_MLX=1, DJPT_SKIP_TF=1):
            mgr = ia_backend_manager.IABackendManager(Path(td))
            status = mgr.status()

            self.assertFalse(status.mlx_available)
            self.assertTrue(any("DJPT_SKIP_MLX" in msg for msg in status.messages))

    def test_auto_heal_creates_dirs(self):
        """Auto-heal only creates local cache/model directories."""
        with tempfile.TemporaryDirectory() as td:
            mgr = ia_backend_manager.IABackendManager(Path(td))
            heal = mgr.auto_heal()

            self.assertTrue((Path(td) / "ai" / "models").exists())
            self.assertTrue((Path(td) / "state" / "cache").exists())
            self.assertTrue(any("mkdir" in action for action in heal.actions))

    def test_cli_json_output(self):
        """CLI emits JSON without heavy imports when skips are set."""
        with tempfile.TemporaryDirectory() as td, temp_env(DJPT_SKIP_MLX=1, DJPT_SKIP_TF=1):
            repo_root = Path(__file__).resolve().parent.parent
            cmd = [
                "python3",
                str(repo_root / "ia_backend_manager.py"),
                "--base-path",
                str(td),
                "--json",
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)

            self.assertEqual(result.returncode, 0, msg=result.stderr)
            payload = json.loads(result.stdout)
            self.assertIn("status", payload)
            self.assertIn("ollama_ready", payload["status"])


if __name__ == "__main__":
    unittest.main()
