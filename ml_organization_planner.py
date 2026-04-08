#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

AUDIO_EXTS = {'.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg', '.aif', '.aiff'}
VIDEO_EXTS = {'.mp4', '.mov', '.mkv', '.avi', '.m4v'}
DOC_EXTS = {'.pdf', '.txt', '.md', '.csv', '.tsv', '.json', '.xml'}
SKIP_DIRS = {'_DJProducerTools', '.git', '__pycache__', 'node_modules', '.venv', 'venv', 'djpt_venv'}


def _category(path: Path) -> tuple[str, str, str]:
    suffix = path.suffix.lower()
    if suffix in AUDIO_EXTS:
        return ('AUDIO', f'Organized/Audio/{suffix.lstrip(".").upper()}', '0.90')
    if suffix in VIDEO_EXTS:
        return ('VIDEO', 'Organized/Video', '0.85')
    if suffix in DOC_EXTS:
        return ('DOC', 'Organized/Documents', '0.75')
    return ('OTHER', 'Organized/Misc', '0.60')


def build_plan(base: str, out_path: str, limit: int = 50, lang: str = 'en') -> Path:
    root = Path(base).expanduser().resolve()
    out = Path(out_path).expanduser().resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    rows = []
    for path in sorted(root.rglob('*')):
        if len(rows) >= limit:
            break
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        category, target, confidence = _category(path)
        rel = path.relative_to(root) if path.is_relative_to(root) else path
        rows.append((str(rel), category, target, confidence))

    if not rows:
        rows.append(('N/A', 'EMPTY', 'No files found', '1.00'))

    with out.open('w', encoding='utf-8') as fh:
        fh.write('File\tCategory\tSuggestedDestination\tConfidence\n')
        for row in rows:
            fh.write('\t'.join(row) + '\n')
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description='Generate ML-style organization suggestions')
    parser.add_argument('--base', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--limit', type=int, default=50)
    parser.add_argument('--lang', default='en')
    args = parser.parse_args()
    build_plan(args.base, args.out, args.limit, args.lang)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
