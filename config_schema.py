from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict, Optional

from lib.config_schema import (
    CONFIG_FILE as LIB_CONFIG_FILE,
    CAPABILITIES_FILE,
    PROFILE_FILE,
    BASE_DIR as LIB_BASE_DIR,
    ConfigManager as _LibConfigManager,
    General,
    Jobs,
    Learning,
    Limits,
    MLX,
    Ollama,
    Optimization,
    Settings,
    TensorFlow,
    Threads,
    Trends,
    export_all_env_vars as _lib_export_all_env_vars,
    save_settings as _lib_save_settings,
    validate_backend,
    validate_memory_fraction,
    validate_positive_int,
    validate_threads,
    validate_timeout,
)

BASE_DIR = Path(os.environ.get("DJPT_BASE_DIR", Path(__file__).resolve().parent)).resolve()


def resolve_config_file(base_dir: Optional[Path] = None) -> Path:
    env_path = os.environ.get("DJPT_CONFIG_FILE")
    if env_path:
        return Path(env_path).expanduser().resolve()

    root = Path(base_dir).expanduser().resolve() if base_dir is not None else BASE_DIR
    return (root / "config" / "ai_model_params.toml").resolve()


CONFIG_FILE = resolve_config_file(BASE_DIR)


class ConfigManager(_LibConfigManager):
    def __init__(self, config_path: Optional[Path] = None):
        super().__init__(config_path=config_path or CONFIG_FILE)


config_manager = ConfigManager()


def load_settings(config_path: Optional[Path] = None) -> Settings:
    if config_path is not None:
        return ConfigManager(config_path=config_path).load_settings()
    return config_manager.load_settings()


def save_settings(settings: Settings, config_path: Optional[Path] = None) -> bool:
    if config_path is not None:
        return ConfigManager(config_path=config_path).save_settings(settings)
    return _lib_save_settings(settings, config_path=config_manager.config_path)


def get_nested_setting(settings: Settings, path: str) -> Any:
    parts = path.split(".")
    if len(parts) != 2:
        raise ValueError(f"Invalid path format: {path}. Expected 'section.key'")

    section_name, key = parts
    if not hasattr(settings, section_name):
        raise ValueError(f"Unknown section: {section_name}")

    section_obj = getattr(settings, section_name)
    if not hasattr(section_obj, key):
        raise ValueError(f"Unknown key: {key} in section {section_name}")

    return getattr(section_obj, key)


def set_nested_setting(settings: Settings, path: str, value: Any) -> None:
    parts = path.split(".")
    if len(parts) != 2:
        raise ValueError(f"Invalid path format: {path}. Expected 'section.key'")

    section_name, key = parts
    if not hasattr(settings, section_name):
        raise ValueError(f"Unknown section: {section_name}")

    section_obj = getattr(settings, section_name)
    if not hasattr(section_obj, key):
        raise ValueError(f"Unknown key: {key} in section {section_name}")

    current = getattr(section_obj, key)
    field_def = section_obj.__class__.__dataclass_fields__[key]
    validator = field_def.metadata.get("validator")

    if isinstance(current, bool):
        value = str(value).lower() in ("1", "true", "yes", "on")
    elif isinstance(current, int):
        value = int(value)
    elif isinstance(current, float):
        value = float(value)

    if validator:
        value = validator(value)

    setattr(section_obj, key, value)


def export_all_env_vars(settings: Settings) -> Dict[str, str]:
    manager = ConfigManager(config_path=config_manager.config_path)
    manager._settings = settings
    return _lib_export_all_env_vars(settings)


__all__ = [
    "BASE_DIR",
    "CONFIG_FILE",
    "CAPABILITIES_FILE",
    "PROFILE_FILE",
    "General",
    "MLX",
    "TensorFlow",
    "Ollama",
    "Threads",
    "Jobs",
    "Optimization",
    "Learning",
    "Limits",
    "Trends",
    "Settings",
    "ConfigManager",
    "config_manager",
    "resolve_config_file",
    "load_settings",
    "save_settings",
    "get_nested_setting",
    "set_nested_setting",
    "export_all_env_vars",
    "validate_backend",
    "validate_threads",
    "validate_memory_fraction",
    "validate_positive_int",
    "validate_timeout",
    "LIB_BASE_DIR",
    "LIB_CONFIG_FILE",
]
