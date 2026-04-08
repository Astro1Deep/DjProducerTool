import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANONICAL_DEDUPE = ROOT / "core" / "dedupe.py"

spec = importlib.util.spec_from_file_location("djpt_root_core_dedupe", CANONICAL_DEDUPE)
if spec is None or spec.loader is None:
    raise ImportError(f"Unable to load canonical dedupe module: {CANONICAL_DEDUPE}")
_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(_module)

Deduper = _module.Deduper

__all__ = ["Deduper"]
