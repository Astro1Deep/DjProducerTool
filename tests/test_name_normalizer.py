import sys
import os
import pytest
from pathlib import Path

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from name_normalizer import normalize_filename, normalize

@pytest.mark.parametrize("input_name, expected", [
    ("test file.mp3", "test file.mp3"), # Spaces preserved
    # The code keeps spaces unless they are leading/trailing (stripped via .strip('._-') which doesn't strip spaces.
    # But it keeps letters, numbers, dots, hyphens, underscores, and spaces.
    # It DOES NOT seem to strip spaces or replace them with underscores in the `replacements` map or in the regex.
    # normalized = ''.join(char for char in normalized if not unicodedata.combining(char))
    # Then replacements...
    # It DOES NOT seem to strip spaces or replace them with underscores in the `replacements` map or the regex.
    # Let's verify this assumption with the test.
    ("My Song!.mp3", "My Song!.mp3"), # Exclamation mark is not in replacement list?
    ("Track/1.mp3", "Track_1.mp3"),
    ("Bad:Name.wav", "Bad_Name.wav"),
    ("café.mp3", "cafe.mp3"), # Accent removal
    ("Schön.mp3", "Schon.mp3"), # Umlaut removal
    ("..test--file__.mp3", "test_file_mp3"), # Leading/trailing and consecutive. Note: _. becomes _ so extension dot is lost if preceded by _
    ("", "unnamed_file"),
    ("   ", "unnamed_file"),
    ("file\nname.mp3", "file_name.mp3"),
])
def test_normalize_filename(input_name, expected):
    # Note: Based on reading the code, spaces seem to be preserved unless they are leading/trailing (stripped via .strip('._-') which doesn't strip spaces... wait).
    # .strip('._-') strips those specific chars.
    # But unicodedata.category(char).startswith('C') might remove some control chars.

    # So "My Song!" should stay "My Song!" unless '!' is considered combining or control (it's not).
    # normalized = ''.join(char for char in normalized if not unicodedata.combining(char))
    # It keeps everything else unless replaced or control char.
    # So "My Song!" should stay "My Song!" unless '!' is considered combining or control (it's not).

    assert normalize_filename(input_name) == expected

def test_normalize_plan_creation(tmp_path):
    # Setup
    base_dir = tmp_path / "files"
    base_dir.mkdir()

    # Create files
    (base_dir / "clean.mp3").touch()
    (base_dir / "bad:name.mp3").touch()

    output_file = tmp_path / "rename_plan.txt"

    # Execute
    normalize(str(base_dir), str(output_file))

    # Verify
    content = output_file.read_text()
    assert "clean.mp3" not in content # Should not be in plan if no change needed?
    # Logic: if new_name != file: f.write(...)

    assert "bad:name.mp3" in content
    assert "bad_name.mp3" in content
    assert "RENAME" in content
