import sys
import subprocess
import pytest
from unittest.mock import MagicMock, patch, call
from pathlib import Path
from dependency_manager import DependencyManager, DEPENDENCIES

@pytest.fixture
def mock_subprocess_run():
    with patch("subprocess.run") as mock:
        yield mock

@pytest.fixture
def manager():
    return DependencyManager()

def test_get_python_cmd_default(manager):
    assert manager._get_python_cmd() == "python3"

def test_get_python_cmd_venv(tmp_path):
    venv_path = tmp_path / "venv"
    (venv_path / "bin").mkdir(parents=True)
    (venv_path / "bin" / "python").touch()
    
    manager = DependencyManager(venv_path=venv_path)
    assert manager._get_python_cmd() == str(venv_path / "bin" / "python")

def test_check_dependency_success(manager, mock_subprocess_run):
    mock_subprocess_run.return_value.returncode = 0
    mock_subprocess_run.return_value.stdout = "1.0.0"
    
    available, version = manager.check_dependency("librosa")
    
    assert available is True
    assert version == "1.0.0"
    mock_subprocess_run.assert_called_once()

def test_check_dependency_failure(manager, mock_subprocess_run):
    mock_subprocess_run.return_value.returncode = 1
    mock_subprocess_run.return_value.stderr = "ImportError"
    
    available, error = manager.check_dependency("librosa")
    
    assert available is False
    assert error == "ImportError"

def test_check_dependency_unknown(manager):
    available, error = manager.check_dependency("unknown_dep")
    assert available is False
    assert error == "Unknown dependency"

def test_install_dependency_success(manager, mock_subprocess_run):
    mock_subprocess_run.return_value.returncode = 0
    
    success, msg = manager.install_dependency("librosa")
    
    assert success is True
    assert msg == "Installation successful"
    mock_subprocess_run.assert_called()

def test_install_dependency_failure(manager, mock_subprocess_run):
    mock_subprocess_run.return_value.returncode = 1
    mock_subprocess_run.return_value.stderr = "Pip error"
    
    success, msg = manager.install_dependency("librosa")
    
    assert success is False
    assert "Installation failed" in msg

@patch("builtins.input", return_value="y")
def test_install_selective_success(mock_input, manager, mock_subprocess_run):
    mock_subprocess_run.return_value.returncode = 0
    
    # Mock check_dependency to always return False so it tries to install?
    # install_selective calls install_dependency directly for the set.
    
    # We only test one category to avoid many calls
    success = manager.install_selective(["audio"])
    
    assert success is True
    # "audio" category only has "librosa"
    mock_subprocess_run.assert_called() 

@patch("builtins.input", return_value="n")
def test_install_selective_cancel(mock_input, manager, mock_subprocess_run):
    success = manager.install_selective(["audio"])
    assert success is False
    mock_subprocess_run.assert_not_called()

def test_run_doctor(manager, mock_subprocess_run):
    # Setup mock for python version check
    mock_subprocess_run.return_value.returncode = 0
    mock_subprocess_run.return_value.stdout = "3.10.0"
    
    results = manager.run_doctor()
    
    assert "python" in results
    assert results["python"]["version"] == "3.10.0"
    assert "venv" in results
    assert "librosa" in results

def test_create_venv(manager, mock_subprocess_run, tmp_path):
    mock_subprocess_run.return_value.returncode = 0
    venv_path = tmp_path / "new_venv"
    
    success = manager.create_venv(venv_path)
    
    assert success is True
    assert venv_path.exists()
    mock_subprocess_run.assert_called()
