#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LABEL = "com.djpt.chat.tasks.runner"
DEFAULT_INTERVAL = 300


def default_plist_path(label: str) -> Path:
    return Path.home() / "Library" / "LaunchAgents" / f"{label}.plist"


def render_plist(
    *,
    label: str,
    program_args: list[str],
    start_interval: int,
    stdout_path: Path,
    stderr_path: Path,
    working_directory: Path,
) -> str:
    args_xml = "\n".join(f"      <string>{arg}</string>" for arg in program_args)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        '<plist version="1.0">\n'
        "<dict>\n"
        "  <key>Label</key>\n"
        f"  <string>{label}</string>\n"
        "  <key>ProgramArguments</key>\n"
        "  <array>\n"
        f"{args_xml}\n"
        "  </array>\n"
        "  <key>WorkingDirectory</key>\n"
        f"  <string>{working_directory}</string>\n"
        "  <key>RunAtLoad</key>\n"
        "  <true/>\n"
        "  <key>StartInterval</key>\n"
        f"  <integer>{int(start_interval)}</integer>\n"
        "  <key>StandardOutPath</key>\n"
        f"  <string>{stdout_path}</string>\n"
        "  <key>StandardErrorPath</key>\n"
        f"  <string>{stderr_path}</string>\n"
        "</dict>\n"
        "</plist>\n"
    )


def _launchctl(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["launchctl", *args],
        capture_output=True,
        text=True,
        check=False,
    )


def install_agent(
    *,
    label: str,
    plist_path: Path,
    program_args: list[str],
    start_interval: int,
    apply: bool,
) -> int:
    logs_dir = REPO_ROOT / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    stdout_path = logs_dir / "launchd_chat_tasks.out.log"
    stderr_path = logs_dir / "launchd_chat_tasks.err.log"
    plist_text = render_plist(
        label=label,
        program_args=program_args,
        start_interval=start_interval,
        stdout_path=stdout_path,
        stderr_path=stderr_path,
        working_directory=REPO_ROOT,
    )
    plist_path.parent.mkdir(parents=True, exist_ok=True)
    plist_path.write_text(plist_text, encoding="utf-8")
    print(f"[OK] plist escrito en {plist_path}")

    if not apply:
        print("[INFO] modo dry-run: no se ejecuta launchctl")
        return 0

    uid = str(os.getuid())
    _launchctl("bootout", f"gui/{uid}/{label}")
    proc = _launchctl("bootstrap", f"gui/{uid}", str(plist_path))
    if proc.returncode != 0:
        print(proc.stderr.strip())
        return proc.returncode

    enable_proc = _launchctl("enable", f"gui/{uid}/{label}")
    if enable_proc.returncode != 0:
        print(enable_proc.stderr.strip())
    print(f"[OK] launchd agent cargado: {label}")
    return 0


def uninstall_agent(*, label: str, plist_path: Path, apply: bool) -> int:
    if not apply:
        print("[INFO] modo dry-run: no se ejecuta launchctl ni borrado")
        return 0

    uid = str(os.getuid())
    _launchctl("bootout", f"gui/{uid}/{label}")
    if plist_path.exists():
        plist_path.unlink()
        print(f"[OK] plist eliminado: {plist_path}")
    else:
        print(f"[INFO] plist no existía: {plist_path}")
    return 0


def status_agent(*, label: str, plist_path: Path) -> int:
    print(f"[STATUS] label={label}")
    print(f"[STATUS] plist={plist_path} exists={plist_path.exists()}")
    uid = str(os.getuid())
    proc = _launchctl("print", f"gui/{uid}/{label}")
    if proc.returncode == 0:
        print(proc.stdout.strip())
        return 0
    print(proc.stderr.strip())
    return 2


def _build_program_args(base_path: Path, python_bin: str) -> list[str]:
    runner = REPO_ROOT / "scripts" / "chat_tasks_runner.py"
    return [
        python_bin,
        str(runner),
        "--base-path",
        str(base_path),
        "--python-bin",
        python_bin,
        "--json",
    ]


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gestiona launchd para tareas del chat DJPT.")
    parser.add_argument("action", choices=["render", "install", "uninstall", "status", "run-once"])
    parser.add_argument("--label", default=DEFAULT_LABEL, help="Label del agente launchd")
    parser.add_argument("--interval", type=int, default=DEFAULT_INTERVAL, help="StartInterval en segundos")
    parser.add_argument("--base-path", default=str(REPO_ROOT), help="Ruta base del proyecto")
    parser.add_argument("--python-bin", default=sys.executable, help="Python ejecutor")
    parser.add_argument("--plist-path", default=None, help="Ruta plist explícita")
    parser.add_argument("--apply", action="store_true", help="Aplica cambios con launchctl")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    base_path = Path(args.base_path).expanduser().resolve()
    plist_path = Path(args.plist_path).expanduser().resolve() if args.plist_path else default_plist_path(args.label)
    program_args = _build_program_args(base_path, args.python_bin)

    if args.action == "render":
        text = render_plist(
            label=args.label,
            program_args=program_args,
            start_interval=max(args.interval, 60),
            stdout_path=REPO_ROOT / "logs" / "launchd_chat_tasks.out.log",
            stderr_path=REPO_ROOT / "logs" / "launchd_chat_tasks.err.log",
            working_directory=REPO_ROOT,
        )
        print(text, end="")
        return 0

    if args.action == "install":
        return install_agent(
            label=args.label,
            plist_path=plist_path,
            program_args=program_args,
            start_interval=max(args.interval, 60),
            apply=args.apply,
        )

    if args.action == "uninstall":
        return uninstall_agent(label=args.label, plist_path=plist_path, apply=args.apply)

    if args.action == "status":
        return status_agent(label=args.label, plist_path=plist_path)

    if args.action == "run-once":
        runner = REPO_ROOT / "scripts" / "chat_tasks_runner.py"
        proc = subprocess.run(
            [args.python_bin, str(runner), "--base-path", str(base_path), "--python-bin", args.python_bin],
            check=False,
        )
        return proc.returncode

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
