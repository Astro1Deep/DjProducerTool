from __future__ import annotations

import sys
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "config_schema.py"
ROOT_STR = str(ROOT)

if ROOT_STR in sys.path:
    sys.path.remove(ROOT_STR)
sys.path.insert(0, ROOT_STR)

spec = importlib.util.spec_from_file_location("djpt_root_config_schema", MODULE_PATH)
if spec is None or spec.loader is None:
    raise ImportError(f"unable to load spec for {MODULE_PATH}")

module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

for name in dir(module):
    if name.startswith("_"):
        continue
    globals()[name] = getattr(module, name)
