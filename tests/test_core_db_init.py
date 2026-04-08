import os
from pathlib import Path

import sys
import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_ROOT = ROOT / "scripts"
for p in (ROOT, SCRIPT_ROOT):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from core.config import Config  # noqa: E402
from core.db import init_db, db, Scan, FileIndex, GlobalHash  # noqa: E402


def test_init_db_uses_config_path_and_creates_tables(tmp_path):
    base = tmp_path / "proj"
    db_path = base / "state" / "db" / "djpt.sqlite"

    old_env = dict(os.environ)
    old_base = Config.BASE_DIR
    old_state = Config.STATE_DIR
    old_db = Config.DB_PATH
    old_scans = Config.SCANS_DIR
    old_models = Config.MODELS_DIR

    try:
        os.environ["DJPT_BASE_DIR"] = str(base)
        os.environ["DJPT_STATE_DIR"] = str(base / "state")
        os.environ["DJPT_DB_PATH"] = str(db_path)

        Config.BASE_DIR = base
        Config.STATE_DIR = base / "state"
        Config.DB_PATH = db_path
        Config.SCANS_DIR = base / "scans"
        Config.MODELS_DIR = base / "ai" / "models"

        connection = init_db()

        assert Path(connection.database) == db_path
        assert db_path.exists()

        tables = set(connection.get_tables())
        assert Scan._meta.table_name in tables
        assert FileIndex._meta.table_name in tables
        assert GlobalHash._meta.table_name in tables
    finally:
        db.close()
        os.environ.clear()
        os.environ.update(old_env)
        Config.BASE_DIR = old_base
        Config.STATE_DIR = old_state
        Config.DB_PATH = old_db
        Config.SCANS_DIR = old_scans
        Config.MODELS_DIR = old_models

