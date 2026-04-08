from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Dict, Tuple


DEPENDENCIES = {
    "audio": ["librosa"],
    "ml": ["tensorflow"],
    "core": ["joblib"],
}

PACKAGE_MAP = {
    "librosa": ("librosa", "librosa"),
    "tensorflow": ("tensorflow", "tensorflow"),
    "joblib": ("joblib", "joblib"),
}


class DependencyManager:
    def __init__(self, venv_path: Path | None = None):
        self.venv_path = Path(venv_path) if venv_path else None

    def _get_python_cmd(self) -> str:
        if self.venv_path:
            candidate = self.venv_path / "bin" / "python"
            if candidate.exists():
                return str(candidate)
        return "python3"

    def check_dependency(self, name: str) -> Tuple[bool, str]:
        if name not in PACKAGE_MAP:
            return False, "Unknown dependency"
        module_name, _ = PACKAGE_MAP[name]
        cmd = [
            self._get_python_cmd(),
            "-c",
            (
                "import importlib; "
                f"m=importlib.import_module('{module_name}'); "
                "print(getattr(m, '__version__', 'unknown'))"
            ),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            return True, result.stdout.strip() or "unknown"
        return False, result.stderr.strip() or "ImportError"

    def install_dependency(self, name: str) -> Tuple[bool, str]:
        if name not in PACKAGE_MAP:
            return False, "Unknown dependency"
        _, package_name = PACKAGE_MAP[name]
        cmd = [self._get_python_cmd(), "-m", "pip", "install", package_name]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            return True, "Installation successful"
        return False, f"Installation failed: {result.stderr.strip()}"

    def install_selective(self, categories: list[str]) -> bool:
        if input("Install selected dependencies? [y/N]: ").strip().lower() != "y":
            return False
        success = True
        for category in categories:
            for dep in DEPENDENCIES.get(category, []):
                ok, _ = self.install_dependency(dep)
                success = success and ok
        return success

    def run_doctor(self) -> Dict[str, dict]:
        python_result = subprocess.run(
            [self._get_python_cmd(), "--version"], capture_output=True, text=True
        )
        doctor = {
            "python": {
                "available": python_result.returncode == 0,
                "version": python_result.stdout.strip() or python_result.stderr.strip(),
            },
            "venv": {
                "configured": bool(self.venv_path),
                "path": str(self.venv_path) if self.venv_path else "",
            },
        }
        for deps in DEPENDENCIES.values():
            for dep in deps:
                available, info = self.check_dependency(dep)
                doctor[dep] = {"available": available, "version": info}
        return doctor

    def create_venv(self, venv_path: Path) -> bool:
        venv_path = Path(venv_path)
        venv_path.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            [sys.executable, "-m", "venv", str(venv_path)],
            capture_output=True,
            text=True,
        )
        return result.returncode == 0
