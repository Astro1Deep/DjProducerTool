import sys
import os
import json
import pytest
from pathlib import Path

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from smart_analyzer import analyze

def test_analyze_success(tmp_path):
    # Setup
    base_dir = tmp_path / "files"
    base_dir.mkdir()
    (base_dir / "file1.txt").touch()
    (base_dir / "file2.txt").touch()
    
    sub_dir = base_dir / "sub"
    sub_dir.mkdir()
    (sub_dir / "file3.txt").touch()
    
    output_file = tmp_path / "report.json"
    
    # Execute
    analyze(str(base_dir), str(output_file))
    
    # Verify
    assert output_file.exists()
    
    with open(output_file) as f:
        data = json.load(f)
    
    assert data["base_path"] == str(base_dir)
    assert data["files_count"] == 3
    assert data["analysis_type"] == "SMART_ANALYSIS"
    assert data["analysis_type_legacy"] == "SMART_ANALYSIS_LEGACY"
    assert "by_type" in data

def test_analyze_empty_dir(tmp_path):
    # Setup
    base_dir = tmp_path / "empty"
    base_dir.mkdir()
    output_file = tmp_path / "report.json"
    
    # Execute
    analyze(str(base_dir), str(output_file))
    
    # Verify
    with open(output_file) as f:
        data = json.load(f)
    
    assert data["files_count"] == 0

def test_analyze_invalid_path(tmp_path):
    # Setup
    base_dir = tmp_path / "non_existent"
    output_file = tmp_path / "report.json"
    
    # Execute
    # os.walk on non-existent path doesn't raise error, just yields nothing
    analyze(str(base_dir), str(output_file))
    
    # Verify
    with open(output_file) as f:
        data = json.load(f)
    
    assert data["files_count"] == 0
