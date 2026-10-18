#!/usr/bin/env python3
"""Workspace-only Antigravity hooks installer. Dry-run until --apply.

Never installs into ~/.gemini or any project outside explicitly named workspace.
Preserves existing hook definitions. Can opt in to minimal stop metadata audit.
"""
from __future__ import annotations
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import shlex
import tempfile

KEY_START = 'ai-bridge-session-start'
KEY_STOP = 'ai-bridge-stop-metadata'


def render(existing: dict, project: str, root: Path, python: str, script: Path, audit: bool) -> dict:
    if not isinstance(existing, dict):
        raise ValueError('hooks.json must contain a JSON object')
    if KEY_START in existing or KEY_STOP in existing:
        raise ValueError('AI Bridge hook already installed: review manually, do not overwrite')
    cmd = (f'{shlex.quote(python)} {shlex.quote(str(script))} '
           f'start --project {shlex.quote(project)}')
    result = dict(existing)
    result[KEY_START] = {'SessionStart': [{'type': 'command', 'command': cmd, 'timeout': 5}]}
    if audit:
        stop = (f'AI_BRIDGE_HOOK_AUDIT=1 AI_BRIDGE_ROOT={shlex.quote(str(root))} '
                f'{shlex.quote(python)} {shlex.quote(str(script))} '
                f'stop --project {shlex.quote(project)}')
        result[KEY_STOP] = {'Stop': [{'type':'command', 'command':stop,'timeout': 5}]}
    return result


def main() -> None:
    p=argparse.ArgumentParser()
    p.add_argument('--workspace', required=True)
    p.add_argument('--bridge-root', required=True)
    p.add_argument('--project', required=True)
    p.add_argument('--enable-stop-audit', action='store_true')
    p.add_argument('--apply', action='store_true')
    a=p.parse_args()
    from sys import executable
    src=Path(__file__).resolve().parent.parent/'hooks'/'antigravity_hooks.py'
    ws=Path(a.workspace).expanduser().resolve(strict=True)
    root=Path(a.bridge_root).expanduser().resolve(strict=True)
    if not ws.is_dir() or not root.is_dir(): raise SystemExit('Invalid workspace or bridge directory')
    if not (root/'99_AUDIT').is_dir(): raise SystemExit('99_AUDIT is missing from AI_BRIDGE')
    if not a.project or not a.project[0].islower() or not all(c.islower() or c.isdigit() or c in '_-' for c in a.project):
        raise SystemExit('Invalid project key')
    dest=ws/'.agents'/'hooks.json'
    existing=json.loads(dest.read_text(encoding='utf-8')) if dest.exists() else {}
    result=render(existing,a.project,root,executable,src,a.enable_stop_audit)
    content=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    if not a.apply:
        print('DRY RUN - NO CHANGES:',dest)
        print(content)
        return
    dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.exists():
        backup=dest.with_name(dest.name+'.bak.'+datetime.now().strftime('%Y%m%dT%H%M%S'))
        shutil.copy2(dest,backup)
        print('Backup:',backup)
    fd,temp_name=tempfile.mkstemp(prefix='hooks.json.',suffix='.tmp',dir=dest.parent)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as f: f.write(content)
        os.replace(temp_name,dest)
    finally:
        if os.path.exists(temp_name): os.unlink(temp_name)
    print('Installed:',dest)
    print('Stop audit enabled:',a.enable_stop_audit)

if __name__=='__main__': main()