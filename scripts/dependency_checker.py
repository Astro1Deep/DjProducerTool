#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def available(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


def main() -> int:
    parser = argparse.ArgumentParser(description='DJProducerTools dependency checker')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    payload = {
        'pyproject': (ROOT / 'pyproject.toml').exists(),
        'requirements': (ROOT / 'requirements.txt').exists(),
        'requirements_dev': (ROOT / 'requirements-dev.txt').exists(),
        'mlx': available('mlx'),
        'tensorflow': available('tensorflow'),
    }
    if args.json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        for key, value in payload.items():
            print(f'{key}: {"OK" if value else "MISSING"}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
