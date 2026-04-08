#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(text, encoding='utf-8')
    tmp.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description='Safely write a file atomically')
    parser.add_argument('path')
    parser.add_argument('--text', default='')
    args = parser.parse_args()
    write_atomic(Path(args.path), args.text)
    print(args.path)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
