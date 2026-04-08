#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


KEYWORDS = {
    'dupes': ('HIGH', 'Review duplicate workflow before cleanup'),
    'backup': ('HIGH', 'Refresh backups before destructive operations'),
    'metadata': ('MEDIUM', 'Apply metadata harmonization before syncing'),
    'normalize': ('MEDIUM', 'Normalize names before exporting playlists'),
    'web': ('MEDIUM', 'Clean web artifacts before cross-platform sync'),
    'snapshot': ('LOW', 'Capture integrity snapshots after changes'),
}


def _classify(name: str) -> tuple[str, str]:
    lowered = name.lower()
    for keyword, payload in KEYWORDS.items():
        if keyword in lowered:
            return payload
    return ('LOW', 'General optimization candidate')


def build_plan(plans_dir: str, out_path: str, lang: str = 'en') -> Path:
    plans_root = Path(plans_dir).expanduser().resolve()
    out = Path(out_path).expanduser().resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    rows: list[tuple[str, str, int, str, str]] = []

    if plans_root.exists():
        for path in sorted(plans_root.iterdir()):
            if not path.is_file():
                continue
            try:
                rows_count = sum(1 for _ in path.open('r', encoding='utf-8', errors='ignore'))
            except OSError:
                rows_count = 0
            priority, recommendation = _classify(path.name)
            kind = path.suffix.lower().lstrip('.') or 'file'
            rows.append((path.name, kind, rows_count, priority, recommendation))

    if not rows:
        rows.append(('none', 'global', 0, 'LOW', 'Generate baseline plans before optimization'))

    with out.open('w', encoding='utf-8') as fh:
        fh.write('Plan\tType\tRows\tPriority\tRecommendation\n')
        for plan_name, kind, rows_count, priority, recommendation in rows:
            fh.write(f'{plan_name}\t{kind}\t{rows_count}\t{priority}\t{recommendation}\n')
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description='Generate an efficiency optimization plan from existing plans')
    parser.add_argument('--plans-dir', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--lang', default='en')
    args = parser.parse_args()
    build_plan(args.plans_dir, args.out, args.lang)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
