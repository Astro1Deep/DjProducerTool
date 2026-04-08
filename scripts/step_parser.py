#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json


def parse_steps(spec: str) -> list[int]:
    steps: set[int] = set()
    for chunk in spec.split(','):
        part = chunk.strip()
        if not part:
            continue
        if '-' in part:
            start_s, end_s = part.split('-', 1)
            start = int(start_s)
            end = int(end_s)
            for item in range(min(start, end), max(start, end) + 1):
                steps.add(item)
        else:
            steps.add(int(part))
    return sorted(steps)


def main() -> int:
    parser = argparse.ArgumentParser(description='Parse and validate step sequences')
    parser.add_argument('spec', nargs='?', default='1-3')
    args = parser.parse_args()
    print(json.dumps({'steps': parse_steps(args.spec)}, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
