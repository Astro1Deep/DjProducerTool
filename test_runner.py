#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main() -> int:
    parser = argparse.ArgumentParser(description='Run DJProducerTools tests with timeout control')
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('targets', nargs='*', default=['tests'])
    args = parser.parse_args()
    cmd = ['python3', '-m', 'pytest', *args.targets]
    try:
      result = subprocess.run(cmd, cwd=str(ROOT), check=False, timeout=args.timeout)
    except subprocess.TimeoutExpired:
      print('TimeoutExpired')
      return 124
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
