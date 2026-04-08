#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil
import platform
from pathlib import Path

def check_internet():
    print("📡 Verificando conectividad a Internet...")
    try:
        subprocess.check_call(["curl", "-s", "--head", "https://www.google.com"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("✅ Conexión confirmada.")
        return True
    except:
        print("❌ Error: No se detecta conexión a Internet.")
        return False

def get_python_command():
    # Prefer Python 3.12, fall back to python3
    if shutil.which("python3.12"):
        return "python3.12"
    return "python3"

def create_venv(venv_path):
    python_cmd = get_python_command()
    print(f"📦 Creando entorno virtual en {venv_path} usando {python_cmd}...")
    
    try:
        subprocess.check_call([python_cmd, "-m", "venv", venv_path])
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error al crear venv: {e}")
        return False

def install_libs(venv_path):
    pip_bin = os.path.join(venv_path, "bin", "pip")
    if not os.path.exists(pip_bin):
        print(f"❌ Error: pip no encontrado en {pip_bin}")
        return False

    # Base packages
    pkgs = [
        "numpy", "pandas", "soundfile", "librosa", 
        "pyloudnorm", "pyserial", "python-osc", 
        "onnxruntime", "tensorflow-hub"
    ]

    # Platform specific adjustments
    system = platform.system()
    machine = platform.machine()
    
    if system == "Darwin" and machine == "arm64":
        print("🍎 Detectado Apple Silicon. Usando tensorflow-macos y tensorflow-metal.")
        pkgs.extend(["tensorflow-macos", "tensorflow-metal"])
    else:
        pkgs.append("tensorflow")

    print(f"⬇️  Instalando librerías: {', '.join(pkgs)}")
    
    try:
        subprocess.check_call([pip_bin, "install", "--upgrade", "pip"])
        subprocess.check_call([pip_bin, "install"] + pkgs)
        print("✅ Librerías instaladas correctamente.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error instalando librerías: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Uso: venv_manager.py <venv_path> [create|install|check]")
        sys.exit(1)

    venv_path = sys.argv[1]
    action = sys.argv[2] if len(sys.argv) > 2 else "install"

    if action == "check":
        if os.path.exists(os.path.join(venv_path, "bin", "python3")):
            print("✅ Entorno válido.")
            sys.exit(0)
        else:
            print("⚠️  Entorno no encontrado.")
            sys.exit(1)

    if action in ["create", "install"]:
        if not check_internet():
            sys.exit(1)

        if not os.path.exists(venv_path) or action == "create":
            if not create_venv(venv_path):
                sys.exit(1)
        
        if action == "install":
            if not install_libs(venv_path):
                sys.exit(1)

if __name__ == "__main__":
    main()