import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANONICAL_DB = ROOT / "core" / "db.py"

spec = importlib.util.spec_from_file_location("djpt_root_core_db", CANONICAL_DB)
if spec is None or spec.loader is None:
    raise ImportError(f"Unable to load canonical db module: {CANONICAL_DB}")
_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(_module)

BaseModel = _module.BaseModel
Scan = _module.Scan
FileIndex = _module.FileIndex
GlobalHash = _module.GlobalHash
db = _module.db
init_db = _module.init_db

__all__ = ["BaseModel", "Scan", "FileIndex", "GlobalHash", "db", "init_db"]
