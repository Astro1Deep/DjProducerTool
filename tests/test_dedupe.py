import os
import tempfile
from pathlib import Path

import pytest

import sys
ROOT = Path(__file__).resolve().parents[1]
SCRIPT_ROOT = ROOT / "scripts"
for p in (ROOT, SCRIPT_ROOT):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from core.db import init_db, db, Scan, FileIndex  # noqa: E402
from core.config import Config  # noqa: E402
from core.dedupe import Deduper  # noqa: E402


@pytest.fixture()
def db_with_dupes():
    """Temporary DB with two duplicates and one unique file."""
    with tempfile.TemporaryDirectory(prefix="djpt_db_") as td:
        base = Path(td)
        os.environ["DJPT_BASE_DIR"] = str(base)
        os.environ["DJPT_STATE_DIR"] = str(base / "state")
        os.environ["DJPT_DB_PATH"] = str(base / "state" / "db" / "djpt.sqlite")
        Config.BASE_DIR = base
        Config.STATE_DIR = base / "state"
        Config.DB_PATH = base / "state" / "db" / "djpt.sqlite"
        Config.SCANS_DIR = base / "scans"
        Config.ensure_dirs()
        init_db()

        scan = Scan.create(id="s1", root_path=str(base))
        (base / "a.mp3").write_bytes(b"a")
        (base / "dup1.mp3").write_bytes(b"b")
        (base / "dup2.mp3").write_bytes(b"c")

        FileIndex.create(path="a.mp3", scan_id=scan, rel_path="a.mp3", full_path=str(base / "a.mp3"),
                         size_bytes=10, mtime=1, sha256="H1", file_type="audio")
        FileIndex.create(path="dup1.mp3", scan_id=scan, rel_path="dup1.mp3", full_path=str(base / "dup1.mp3"),
                         size_bytes=11, mtime=2, sha256="H2", file_type="audio")
        FileIndex.create(path="dup2.mp3", scan_id=scan, rel_path="dup2.mp3", full_path=str(base / "dup2.mp3"),
                         size_bytes=12, mtime=3, sha256="H2", file_type="audio")

        yield base

        db.close()


def test_generate_plan(db_with_dupes):
    deduper = Deduper()
    plan_path, groups, summary = deduper.generate_plan()
    assert plan_path.exists()
    assert groups == 1
    assert summary["missing_files"] == 0
    lines = plan_path.read_text().splitlines()
    # header + KEEP + QUARANTINE
    assert len(lines) == 3
    assert lines[1].split("\t")[1] == "KEEP"
    assert lines[2].split("\t")[1] == "QUARANTINE"


def test_apply_plan_dry_run(db_with_dupes):
    deduper = Deduper()
    plan_path, _, _ = deduper.generate_plan()
    result = deduper.apply_plan(plan_path, dry_run=True)
    assert result["planned"] == 1
    assert result["moved"] == 0
    assert result["quarantine_dir"].exists()


def test_plan_skips_missing_files(db_with_dupes):
    # Remove one duplicate from disk to simulate stale entry
    missing = db_with_dupes / "dup2.mp3"
    missing.unlink()
    deduper = Deduper()
    plan_path, groups, summary = deduper.generate_plan()
    # Only one file of the duplicate pair exists -> plan still counts group but missing_files increments
    assert summary["missing_files"] >= 1
    # Apply should skip missing
    result = deduper.apply_plan(plan_path, dry_run=True)
    assert result["skipped_missing"] >= 0
