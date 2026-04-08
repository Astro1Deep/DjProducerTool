from __future__ import annotations

from pathlib import Path

from config_schema import ConfigManager


ROOT = Path(__file__).resolve().parents[1]


def test_canonical_ai_config_exists_and_loads() -> None:
    config_path = ROOT / "config" / "ai_model_params.toml"
    assert config_path.exists(), "canonical AI config file missing"

    manager = ConfigManager(config_path=config_path)
    settings = manager.load_settings()

    assert settings.general.preferred_backend in {"auto", "mlx", "tensorflow", "ollama"}
    assert settings.mlx.device in {"metal", "cpu"}
    assert settings.tensorflow.device in {"auto", "cpu", "gpu", "mps"}
    assert settings.ollama.default_model == "llama3.2:3b"
