import os
import json
import shutil
import tempfile
from pathlib import Path

import pytest

# Adjust import path to use local core modules
import sys
ROOT = Path(__file__).resolve().parents[1]
SCRIPT_ROOT = ROOT / "scripts"
for p in (ROOT, SCRIPT_ROOT):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from core.scanner import Scanner  # noqa: E402
from core.config import Config  # noqa: E402


@pytest.fixture()
def tmp_base():
    """Create an isolated BASE_DIR with sample files."""
    with tempfile.TemporaryDirectory(prefix="djpt_scan_") as td:
        base = Path(td)
        (base / "music").mkdir()
        (base / "music" / "a.mp3").write_bytes(b"a" * 10)
        (base / "music" / "b.wav").write_bytes(b"b" * 20)
        (base / "video").mkdir()
        (base / "video" / "c.mp4").write_bytes(b"c" * 5)
        os.environ["DJPT_BASE_DIR"] = str(base)
        os.environ["DJPT_SCANS_DIR"] = str(base / "scans")
        Config.BASE_DIR = base
        Config.SCANS_DIR = base / "scans"
        Config.STATE_DIR = base / "state"
        Config.ensure_dirs()
        yield base


def test_scanner_quick(tmp_base):
    scan = Scanner(tmp_base)
    out = scan.run(quick=True, parallel=False)
    csv_path = out / "files_index.csv"
    manifest = json.loads((out / "manifest.json").read_text())
    assert csv_path.exists()
    rows = csv_path.read_text().splitlines()
    # header + 3 files
    assert len(rows) == 4
    # quick => sha256 empty
    assert rows[1].split(",")[-2] == ""
    assert manifest["file_count"] == 3
    assert manifest["parallel"] is False


def test_scanner_full_hash(tmp_base):
    scan = Scanner(tmp_base)
    out = scan.run(quick=False, parallel=False)
    csv_path = out / "files_index.csv"
    rows = csv_path.read_text().splitlines()
    # hashes present (not empty string)
    assert rows[1].split(",")[-2] != ""


def test_scanner_blocks_outside_base(tmp_base):
    outside = tmp_base.parent
    os.environ.pop("DJPT_ALLOW_OUTSIDE", None)
    with pytest.raises(ValueError):
        Scanner(outside)


def test_scanner_allows_outside_with_env(tmp_base):
    outside = tmp_base.parent
    os.environ["DJPT_ALLOW_OUTSIDE"] = "1"
    scan = Scanner(outside)
    assert scan is not None
