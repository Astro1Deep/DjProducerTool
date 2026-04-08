#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib  # type: ignore


def _ts() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")


def cmd_validate(path: Path) -> int:
    try:
        tomllib.loads(path.read_text(encoding="utf-8"))
        payload = {"valid": True, "file": str(path)}
    except Exception as exc:
        payload = {"valid": False, "file": str(path), "error": f"toml_parse_error: {exc}"}
    print(json.dumps(payload, ensure_ascii=False))
    return 0


def cmd_backup(path: Path) -> int:
    backup = path.with_name(f"{path.name}.{_ts()}.bak")
    shutil.copy2(path, backup)
    print(json.dumps({"ok": True, "file": str(path), "backup_file": str(backup)}, ensure_ascii=False))
    return 0


def cmd_restore(path: Path, backup: Path) -> int:
    shutil.copy2(backup, path)
    print(json.dumps({"ok": True, "file": str(path), "backup_file": str(backup)}, ensure_ascii=False))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Config backup/validate helpers")
    sub = parser.add_subparsers(dest="command", required=True)

    validate = sub.add_parser("validate")
    validate.add_argument("--file", required=True)

    backup = sub.add_parser("backup")
    backup.add_argument("--file", required=True)

    restore = sub.add_parser("restore")
    restore.add_argument("--file", required=True)
    restore.add_argument("--backup", required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.command == "validate":
        return cmd_validate(Path(args.file))
    if args.command == "backup":
        return cmd_backup(Path(args.file))
    if args.command == "restore":
        return cmd_restore(Path(args.file), Path(args.backup))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
