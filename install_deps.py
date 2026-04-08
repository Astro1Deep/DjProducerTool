#!/usr/bin/env python3
"""
DJProducerTools Dependency Installer
Simple, robust dependency management for DJProducerTools
"""

import subprocess
import sys
from pathlib import Path

# Define dependencies with installation commands
DEPENDENCIES = {
    "critical": [
        ("librosa", "pip3 install librosa"),
        ("pandas", "pip3 install pandas"),
        ("scikit-learn", "pip3 install scikit-learn"),
        ("joblib", "pip3 install joblib"),
    ],
    "optional": [
        ("tensorflow", "pip3 install tensorflow"),
        ("tensorflow-hub", "pip3 install tensorflow-hub"),
    ],
    "hardware": [("pyserial", "pip3 install pyserial")],
}


def run_command(cmd, description=""):
    """Run a command and return success status."""
    print(f"🔄 {description}")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
        if result.returncode == 0:
            print(f"✅ {description} - Success")
            return True
        else:
            print(f"❌ {description} - Failed")
            print(f"   Error: {result.stderr}")
            return False
    except subprocess.TimeoutExpired:
        print(f"⏰ {description} - Timeout")
        return False
    except Exception as e:
        print(f"💥 {description} - Error: {e}")
        return False


def check_python():
    """Check Python version."""
    print("🐍 Checking Python version...")
    try:
        result = subprocess.run([sys.executable, "--version"], capture_output=True, text=True)
        print(f"   {result.stdout.strip()}")
        return True
    except Exception as e:
        print(f"   Error: {e}")
        return False


def check_dependency(name):
    """Check if a dependency is available."""
    try:
        if name == "librosa":
            import librosa

            print(f"✅ librosa v{librosa.__version__}")
        elif name == "pandas":
            import pandas

            print(f"✅ pandas v{pandas.__version__}")
        elif name == "scikit-learn":
            import sklearn

            print(f"✅ scikit-learn v{sklearn.__version__}")
        elif name == "joblib":
            import joblib

            print(f"✅ joblib v{joblib.__version__}")
        elif name == "tensorflow":
            import tensorflow

            print(f"✅ tensorflow v{tensorflow.__version__}")
        elif name == "tensorflow-hub":
            import tensorflow_hub

            print(f"✅ tensorflow-hub v{tensorflow_hub.__version__}")
        elif name == "pyserial":
            import serial

            print(f"✅ pyserial v{serial.VERSION}")
        else:
            print(f"❓ {name} - Unknown dependency")
        return True
    except ImportError:
        print(f"❌ {name} - Not installed")
        return False


def install_dependencies(category="all"):
    """Install dependencies by category."""
    print(f"📦 Installing {category} dependencies...")
    print("=" * 50)

    success_count = 0
    total_count = 0

    categories = [category] if category != "all" else DEPENDENCIES.keys()

    for cat in categories:
        if cat not in DEPENDENCIES:
            print(f"❌ Unknown category: {cat}")
            continue

        print(f"\n📂 Category: {cat.upper()}")
        for name, install_cmd in DEPENDENCIES[cat]:
            total_count += 1
            if run_command(install_cmd, f"Installing {name}"):
                success_count += 1

    print(f"\n📊 Summary: {success_count}/{total_count} packages installed successfully")
    return success_count == total_count


def check_all_dependencies():
    """Check all dependencies status."""
    print("🔍 Checking DJProducerTools Dependencies")
    print("=" * 50)

    check_python()
    print("\n📦 Dependencies:")

    all_available = True
    for category, deps in DEPENDENCIES.items():
        print(f"\n📂 {category.upper()}:")
        for name, _ in deps:
            if not check_dependency(name):
                all_available = False

    print("\n" + "=" * 50)
    if all_available:
        print("🎉 All dependencies are installed!")
    else:
        print("⚠️ Some dependencies are missing. Run with 'install' to install them.")
        print("\n💡 Installation options:")
        print("   python3 install_deps.py install critical   # Install core dependencies")
        print("   python3 install_deps.py install all        # Install everything")
        print("   python3 install_deps.py install optional   # Install ML/AI features")
        print("   python3 install_deps.py install hardware   # Install hardware support")

    return all_available


def create_venv(venv_path):
    """Create virtual environment."""
    print(f"🏗️ Creating virtual environment at {venv_path}")

    # Create directory
    Path(venv_path).mkdir(parents=True, exist_ok=True)

    # Create venv
    if run_command(f"{sys.executable} -m venv {venv_path}", "Creating virtual environment"):
        print(f"✅ Virtual environment created at {venv_path}")
        print(f"🔄 Activate with: source {venv_path}/bin/activate")
        print("🔄 Then run: python3 install_deps.py install critical")
        return True
    else:
        print("❌ Failed to create virtual environment")
        return False


def main():
    if len(sys.argv) < 2:
        check_all_dependencies()
        return

    command = sys.argv[1].lower()

    if command == "check":
        check_all_dependencies()
    elif command == "install":
        category = sys.argv[2].lower() if len(sys.argv) > 2 else "critical"
        install_dependencies(category)
    elif command == "create-venv":
        if len(sys.argv) < 3:
            print("❌ Please specify venv path")
            print("   Usage: python3 install_deps.py create-venv /path/to/venv")
            return
        venv_path = sys.argv[2]
        create_venv(venv_path)
    else:
        print("❌ Unknown command")
        print("📋 Available commands:")
        print("   check                    - Check all dependencies")
        print("   install [category]       - Install dependencies")
        print("   create-venv [path]       - Create virtual environment")
        print("\n📦 Categories:")
        print("   critical   - Core dependencies (librosa, pandas, scikit-learn, joblib)")
        print("   optional   - ML/AI features (tensorflow, tensorflow-hub)")
        print("   hardware   - Hardware support (pyserial)")
        print("   all        - Install everything")


if __name__ == "__main__":
    main()
