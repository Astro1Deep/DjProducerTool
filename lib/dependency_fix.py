#!/usr/bin/env python3
"""
DJProducerTools - Dependency Fix & Repair Script
Resuelve problemas de instalación y configura el entorno correctamente.
"""

import os
import subprocess
import sys
from pathlib import Path


def print_banner():
    """Print repair banner."""
    print("""
🔧 DJProducerTools - Dependency Repair & Fix
==========================================
🚀 Resolución automática de problemas de instalación
🔍 Diagnóstico y reparación del entorno
📊 Verificación completa del sistema
""")


def check_environment():
    """Check current environment status."""
    print("🔍 Verificando entorno actual...")

    # Check if in virtual environment
    in_venv = hasattr(sys, "real_prefix") or (hasattr(sys, "base_prefix") and sys.base_prefix != sys.prefix)

    if in_venv:
        print(f"✅ Entorno virtual detectado: {sys.prefix}")
        return True
    else:
        print("⚠️ No se detectó entorno virtual activo")
        print("   Esto puede causar errores de instalación")
        return False


def find_venv():
    """Find available virtual environments."""
    possible_venvs = []

    # Check common locations
    locations = [
        Path.cwd() / "djpt_venv",
        Path.cwd() / "venv",
        Path.cwd() / ".venv",
        Path.cwd() / "mi_venv",
    ]

    for location in locations:
        if location.exists() and (location / "bin" / "python").exists():
            possible_venvs.append(location)
            print(f"   📁 Entorno encontrado: {location}")

    return possible_venvs


def activate_venv(venv_path):
    """Generate activation command for virtual environment."""
    if os.name == "nt":  # Windows
        activate_script = venv_path / "Scripts" / "activate.bat"
        if activate_script.exists():
            return f'call "{activate_script}"'
    else:  # Unix/Linux/macOS
        activate_script = venv_path / "bin" / "activate"
        if activate_script.exists():
            return f'source "{activate_script}"'

    return None


def fix_pip_issues():
    """Fix common pip installation issues."""
    print("🔧 Aplicando soluciones para problemas comunes de pip...")

    fixes = []

    # Check for externally-managed-environment error
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "--version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            print(f"✅ pip funcional: {result.stdout.strip()}")
        else:
            fixes.append("pip no responde correctamente")
    except Exception as e:
        fixes.append(f"Error verificando pip: {e}")

    # Check if we need to use --user flag
    try:
        test_install = subprocess.run(
            [
                sys.executable,
                "-m",
                "pip",
                "install",
                "--user",
                "--dry-run",
                "setuptools",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if test_install.returncode == 0:
            print("✅ pip --user funciona correctamente")
            fixes.append("Usar --user flag para instalaciones")
    except Exception:
        fixes.append("Considerar --break-system-packages para Homebrew")

    return fixes


def install_with_workarounds(category="critical"):
    """Install dependencies with common workarounds."""
    script_path = Path(__file__).parent / "install_deps.py"

    if not script_path.exists():
        print("❌ install_deps.py no encontrado")
        return False

    print(f"📦 Instalando dependencias {category} con workarounds...")

    # Try different installation methods
    methods = [
        # Method 1: Standard pip in venv
        [sys.executable, "-m", "pip", "install"],
        # Method 2: pip with --user flag
        [sys.executable, "-m", "pip", "install", "--user"],
        # Method 3: pip with break-system-packages
        [sys.executable, "-m", "pip", "install", "--break-system-packages"],
    ]

    for method in methods:
        print(f"🔄 Intentando método: {' '.join(method[2:])}")

        cmd = method + [category]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            if result.returncode == 0:
                print(f"✅ Instalación exitosa con: {' '.join(method[2:])}")
                return True
            else:
                print(f"❌ Fallo con método: {' '.join(method[2:])}")
                print(f"   Error: {result.stderr}")
        except subprocess.TimeoutExpired:
            print("⏰ Timeout - Intentando siguiente método...")
        except Exception as e:
            print(f"💥 Error inesperado: {e}")

    return False


def create_proper_install_script():
    """Create a robust installation script."""
    script_content = """#!/bin/bash
# DJProducerTools - Installation Script with Workarounds
set -e

echo "🚀 DJProducerTools - Installation Script"
echo "====================================="

# Check Python
python3 --version

# Find or create virtual environment
if [ ! -d "djpt_venv" ]; then
    echo "🏗️ Creando virtual environment..."
    python3 -m venv djpt_venv
fi

# Activate virtual environment
echo "🔄 Activando virtual environment..."
source djpt_.venv/bin/activate

# Upgrade pip in venv
echo "⬆️ Actualizando pip..."
pip install --upgrade pip

# Install critical dependencies
echo "📦 Instalando dependencias críticas..."
pip install librosa pandas scikit-learn joblib

# Install optional dependencies
echo "📦 Instalando dependencias opcionales..."
pip install tensorflow tensorflow-hub || echo "⚠️ Opcionales no instaladas (normal)"

# Install hardware dependencies
echo "📦 Instalando dependencias de hardware..."
pip install pyserial

echo "✅ Instalación completada!"
echo ""
echo "🎯 Para usar DJProducerTools:"
echo "   source djpt_.venv/bin/activate"
echo "   python3 scripts/install_deps.py check"
"""

    script_path = Path("install_with_fixes.sh")
    with open(script_path, "w") as f:
        f.write(script_content)

    os.chmod(script_path, 0o755)
    print(f"✅ Script de instalación creado: {script_path}")
    print("   Ejecuta con: ./install_with_fixes.sh")

    return script_path


def main():
    """Main repair function."""
    print_banner()

    # Check current environment
    env_ok = check_environment()

    # Find available virtual environments
    venvs = find_venv()

    if not venvs:
        print("\n🏗️ No se encontraron entornos virtuales")
        print("   Creando nuevo entorno virtual...")

        # Create new venv
        try:
            subprocess.run(
                [sys.executable, "-m", "venv", "djpt_venv_fixed"],
                capture_output=True,
                text=True,
                timeout=120,
            )
            print("✅ Entorno virtual creado: djpt_venv_fixed")
            venvs.append(Path("djpt_venv_fixed"))
        except Exception as e:
            print(f"❌ Error creando venv: {e}")
            return

    # Fix pip issues
    fixes = fix_pip_issues()

    if fixes:
        print("\n🔧 Soluciones aplicadas:")
        for fix in fixes:
            print(f"   • {fix}")

    # Create installation script
    print("\n📝 Creando script de instalación con workarounds...")
    install_script = create_proper_install_script()

    # Provide next steps
    print("\n🎯 Soluciones y próximos pasos:")
    print("=" * 40)

    print("1️⃣ Opción RECOMENDADA - Usar script automático:")
    print("   ./install_with_fixes.sh")

    print("\n2️⃣ Opción MANUAL - Activar entorno e instalar:")
    if venvs:
        activate_cmd = activate_venv(venvs[0])
        if activate_cmd:
            print(f"   {activate_cmd}")
            print("   python3 scripts/install_deps.py install critical")

    print("\n3️⃣ Opción AVANZADA - Instalación con workarounds:")
    print("   python3 scripts/dependency_fix.py install critical")

    print("\n📊 Resumen del diagnóstico:")
    print(f"   • Entorno virtual: {'✅ Detectado' if env_ok else '❌ No detectado'}")
    print(f"   • Entornos disponibles: {len(venvs)}")
    print(f"   • Problemas de pip detectados: {len(fixes)}")
    print("   • Script de reparación: ✅ Creado")

    print("\n🎉 Sistema de reparación completado!")


if __name__ == "__main__":
    main()
