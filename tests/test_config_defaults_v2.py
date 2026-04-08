from __future__ import annotations

from scripts.config_schema import Settings


def test_config_defaults_are_explicit() -> None:
    settings = Settings()
    assert settings.general.preferred_backend in {"auto", "mlx", "tensorflow", "ollama"}
    assert settings.jobs.scan_workers > 0
    assert settings.limits.max_memory_usage <= 0.9
