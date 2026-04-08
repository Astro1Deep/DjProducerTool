import sys
import os
import pytest
import hashlib
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from hash_root import sha256_file, main

def test_sha256_file(tmp_path):
    # Setup
    test_file = tmp_path / "test_file.txt"
    content = b"Hello World"
    test_file.write_bytes(content)
    
    # Execute
    digest = sha256_file(str(test_file))
    
    # Verify
    expected = hashlib.sha256(content).hexdigest()
    assert digest == expected

def test_main_hash_execution(tmp_path, capsys):
    # Setup
    root_dir = tmp_path / "root"
    root_dir.mkdir()
    (root_dir / "file1.txt").write_text("content1")
    
    external_file = tmp_path / "hashes.tsv"
    
    # Mock sys.argv
    test_args = ["hash_root.py", "--root", str(root_dir), "--external-file", str(external_file)]
    
    with patch.object(sys, 'argv', test_args):
        with pytest.raises(SystemExit) as excinfo:
            main()
        
        # Verify exit code
        assert excinfo.value.code == 0
    
    # Verify output file
    assert external_file.exists()
    content = external_file.read_text()
    assert "file1.txt" in content
    # SHA256 of "content1"
    expected_hash = hashlib.sha256(b"content1").hexdigest()
    assert expected_hash in content
    
    captured = capsys.readouterr()
    assert "[INFO] Root" in captured.out

def test_main_limit(tmp_path):
    # Setup
    root_dir = tmp_path / "root"
    root_dir.mkdir()
    (root_dir / "file1.txt").write_text("content1")
    (root_dir / "file2.txt").write_text("content2")
    
    external_file = tmp_path / "hashes.tsv"
    
    # Mock sys.argv with limit 1
    test_args = ["hash_root.py", "--root", str(root_dir), "--external-file", str(external_file), "--limit", "1"]
    
    with patch.object(sys, 'argv', test_args):
        with pytest.raises(SystemExit) as excinfo:
            main()
        
        # Verify exit code 2 (limit reached)
        assert excinfo.value.code == 2
    
    # Verify only 1 file hashed (or checks limit after hashing)
    content = external_file.read_text()
    lines = content.strip().split('\n')
    assert len(lines) == 1

def test_main_existing_hash(tmp_path, capsys):
    # Setup
    root_dir = tmp_path / "root"
    root_dir.mkdir()
    file_path = root_dir / "file1.txt"
    file_path.write_text("content1")
    
    external_file = tmp_path / "hashes.tsv"
    # Pre-populate hash
    # Note: hash_root checks if PATH is in existing, not hash
    external_file.write_text(f"somehash\t{file_path}\n")
    
    test_args = ["hash_root.py", "--root", str(root_dir), "--external-file", str(external_file)]
    
    with patch.object(sys, 'argv', test_args):
        with pytest.raises(SystemExit) as excinfo:
            main()
        
        assert excinfo.value.code == 0
    
    captured = capsys.readouterr()
    assert "No new files hashed" in captured.out

def test_main_invalid_root(tmp_path, capsys):
    test_args = ["hash_root.py", "--root", str(tmp_path / "non_existent")]
    
    with patch.object(sys, 'argv', test_args):
        with pytest.raises(SystemExit) as excinfo:
            main()
        
        assert excinfo.value.code == 1
    
    captured = capsys.readouterr()
    assert "[ERROR]" in captured.err
