#!/usr/bin/env python3
"""
DJProducerTools Chat CLI
Interactive management interface for the DJProducerTools suite.
"""
import os
import sys
import subprocess
import shlex
import time
from pathlib import Path

# ANSI Colors
C_CYN = "\033[1;36m"
C_GRN = "\033[1;32m"
C_YLW = "\033[1;33m"
C_RED = "\033[1;31m"
C_RESET = "\033[0m"

SCRIPT_DIR = Path(__file__).parent.resolve()
ROOT_DIR = SCRIPT_DIR.parent
ENGINE_SCRIPT = SCRIPT_DIR / "DJProducerTools_MultiScript_EN.sh"

def load_conf():
    # Priority: Env var -> default logic
    base = os.environ.get("BASE_PATH")
    if base:
        conf_file = Path(base) / "_DJProducerTools" / "config" / "djpt.conf"
    else:
        conf_file = ROOT_DIR / "_DJProducerTools" / "config" / "djpt.conf"
        
    if not conf_file.exists():
        return {}
    config = {}
    with open(conf_file, "r") as f:
        for line in f:
            if "=" in line:
                key, val = line.strip().split("=", 1)
                config[key] = val.strip("'\"")
    return config

def run_engine(action):
    """Executes the shell script engine with a specific action."""
    cmd = [str(ENGINE_SCRIPT), "--run", action]
    try:
        subprocess.run(cmd, check=False)
    except Exception as e:
        print(f"{C_RED}[ERR] Failed to run engine: {e}{C_RESET}")

def print_help():
    print(f"\n{C_CYN}Available Commands:{C_RESET}")
    print(f"  {C_GRN}status{C_RESET}    - Show system status and paths")
    print(f"  {C_GRN}scan{C_RESET}      - Scan workspace for files")
    print(f"  {C_GRN}backup{C_RESET}    - Perform DJ library backup")
    print(f"  {C_GRN}dupes{C_RESET}     - Find exact duplicates (Hash)")
    print(f"  {C_GRN}smart{C_RESET}     - Run Smart Analysis (Deep Thinking)")
    print(f"  {C_GRN}predict{C_RESET}   - Run ML Problem Predictor")
    print(f"  {C_GRN}optimize{C_RESET}  - Run Efficiency Optimizer")
    print(f"  {C_GRN}workflow{C_RESET}  - Generate Smart Workflow")
    print(f"  {C_GRN}ml train{C_RESET}  - Train local evolutionary model")
    print(f"  {C_GRN}ml predict{C_RESET}- Predict using local model")
    print(f"  {C_GRN}ml status{C_RESET} - Check model status")
    print(f"  {C_GRN}help{C_RESET}      - Show this help")
    print(f"  {C_GRN}exit{C_RESET}      - Exit CLI")

def get_python_bin(base_path):
    """Detects the virtual environment python binary."""
    # Priority: Env var passed from shell script
    env_venv = os.environ.get("VENV_DIR")
    if env_venv:
        venv_python = Path(env_venv) / "bin" / "python3"
        if venv_python.exists():
            return str(venv_python)

    venv_python = Path(base_path) / "_DJProducerTools" / "venv" / "bin" / "python3"
    if venv_python.exists():
        return str(venv_python)
    return sys.executable

def ensure_ai_structure(base_path):
    """Creates the necessary folder structure for the AI layer."""
    base = Path(base_path) / "_DJProducerTools"
    dirs = [
        base / "kb" / "raw",
        base / "ai" / "embeddings",
        base / "ai" / "models",
        base / "ai" / "index",
        base / "chat" / "logs",
        base / "config",
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)

def main():
    print(f"{C_CYN}Welcome to DJProducerTools Chat CLI{C_RESET}")
    print(f"Type 'help' for commands or describe what you want to do.")
    
    config = load_conf()
    # Env var overrides config
    base_path = os.environ.get("BASE_PATH") or config.get("BASE_PATH", str(ROOT_DIR))
    
    # Ensure AI structure exists
    ensure_ai_structure(base_path)

    python_bin = get_python_bin(base_path)
    print(f"Active Base: {C_YLW}{base_path}{C_RESET}")
    if python_bin != sys.executable:
        print(f"ML Environment: {C_GRN}Active ({python_bin}){C_RESET}\n")
    else:
        print(f"ML Environment: {C_YLW}System Python (venv not found){C_RESET}\n")

    while True:
        try:
            user_input = input(f"{C_CYN}djpt>{C_RESET} ").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print("\nExiting...")
            break

        if not user_input:
            continue

        if user_input in ["exit", "quit", "q", "back", "atras", "volver"]:
            print(f"\n{C_GRN}Returning to main menu...{C_RESET}")
            break
        
        if user_input in ["help", "ayuda"]:
            print_help()
            continue

        # Intent Matching
        if "status" in user_input or "info" in user_input:
            run_engine("status")
        elif "scan" in user_input:
            run_engine("scan")
        elif "backup" in user_input:
            run_engine("backup")
        elif "hash" in user_input:
            run_engine("hash")
        elif "dupes" in user_input or "duplicates" in user_input:
            run_engine("dupes")
        elif "smart" in user_input or "analysis" in user_input:
            run_engine("smart")
        elif "predict" in user_input and "ml" not in user_input:
            run_engine("predict")
        elif "optimize" in user_input:
            run_engine("optimize")
        elif "workflow" in user_input:
            run_engine("workflow")
        elif "ml status" in user_input:
            model_path = Path(base_path) / "_DJProducerTools" / "ml_model.pkl"
            if model_path.exists():
                size_kb = model_path.stat().st_size / 1024
                mtime = time.ctime(model_path.stat().st_mtime)
                print(f"{C_GRN}[OK] Model found.{C_RESET} Size: {size_kb:.1f}KB. Last modified: {mtime}")
            else:
                print(f"{C_YLW}[INFO] No model trained yet.{C_RESET} Run 'ml train' to create one.")
        elif "ml train" in user_input:
            # Direct python call example
            print(f"{C_YLW}[INFO] Invoking ML training directly...{C_RESET}")
            subprocess.run([python_bin, str(SCRIPT_DIR / "lib" / "ml_evolutionary.py"), "train", "--base", base_path, "--model-out", str(Path(base_path)/"_DJProducerTools/ml_model.pkl")])
        elif "ml predict" in user_input:
             print(f"{C_YLW}[INFO] Invoking ML prediction directly...{C_RESET}")
             subprocess.run([python_bin, str(SCRIPT_DIR / "lib" / "ml_evolutionary.py"), "predict", "--base", base_path, "--model-in", str(Path(base_path)/"_DJProducerTools/ml_model.pkl")])
        else:
            print(f"{C_RED}Unknown command or intent.{C_RESET} Try 'help'.")

if __name__ == "__main__":
    main()
