#!/usr/bin/env python3
"""Manage DJPT Python virtual environment and base ML dependencies."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path


def check_internet() -> bool:
    print("📡 Verificando conectividad a Internet...")
    try:
        subprocess.check_call(
            ["curl", "-s", "--head", "https://www.google.com"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print("✅ Conexión confirmada.")
        return True
    except Exception:
        print("❌ Error: No se detecta conexión a Internet.")
        return False


def get_python_command() -> str:
    if shutil.which("python3.12"):
        return "python3.12"
    return "python3"


def create_venv(venv_path: Path) -> bool:
    python_cmd = get_python_command()
    print(f"📦 Creando entorno virtual en {venv_path} usando {python_cmd}...")
    try:
        subprocess.check_call([python_cmd, "-m", "venv", str(venv_path)])
        return True
    except subprocess.CalledProcessError as exc:
        print(f"❌ Error al crear venv: {exc}")
        return False


def install_libs(venv_path: Path) -> bool:
    pip_bin = venv_path / "bin" / "pip"
    if not pip_bin.exists():
        print(f"❌ Error: pip no encontrado en {pip_bin}")
        return False

    pkgs = [
        "numpy",
        "pandas",
        "soundfile",
        "librosa",
        "pyloudnorm",
        "pyserial",
        "python-osc",
        "onnxruntime",
        "tensorflow-hub",
    ]

    system = platform.system()
    machine = platform.machine()
    if system == "Darwin" and machine == "arm64":
        print("🍎 Detectado Apple Silicon. Usando tensorflow-macos y tensorflow-metal.")
        pkgs.extend(["tensorflow-macos", "tensorflow-metal"])
    else:
        pkgs.append("tensorflow")

    print(f"⬇️  Instalando librerías: {', '.join(pkgs)}")
    try:
        subprocess.check_call([str(pip_bin), "install", "--upgrade", "pip"])
        subprocess.check_call([str(pip_bin), "install", *pkgs])
        print("✅ Librerías instaladas correctamente.")
        return True
    except subprocess.CalledProcessError as exc:
        print(f"❌ Error instalando librerías: {exc}")
        return False


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Manage DJPT venv and install base AI dependencies."
    )
    parser.add_argument("venv_path", nargs="?", help="Virtualenv path (legacy mode).")
    parser.add_argument(
        "action",
        nargs="?",
        choices=["create", "install", "check"],
        default="install",
        help="Action to execute (legacy mode).",
    )
    parser.add_argument("--venv", dest="venv_opt", help="Virtualenv path.")
    parser.add_argument(
        "--action",
        dest="action_opt",
        choices=["create", "install", "check"],
        help="Action to execute.",
    )
    args = parser.parse_args(argv)

    # Compatibility:
    # - old style: venv_manager.py <venv_path> [action]
    # - new style used by shell scripts: venv_manager.py --venv <path> [--action install]
    if args.venv_opt:
        args.venv_path = args.venv_opt
    if args.action_opt:
        args.action = args.action_opt

    if not args.venv_path:
        parser.error("Debes indicar la ruta del venv (posicional o --venv).")
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    venv_path = Path(os.path.expanduser(args.venv_path))
    action = args.action

    if action == "check":
        if (venv_path / "bin" / "python3").exists():
            print("✅ Entorno válido.")
            return 0
        print("⚠️  Entorno no encontrado.")
        return 1

    if not check_internet():
        return 1

    if not venv_path.exists() or action == "create":
        if not create_venv(venv_path):
            return 1

    if action == "install":
        return 0 if install_libs(venv_path) else 1

    # Defensive fallback; argparse should prevent this path.
    print(f"❌ Acción no soportada: {action}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
