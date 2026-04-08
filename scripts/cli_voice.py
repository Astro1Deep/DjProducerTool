#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ai.voice_control import VoiceControl


async def _run(audio_file: str, command_type: str) -> int:
    vc = VoiceControl()
    result = await vc.process_command(audio_file, command_type)
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result.get("success") else 2


def main() -> int:
    parser = argparse.ArgumentParser(description="Voice control CLI")
    parser.add_argument("audio_file")
    parser.add_argument("--command-type", default="general")
    args = parser.parse_args()
    return asyncio.run(_run(args.audio_file, args.command_type))


if __name__ == "__main__":
    raise SystemExit(main())
