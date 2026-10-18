#!/usr/bin/env python3
"""Safe Antigravity lifecycle hooks for an explicitly scoped AI bridge.

Read stdin JSON. SessionStart injects a harmless reminder, not documents.
Stop optionally records ONLY minimal runtime metadata in a new event file.
Never opens the agent transcript or artifact directory, and never accesses
underlying user project trees. No background process or outbound requests.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import uuid

PROJECT = re.compile(r"^[a-z][a-z0-9_-]{0,63}$")
MAX_INPUT = 1_048_576


def events_path(root: Path) -> Path:
    if not root.is_dir() or root.is_symlink():
        raise ValueError('Root is not a real local directory')
    root = root.resolve(strict=True)
    audit = root / '99_AUDIT'
    if not audit.is_dir() or audit.is_symlink() or not audit.resolve(strict=True).is_relative_to(root):
        raise ValueError('99_AUDIT does not exist or is unsafe')
    events = audit / 'antigravity_events'
    if events.is_symlink():
        raise ValueError('Events dir is a symlink')
    events.mkdir(exist_ok=True)
    if not events.resolve(strict=True).is_relative_to(root):
        raise ValueError('Events dir escapes root')
    return events


def handle(event: str, project: str, payload: dict, root: str | None, audit: bool) -> dict:
    if not PROJECT.fullmatch(project):
        raise ValueError('Invalid project key')
    if not isinstance(payload, dict):
        raise ValueError('Hook input must be JSON object')
    if event == 'start':
        msg = (f'AI_BRIDGE: workspace project key={project}. Before continuing tasks that need '
               'cross-agent context, call the registered ai-bridge-safe-local MCP tools '
               'bridge_status and list_handoffs. Verify source references; handoff reports '
               'are not evidence. Never auto-export entire transcripts, credentials, personal '
               'records or forensic originals. Publishing substantive results requires an '
               'explicit user-reviewed handoff. Do not assume this hook imports sessions.')
        return {'injectSteps': [{'ephemeralMessage': msg}]}
    if event != 'stop':
        raise ValueError('Unsupported event')
    if not audit or payload.get('fullyIdle') is not True:
        return {}
    if not root:
        raise ValueError('AI_BRIDGE_ROOT required for stop audit')
    event_dir = events_path(Path(root).expanduser())
    reason = payload.get('terminationReason', '')
    if not isinstance(reason, str):
        reason = ''
    reason = reason if reason in ('model_stop', 'max_steps_exceeded', 'error', 'cancelled', 'user_stop') else 'other'
    conversation_id = payload.get('conversationId', '')
    if not isinstance(conversation_id, str):
        conversation_id = ''
    uid_hash = hashlib.sha256(conversation_id.encode('utf-8')).hexdigest()[:16] if conversation_id else None
    obj = {
        'schema': 'ai-bridge/antigravity-stop-v1',
        'record_type': 'session_metadata_only',
        'project': project,
        'created_at': datetime.now(timezone.utc).isoformat().replace('+00:00','Z'),
        'conversation_id_hash': uid_hash,
        'fully_idle': True,
        'termination_reason': reason,
        'actor': 'antigravity',
        'has_transcript_content': False,
        'has_evidence_content': False,
        'review_status': 'unverified_agent_runtime_metadata',
    }
    # File ID is unique; O_EXCL refuses overwrite.
    outfile = event_dir / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ_') + uuid.uuid4().hex[:12] + '.json')
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    with os.fdopen(os.open(str(outfile), flags, 0o600), 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write('\n')
    return {}


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument('event', choices=['start', 'stop'])
    p.add_argument('--project', required=True)
    args = p.parse_args()
    try:
        raw = sys.stdin.buffer.read(MAX_INPUT + 1)
        if len(raw) > MAX_INPUT:
            raise ValueError('Hook input exceeded maximum size')
        payload = json.loads(raw or b'{}')
        output = handle(args.event, args.project, payload, os.environ.get('AI_BRIDGE_ROOT'),
                        os.environ.get('AI_BRIDGE_HOOK_AUDIT') == '1')
    except (ValueError, OSError, json.JSONDecodeError) as err:
        print(f'AI Bridge hook error: {err}', file=sys.stderr)
        # Fail open for lifecycle bookkeeping; no actions taken.
        output = {}
    print(json.dumps(output, ensure_ascii=False))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())