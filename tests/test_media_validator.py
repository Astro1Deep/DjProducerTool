import sys
import os
import pytest
import subprocess
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from media_validator import validate

def test_validate_valid_file(tmp_path):
    # Setup
    base_dir = tmp_path / "media"
    base_dir.mkdir()
    (base_dir / "valid.mp3").touch()
    
    output_file = tmp_path / "report.txt"
    
    # Mock subprocess.run to succeed
    with patch("subprocess.run") as mock_run:
        mock_run.return_value.returncode = 0
        
        # Execute
        validate(str(base_dir), str(output_file))
        
        # Verify
        mock_run.assert_called()
        # Report should be empty if no corrupt files
        assert output_file.exists()
        assert output_file.read_text() == ""

def test_validate_corrupt_file(tmp_path, capsys):
    # Setup
    base_dir = tmp_path / "media"
    base_dir.mkdir()
    (base_dir / "corrupt.mp3").touch()
    
    output_file = tmp_path / "report.txt"
    
    # Mock subprocess.run to raise CalledProcessError
    with patch("subprocess.run", side_effect=subprocess.CalledProcessError(1, ["ffprobe"])):
        
        # Execute
        validate(str(base_dir), str(output_file))
        
        # Verify
        captured = capsys.readouterr()
        assert "Corrupt:" in captured.out
        
        content = output_file.read_text()
        assert "corrupt.mp3\tCORRUPT" in content

def test_validate_ffprobe_missing(tmp_path, capsys):
    # Setup
    base_dir = tmp_path / "media"
    base_dir.mkdir()
    (base_dir / "file.mp3").touch()
    
    output_file = tmp_path / "report.txt"
    
    # Mock subprocess.run to raise FileNotFoundError (command not found)
    with patch("subprocess.run", side_effect=FileNotFoundError):
        
        # Execute
        validate(str(base_dir), str(output_file))
        
        # Verify
        captured = capsys.readouterr()
        assert "Corrupt:" in captured.out # The code treats FileNotFoundError as corruption indicator in current logic
        
        content = output_file.read_text()
        assert "file.mp3\tCORRUPT" in content
