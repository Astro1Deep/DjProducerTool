import sys
import os
import pytest
from pathlib import Path

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dj_lib_finder import find_libs

def test_find_libs_success(tmp_path, capsys):
    # Setup
    base_dir = tmp_path / "dj_library"
    base_dir.mkdir()
    
    # Create target directories
    (base_dir / "_Serato_").mkdir()
    (base_dir / "Traktor").mkdir()
    (base_dir / "Rekordbox_Data").mkdir() # Should match "Rekordbox"
    (base_dir / "Ableton Project").mkdir() # Should match "Ableton"
    (base_dir / "OtherFolder").mkdir() # Should NOT match
    
    # Execute
    find_libs(str(base_dir))
    
    # Verify
    captured = capsys.readouterr()
    output = captured.out
    
    assert f"Found: {base_dir / '_Serato_'}" in output
    assert f"Found: {base_dir / 'Traktor'}" in output
    assert f"Found: {base_dir / 'Rekordbox_Data'}" in output
    assert f"Found: {base_dir / 'Ableton Project'}" in output
    assert "OtherFolder" not in output

def test_find_libs_nested(tmp_path, capsys):
    # Setup
    base_dir = tmp_path / "nested_libs"
    base_dir.mkdir()
    
    nested_dir = base_dir / "subfolder"
    nested_dir.mkdir()
    
    (nested_dir / "_Serato_").mkdir()
    
    # Execute
    find_libs(str(base_dir))
    
    # Verify
    captured = capsys.readouterr()
    output = captured.out
    
    assert f"Found: {nested_dir / '_Serato_'}" in output

def test_find_libs_no_matches(tmp_path, capsys):
    # Setup
    base_dir = tmp_path / "empty_lib"
    base_dir.mkdir()
    
    (base_dir / "RandomFolder").mkdir()
    
    # Execute
    find_libs(str(base_dir))
    
    # Verify
    captured = capsys.readouterr()
    output = captured.out
    assert "Searching DJ libs" in output
    assert "Found:" not in output
