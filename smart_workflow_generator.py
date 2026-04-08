#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path


def build_workflow(out_path: str, lang: str = 'en') -> Path:
    out = Path(out_path).expanduser().resolve()
    base = Path(os.environ.get('BASE_PATH', '.')).expanduser().resolve()
    plans_dir = out.parent
    dupes = plans_dir / 'dupes_plan.tsv'
    snapshot = plans_dir / 'snapshot.tsv'
    workflow = [
        'SMART WORKFLOW',
        f'BASE: {base}',
        '',
        '1. Generate or refresh backups (option 8).',
        '2. Capture a fresh snapshot (option 27).',
        '3. Review duplicates and quarantine candidates (options 10 and 11).',
        '4. Normalize names and harmonize metadata (options 34 and 46).',
        '5. Re-run health and integrity checks (options 59 and 61).',
    ]
    if dupes.exists():
        workflow.append(f'Known duplicate plan detected: {dupes.name}')
    if snapshot.exists():
        workflow.append(f'Existing snapshot detected: {snapshot.name}')

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text('\n'.join(workflow) + '\n', encoding='utf-8')
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description='Generate a smart operational workflow')
    parser.add_argument('--out', required=True)
    parser.add_argument('--lang', default='en')
    args = parser.parse_args()
    build_workflow(args.out, args.lang)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
