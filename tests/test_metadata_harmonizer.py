import sys
import os
import pytest
from pathlib import Path

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from metadata_harmonizer import harmonize

def test_harmonize_execution(tmp_path):
    # Setup
    output_file = tmp_path / "harmonization_plan.txt"
    lang = "es"
    
    # Execute
    harmonize(str(output_file), lang)
    
    # Verify
    assert output_file.exists()
    content = output_file.read_text()
    assert "Field\tIssue\tAction" in content
