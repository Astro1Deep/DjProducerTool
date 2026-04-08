#!/usr/bin/env python3
"""
Dependency checker for DJProducerTools.
Reports missing Python modules by group and exits non-zero if required deps are missing.
"""

import argparse
import importlib
import json
import sys
from typing import Dict, List

# Map group -> {module_name: package_name}
GROUPS: Dict[str, Dict[str, str]] = {
    "core": {
        "requests": "requests",
        "psutil": "psutil",
        "yaml": "pyyaml",
        "tqdm": "tqdm",
        "rich": "rich",
        "click": "click",
        "typer": "typer",
    },
    "audio": {
        "numpy": "numpy",
        "pandas": "pandas",
        "mutagen": "mutagen",
        "soundfile": "soundfile",
        "librosa": "librosa",
    },
    "apple-silicon": {
        "mlx": "mlx",
        "mlx_lm": "mlx-lm",
    },
    "ml": {
        "sklearn": "scikit-learn",
        "tensorflow": "tensorflow",
        "sentence_transformers": "sentence-transformers",
    },
    "ai": {
        "pdfplumber": "pdfplumber",
        "openai": "openai",
        "anthropic": "anthropic",
    },
    "dev": {
        "pytest": "pytest",
        "black": "black",
        "flake8": "flake8",
        "mypy": "mypy",
    },
}


def check_modules(modules: Dict[str, str]) -> Dict[str, List[str]]:
    missing_modules: List[str] = []
    missing_packages: List[str] = []
    for module_name, package_name in modules.items():
        try:
            importlib.import_module(module_name)
        except Exception:
            missing_modules.append(module_name)
            missing_packages.append(package_name)
    return {
        "missing_modules": missing_modules,
        "missing_packages": missing_packages,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="DJProducerTools dependency checker")
    parser.add_argument(
        "--groups",
        default="core",
        help="Comma-separated groups to check (core,audio,apple-silicon,ml,ai,dev)",
    )
    parser.add_argument("--json", action="store_true", help="Output JSON report")
    parser.add_argument(
        "--report-only",
        action="store_true",
        help="Always exit 0 (report only)",
    )
    args = parser.parse_args()

    group_names = [g.strip() for g in args.groups.split(",") if g.strip()]
    unknown = [g for g in group_names if g not in GROUPS]
    if unknown:
        sys.stderr.write(f"Unknown groups: {', '.join(unknown)}\n")
        return 2

    report = {
        "groups": group_names,
        "missing_modules": {},
        "missing_packages": {},
        "ok": True,
    }

    any_missing = False
    for group in group_names:
        result = check_modules(GROUPS[group])
        report["missing_modules"][group] = result["missing_modules"]
        report["missing_packages"][group] = result["missing_packages"]
        if result["missing_modules"]:
            any_missing = True

    report["ok"] = not any_missing

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        for group in group_names:
            missing = report["missing_packages"][group]
            if missing:
                print(f"[{group}] missing: {', '.join(missing)}")
            else:
                print(f"[{group}] ok")

    if args.report_only:
        return 0
    return 1 if any_missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
