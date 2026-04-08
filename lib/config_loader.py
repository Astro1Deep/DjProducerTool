from __future__ import annotations

import importlib.util
from pathlib import Path


_ROOT_MODULE = Path(__file__).resolve().parents[1] / "config_loader.py"
_SPEC = importlib.util.spec_from_file_location("djpt_root_config_loader", _ROOT_MODULE)
if _SPEC is None or _SPEC.loader is None:
    raise ImportError(f"Cannot load config_loader from {_ROOT_MODULE}")
_MODULE = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_MODULE)

ConfigLoader = _MODULE.ConfigLoader
AgentConfig = _MODULE.AgentConfig
AgentMode = _MODULE.AgentMode
SafetyConfig = _MODULE.SafetyConfig
PlatformConfig = _MODULE.PlatformConfig
AIConfig = _MODULE.AIConfig
MetricsConfig = _MODULE.MetricsConfig
LoggingConfig = _MODULE.LoggingConfig

__all__ = [
    "ConfigLoader",
    "AgentConfig",
    "AgentMode",
    "SafetyConfig",
    "PlatformConfig",
    "AIConfig",
    "MetricsConfig",
    "LoggingConfig",
]
