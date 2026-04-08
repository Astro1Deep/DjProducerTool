#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

AUDIO_EXTENSIONS = {'.mp3', '.wav', '.flac', '.aiff', '.m4a', '.aac', '.ogg'}
EXCLUDED_DIRS = {'_DJProducerTools', '.git', 'state', 'dist', 'djpt_venv', '.venv', 'venv', '__pycache__'}


def generate_config(path: Path) -> None:
    payload = {
        'excluded_dirs': sorted(EXCLUDED_DIRS),
        'audio_extensions': sorted(AUDIO_EXTENSIONS),
        'follow_symlinks': False,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def iter_audio_files(root: Path):
    for current_root, dirnames, filenames in os.walk(root):
        dirnames[:] = [name for name in dirnames if name not in EXCLUDED_DIRS]
        current = Path(current_root)
        for name in sorted(filenames):
            path = current / name
            if path.suffix.lower() in AUDIO_EXTENSIONS:
                yield path


def scan_inventory(base: Path, out: Path) -> int:
    items = [str(path) for path in iter_audio_files(base)]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text('\n'.join(items) + ('\n' if items else ''), encoding='utf-8')
    return len(items)


def main() -> int:
    parser = argparse.ArgumentParser(description='Efficient Audio Inventory Scanner')
    parser.add_argument('base', nargs='?', help='Base directory to scan')
    parser.add_argument('out', nargs='?', help='Output inventory file')
    parser.add_argument('--generate-config', dest='generate_config')
    args = parser.parse_args()

    if args.generate_config:
        generate_config(Path(args.generate_config))
        print(f'Config generated: {args.generate_config}')
        return 0
    if not args.base or not args.out:
        parser.error('base and out are required unless --generate-config is used')
    count = scan_inventory(Path(args.base), Path(args.out))
    print(f'Indexed {count} audio files')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
