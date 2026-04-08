#!/usr/bin/env python3
import unittest
import os
import sys
import shutil
import tempfile
from pathlib import Path

# Add repo root to path
REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from scripts.config_schema import resolve_config_file, ConfigManager

class TestCLIConfigResolutionV2(unittest.TestCase):
    def setUp(self):
        self.test_dir = Path(tempfile.mkdtemp()).resolve()
        self.config_dir = self.test_dir / "config"
        self.config_dir.mkdir()
        self.dummy_conf = self.config_dir / "ai_model_params.toml"
        self.dummy_conf.touch()

    def tearDown(self):
        shutil.rmtree(self.test_dir)
        # Restore env
        if "DJPT_CONFIG_FILE" in os.environ:
            del os.environ["DJPT_CONFIG_FILE"]

    def test_env_var_precedence(self):
        """DJPT_CONFIG_FILE should take precedence"""
        custom_conf = (self.test_dir / "custom.toml").resolve()
        custom_conf.touch()
        os.environ["DJPT_CONFIG_FILE"] = str(custom_conf)
        
        resolved = resolve_config_file(self.test_dir)
        self.assertEqual(resolved.resolve(), custom_conf)

    def test_standard_location(self):
        """Should find config in base_dir/config/"""
        if "DJPT_CONFIG_FILE" in os.environ:
            del os.environ["DJPT_CONFIG_FILE"]
            
        resolved = resolve_config_file(self.test_dir)
        self.assertEqual(resolved.resolve(), self.dummy_conf.resolve())

    def test_manager_loading(self):
        """ConfigManager should load from resolved path"""
        content = """[general]
preferred_backend = "mlx"
"""
        self.dummy_conf.write_text(content, encoding="utf-8")
        
        manager = ConfigManager(config_path=self.dummy_conf)
        settings = manager.load_settings()
        self.assertEqual(settings.general.preferred_backend, "mlx")

if __name__ == "__main__":
    unittest.main()