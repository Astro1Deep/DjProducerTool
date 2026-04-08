import sys
import os
import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bpm_analyzer import analyze

def test_analyze_valid_input(tmp_path):
    # Setup
    base_dir = tmp_path / "audio_files"
    base_dir.mkdir()
    output_file = tmp_path / "bpm_report.txt"
    
    # Execute
    analyze(str(base_dir), str(output_file))
    
    # Verify
    assert output_file.exists()
    content = output_file.read_text()
    assert "File\tBPM" in content

def test_analyze_invalid_base_directory(tmp_path):
    # Setup
    base_dir = tmp_path / "non_existent_dir"
    output_file = tmp_path / "bpm_report.txt"
    
    # Execute & Verify
    with pytest.raises(SystemExit) as excinfo:
        analyze(str(base_dir), str(output_file))
    
    assert excinfo.value.code == 1

def test_analyze_base_is_file_not_dir(tmp_path):
    # Setup
    base_file = tmp_path / "some_file.txt"
    base_file.touch()
    output_file = tmp_path / "bpm_report.txt"
    
    # Execute & Verify
    with pytest.raises(SystemExit) as excinfo:
        analyze(str(base_file), str(output_file))
    
    assert excinfo.value.code == 1

def test_analyze_output_creation_failure(tmp_path, capsys):
    # Setup
    base_dir = tmp_path / "audio_files"
    base_dir.mkdir()
    # Use a directory as output path to force IOError/IsADirectoryError when opening for write
    output_file = tmp_path / "output_dir"
    output_file.mkdir()
    
    # Execute & Verify
    with pytest.raises(SystemExit) as excinfo:
        analyze(str(base_dir), str(output_file))
    
    assert excinfo.value.code == 1
    
    # Check stderr for error message
    captured = capsys.readouterr()
    assert "Error writing to" in captured.err
