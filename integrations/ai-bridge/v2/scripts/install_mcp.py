#!/usr/bin/env python3
"""Explicit, reversible installer for workspace-local Antigravity MCP entry.
No default system/global config mutation. Dry-run unless --apply.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import sys


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--workspace',required=True,help='Existing Antigravity workspace/project root')
    p.add_argument('--bridge-root',required=True,help='Existing locally mounted/synced AI_BRIDGE folder')
    p.add_argument('--config',help='Absolute path to optional private project mapping JSON')
    p.add_argument('--enable-writes',action='store_true',help='Allow creation of new bridge handoffs (never overwrites)')
    p.add_argument('--apply',action='store_true',help='Actually modify .agents/mcp_config.json; otherwise dry run')
    args=p.parse_args()
    workspace=Path(args.workspace).expanduser().resolve()
    root=Path(args.bridge_root).expanduser().resolve()
    server=(Path(__file__).resolve().parent.parent/'bridge_server.py')
    if not workspace.is_dir() or not root.is_dir() or not server.is_file():
        raise SystemExit('Workspace, bridge folder and server must already exist')
    python=shutil.which('python3.11')
    if not python: raise SystemExit('Python 3.11 not found; install via pyenv or specify the right interpreter')
    target=workspace/'.agents'/'mcp_config.json'
    if target.exists():
        old=json.loads(target.read_text(encoding='utf-8'))
        if not isinstance(old,dict): raise SystemExit('Existing config must be a JSON object')
    else: old={}
    servers=old.setdefault('mcpServers',{})
    if not isinstance(servers,dict): raise SystemExit('mcpServers must be a JSON object')
    if 'ai-bridge-safe-local' in servers:
        raise SystemExit('Already configured. Review manually; will not overwrite')
    env={'AI_BRIDGE_ROOT':str(root),'AI_BRIDGE_ALLOW_WRITE':'1' if args.enable_writes else '0'}
    if args.config:
        cfg=Path(args.config).expanduser().resolve()
        if not cfg.is_file(): raise SystemExit('Config does not exist')
        env['AI_BRIDGE_CONFIG']=str(cfg)
    servers['ai-bridge-safe-local']={'command':python,'args':[str(server)],'env':env}
    rendered=json.dumps(old,indent=2,ensure_ascii=False)+'\n'
    if not args.apply:
        print('DRY RUN - no file changes. Target:',target)
        print(rendered)
        return
    target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists():
        backup=target.with_name('mcp_config.json.bak.'+datetime.datetime.now().strftime('%Y%m%dT%H%M%S'))
        shutil.copy2(target,backup)
        print('Backup:',backup)
    tmp=target.with_suffix('.json.tmp')
    with open(tmp,'x',encoding='utf-8') as f: f.write(rendered)
    os.replace(tmp,target)
    print('Installed MCP config:',target)
    print('Restart Antigravity agent or refresh MCP servers. Writes enabled:',args.enable_writes)


if __name__=='__main__': main()