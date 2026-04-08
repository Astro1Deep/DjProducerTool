import sys
import os
import pytest
import shutil
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from checkpoint_state import main, df_summary

def test_df_summary_mocked(tmp_path):
    # Setup
    target = tmp_path
    
    with patch("subprocess.run") as mock_run:
        mock_run.return_value.stdout = "Filesystem Size Used Avail Use% Mounted on\n/dev/disk1s1 1T 500G 500G 50% /"
        
        result = df_summary([target])
        
        assert len(result) == 1
        assert "Filesystem" in result[0]
        mock_run.assert_called_once()

def test_main_checkpoint(tmp_path, capsys):
    # Setup
    base_dir = tmp_path / "lib"
    base_dir.mkdir()
    
    state_dir = base_dir / "_DJProducerTools"
    state_dir.mkdir()
    
    (state_dir / "reports").mkdir()
    (state_dir / "plans").mkdir()
    
    # Create dummy files to be copied
    (state_dir / "reports" / "hash_index.tsv").write_text("hash_index")
    (state_dir / "reports" / "general_hash_dupes_report.txt").write_text("report")
    (state_dir / "plans" / "general_hash_dupes_plan.tsv").write_text("plan")
    
    # Mock df_summary to avoid real df call and simplify output
    with patch("checkpoint_state.df_summary", return_value=["Mock DF Output"]):
        test_args = ["checkpoint_state.py", "--base", str(base_dir)]
        
        with patch.object(sys, 'argv', test_args):
            main()
    
    # Verify
    checkpoints_dir = state_dir / "checkpoints"
    assert checkpoints_dir.exists()
    
    # Should be one timestamped directory
    subdirs = list(checkpoints_dir.iterdir())
    assert len(subdirs) == 1
    chk_dir = subdirs[0]
    
    # Check copied files
    assert (chk_dir / "hash_index.tsv").exists()
    assert (chk_dir / "general_hash_dupes_report.txt").exists()
    assert (chk_dir / "general_hash_dupes_plan.tsv").exists()
    
    # Check log
    log_file = chk_dir / "checkpoint.log"
    assert log_file.exists()
    log_content = log_file.read_text()
    assert "Mock DF Output" in log_content
    assert "copied" in log_content

def test_main_missing_files(tmp_path, capsys):
    # Setup - don't create the files
    base_dir = tmp_path / "lib"
    base_dir.mkdir()
    state_dir = base_dir / "_DJProducerTools"
    state_dir.mkdir()
    
    with patch("checkpoint_state.df_summary", return_value=["Mock DF Output"]):
        test_args = ["checkpoint_state.py", "--base", str(base_dir)]
        
        with patch.object(sys, 'argv', test_args):
            main()
            
    captured = capsys.readouterr()
    assert "[CHECKPOINT] saved to" in captured.out
    
    # Log should not contain "copied" if no files existed
    # Wait, the script iterates list and checks `if candidate.exists()`.
    
    # Let's find the log file
    checkpoints_dir = state_dir / "checkpoints"
    chk_dir = list(checkpoints_dir.iterdir())[0]
    log_file = chk_dir / "checkpoint.log"
    log_content = log_file.read_text()
    
    assert "copied" not in log_content
