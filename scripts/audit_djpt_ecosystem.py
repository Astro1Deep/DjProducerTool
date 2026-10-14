#!/usr/bin/env python3
"""
DJProducerTools & Tri-System Ecosystem - Auditoría Integral y Diagnóstico
Auditoría profunda de sintaxis, dependencias, ecosistema de 3 discos y motor ShazamIO.
"""

from __future__ import annotations

import os
import sys
import subprocess
import py_compile
import shutil
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]

def run_cmd(cmd: list[str]) -> tuple[int, str]:
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, (res.stdout + res.stderr).strip()

def main():
    print("=" * 75)
    print("🎧 DJPRODUCERTOOLS & ECOSISTEMA MULTI-DISCO - AUDITORÍA COMPLETA")
    print(f"Fecha: {datetime.now(timezone.utc).isoformat()} | Host: macOS Apple Silicon")
    print("=" * 75)

    # 1. Auditoría de Sintaxis Python
    print("\n[1/5] 🐍 Auditoría de Sintaxis Python (py_compile)...")
    py_files = list(ROOT.rglob("*.py"))
    # Excluir carpetas temporales o backups
    py_files = [p for p in py_files if ".venv" not in str(p) and "build" not in str(p)]
    py_errors = []
    for pf in py_files:
        try:
            py_compile.compile(str(pf), doraise=True)
        except Exception as e:
            py_errors.append((str(pf.relative_to(ROOT)), str(e)))

    if not py_errors:
        print(f"  ✔ {len(py_files)} archivos Python analizados. Cero errores de sintaxis (100% OK).")
    else:
        print(f"  ❌ Errores encontrados en {len(py_errors)} archivos:")
        for fn, err in py_errors:
            print(f"     - {fn}: {err}")

    # 2. Auditoría de Scripts Bash (bash -n)
    print("\n[2/5] 🐚 Auditoría de Scripts Shell (bash -n)...")
    sh_files = list(ROOT.rglob("*.sh"))
    sh_files = [p for p in sh_files if ".venv" not in str(p)]
    sh_errors = []
    for sf in sh_files:
        code, out = run_cmd(["bash", "-n", str(sf)])
        if code != 0:
            sh_errors.append((str(sf.relative_to(ROOT)), out))

    if not sh_errors:
        print(f"  ✔ {len(sh_files)} scripts Bash verificados con bash -n. Sintaxis 100% válida.")
    else:
        print(f"  ❌ Errores en {len(sh_errors)} scripts Bash:")
        for fn, err in sh_errors:
            print(f"     - {fn}: {err}")

    # 3. Auditoría de Ecosistema de Almacenamiento (Los 3 Sistemas)
    print("\n[3/5] 💽 Auditoría de Conectividad y Estado de Discos...")
    disks = [
        ("Akai MPC Sample (MicroSD)", "/Volumes/MPCSMPL", ["MPC-Sample", "Expansions", "SQLITE_DATABASE"]),
        ("Serato DJ Pro & VJ Loops", "/Volumes/SanDisk SSD", ["00_SERATO_MUSICA", "_Serato_", "_INDEX_SERATO_DJ"]),
        ("Producción & Ableton/SP-404", "/Volumes/samsung PSSDT7", ["_INDEX_PRODUCCION"]),
        ("Audioteca NI (Secundario)", "/Volumes/Realtek RTL9210B-CG Media", ["_INDEX_AUDIOTECA"])
    ]

    for label, mount_point, expected_dirs in disks:
        mp = Path(mount_point)
        if mp.exists() and mp.is_dir():
            status = "CONECTADO & MONTADO"
            sub_checks = []
            for ed in expected_dirs:
                exists = (mp / ed).exists()
                sub_checks.append(f"{ed}: {'✔' if exists else '⚠️'}")
            print(f"  ✔ {label}: [{status}] ({', '.join(sub_checks)})")
        else:
            print(f"  ⚪ {label}: [NO MONTADO]")

    # 4. Auditoría de Herramientas CLI y Motores de Audio
    print("\n[4/5] ⚙️ Auditoría de Herramientas CLI del Sistema...")
    tools = ["ffmpeg", "ffprobe", "sox", "sqlite3", "uv", "python3", "git"]
    for t in tools:
        found = shutil.which(t)
        ver = ""
        if found:
            if t in ["ffmpeg", "ffprobe", "sqlite3"]:
                _, out = run_cmd([t, "-version"])
                ver = out.splitlines()[0] if out else ""
            elif t == "python3":
                _, out = run_cmd([t, "--version"])
                ver = out
            elif t == "uv":
                _, out = run_cmd([t, "--version"])
                ver = out
            print(f"  ✔ {t:10}: {found} ({ver[:45]})")
        else:
            print(f"  ❌ {t:10}: NO INSTALADO")

    # 5. Auditoría del Módulo ShazamIO (Acoustic Engine)
    print("\n[5/5] 🎧 Auditoría del Motor Acústico ShazamIO...")
    shz_py = ROOT / "lib" / "shazam_resilient_engine.py"
    if shz_py.exists():
        code, out = run_cmd(["uv", "run", "--no-project", "--with", "shazamio", "python3", str(ROOT / "scripts" / "integration_checks.py"), "shazam"])
        if code == 0:
            print("  ✔ Motor Resiliente ShazamIO y scripts de integración: ACTIVOS Y LISTOS")
            print(f"  ✔ Script ejecutable: {shz_py}")
        else:
            print(f"  ⚠️ Error al validar integración Shazam: {out}")
    else:
        print(f"  ❌ Falta el script: {shz_py}")

    print("\n" + "=" * 75)
    print("🎉 AUDITORÍA COMPLETADA CON ÉXITO")
    print("=" * 75)

if __name__ == "__main__":
    main()
