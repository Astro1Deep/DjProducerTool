import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANONICAL_CONFIG = ROOT / "core" / "config.py"

spec = importlib.util.spec_from_file_location("djpt_root_core_config", CANONICAL_CONFIG)
if spec is None or spec.loader is None:
    raise ImportError(f"Unable to load canonical config module: {CANONICAL_CONFIG}")
_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(_module)

Config = _module.Config
_default_base_dir = _module._default_base_dir

__all__ = ["Config", "_default_base_dir"]
