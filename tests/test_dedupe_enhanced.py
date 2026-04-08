#!/usr/bin/env python3
"""Test enhanced dedupe functionality with existence validation and stale path detection."""

import os
import tempfile
from pathlib import Path
import pytest
import sys
import time

# Add scripts to path for testing
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))

from core.dedupe import Deduper
from core.db import db, FileIndex, Scan
from core.config import Config


@pytest.fixture
def temp_dedupe_env(tmp_path):
    """Create temporary environment for dedupe testing."""
    # Setup test environment
    os.environ["BASE_PATH"] = str(tmp_path)
    os.environ["STATE_DIR"] = str(tmp_path / "state")
    
    # Create test files
    test_dir = tmp_path / "test_files"
    test_dir.mkdir()
    
    # Create duplicate files with same content
    file1 = test_dir / "file1.mp3"
    file2 = test_dir / "subdir" / "file2.mp3"
    file2.parent.mkdir()
    
    content = b"test audio content"
    file1.write_bytes(content)
    file2.write_bytes(content)
    
    # Create a file that will be "missing" (delete after DB scan)
    missing_file = test_dir / "missing.mp3"
    missing_file.write_bytes(content)
    
    # Initialize database and scan files
    Config.STATE_DIR = tmp_path / "state"
    Config.STATE_DIR.mkdir(parents=True, exist_ok=True)
    
    db.init(str(Config.STATE_DIR / "djpt.db"))
    db.create_tables([Scan, FileIndex])
    
    # Create a scan record for the files
    scan = Scan.create(
        id="test_scan_123",
        root_path=str(tmp_path),
        file_count=3
    )
    
    # Add files to database
    for file_path in [file1, file2, missing_file]:
        stat = file_path.stat()
        FileIndex.create(
            path=str(file_path.relative_to(tmp_path)),  # unique path field
            scan_id=scan.id,
            full_path=str(file_path),
            rel_path=str(file_path.relative_to(tmp_path)),
            size_bytes=stat.st_size,
            mtime=stat.st_mtime,
            sha256="test_hash_123",
            file_type="audio",
        )
    
    # Delete the missing file to simulate stale/missing paths
    missing_file.unlink()
    
    yield {
        "tmp_path": tmp_path,
        "test_dir": test_dir,
        "file1": file1,
        "file2": file2,
        "missing_file": missing_file,
        "deduper": Deduper()
    }
    
    # Cleanup
    db.close()


def test_generate_plan_with_existence_validation(temp_dedupe_env):
    """Test plan generation validates file existence and detects stale paths."""
    deduper = temp_dedupe_env["deduper"]
    
    # Generate plan
    plan_path, count, stats = deduper.generate_plan()
    
    # Should find 1 duplicate group (2 existing files, 1 missing)
    assert count == 1
    assert stats["missing_files"] == 1
    assert plan_path.exists()
    
    # Check plan content
    plan_content = plan_path.read_text()
    assert "KEEP" in plan_content
    assert "QUARANTINE" in plan_content
    assert "True" in plan_content  # exists column
    
    # Should have new columns
    header = plan_content.split('\\n')[0]
    assert "mtime" in header
    assert "exists" in header


def test_apply_plan_with_missing_files(temp_dedupe_env):
    """Test apply plan handles missing files gracefully."""
    deduper = temp_dedupe_env["deduper"]
    
    # Generate plan first
    plan_path, count, stats = deduper.generate_plan()
    
    # Missing files should be filtered during plan generation
    assert stats["missing_files"] >= 1
    
    # Apply plan in dry-run mode
    result = deduper.apply_plan(plan_path, dry_run=True)
    
    assert result["moved"] == 0  # dry-run
    assert result["planned"] >= 1  # should plan to move at least one file
    assert "skipped_missing" in result


def test_stale_path_detection(temp_dedupe_env):
    """Test detection of stale paths where mtime doesn't match."""
    deduper = temp_dedupe_env["deduper"]
    file1 = temp_dedupe_env["file1"]
    
    # Modify file mtime in DB to simulate stale data
    file_record = FileIndex.get(FileIndex.full_path == str(file1))
    file_record.mtime = 1234567890  # Old timestamp
    file_record.save()
    
    # Generate plan should detect stale path
    plan_path, count, stats = deduper.generate_plan()
    
    assert stats["stale_paths"] >= 1


def test_plan_with_all_missing_files(tmp_path):
    """Test plan generation when all files are missing."""
    # Setup environment with no files
    os.environ["BASE_PATH"] = str(tmp_path)
    os.environ["STATE_DIR"] = str(tmp_path / "state")
    Config.STATE_DIR = tmp_path / "state"
    Config.STATE_DIR.mkdir(parents=True, exist_ok=True)
    
    db.init(str(Config.STATE_DIR / "djpt.db"))
    db.create_tables([Scan, FileIndex])
    
    deduper = Deduper()
    
    # Generate plan with no files
    plan_path, count, stats = deduper.generate_plan()
    
    assert count == 0
    assert stats["missing_files"] == 0
    assert plan_path.exists()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
