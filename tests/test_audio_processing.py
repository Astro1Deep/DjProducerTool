import sys
import os
import pytest
from pathlib import Path

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from audio_processing import lufs, cues

def test_lufs_execution(tmp_path):
    # Setup
    base_dir = tmp_path / "audio_files"
    base_dir.mkdir()
    output_file = tmp_path / "lufs_report.txt"
    target_lufs = "-14"
    
    # Execute
    lufs(str(base_dir), str(output_file), target_lufs)
    
    # Verify
    assert output_file.exists()
    content = output_file.read_text()
    assert "File\tLUFS" in content

def test_cues_execution(tmp_path):
    # Setup
    base_dir = tmp_path / "audio_files"
    base_dir.mkdir()
    output_file = tmp_path / "cues_report.txt"
    
    # Execute
    cues(str(base_dir), str(output_file))
    
    # Verify
    assert output_file.exists()
    content = output_file.read_text()
    assert "File\tCue" in content
