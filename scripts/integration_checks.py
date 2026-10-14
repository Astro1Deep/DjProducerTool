#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def _spec_available(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


def check_serato(serato_root: str | None) -> dict[str, Any]:
    root = Path(serato_root).expanduser() if serato_root else (ROOT / "_Serato_")
    root_exists = root.exists()
    parser_available = _spec_available("serato_crate")
    tools_available = _spec_available("serato_tools")
    if root_exists:
        status = "ready" if parser_available or tools_available else "missing_optional_deps"
        message = "Serato root detected" if status == "ready" else "Serato root detected but optional parser/tools are missing"
    else:
        status = "not_found"
        message = "Serato root path not found"
    return {
        "status": status,
        "message": message,
        "serato_root": str(root),
        "parser_available": parser_available,
        "tools_available": tools_available,
    }


def check_spotify(client_id: str | None, client_secret: str | None) -> dict[str, Any]:
    client_id = (client_id or "").strip()
    client_secret = (client_secret or "").strip()
    if not client_id or not client_secret:
        return {
            "status": "not_configured",
            "message": "Spotify requires Client ID/Secret to run OAuth client-credentials checks.",
            "client_id_present": bool(client_id),
            "client_secret_present": bool(client_secret),
        }
    return {
        "status": "configured",
        "message": "Spotify credentials are configured for OAuth client-credentials flow.",
        "client_id_present": True,
        "client_secret_present": True,
    }


def check_musicbrainz(app_name: str | None, contact: str | None) -> dict[str, Any]:
    app_name = (app_name or "DJProducerTools").strip() or "DJProducerTools"
    contact = (contact or "").strip()
    status = "configured" if app_name else "not_configured"
    return {
        "status": status,
        "message": "MusicBrainz User-Agent is ready" if status == "configured" else "MusicBrainz app name is missing",
        "app_name": app_name,
        "contact": contact,
    }


def check_mcp() -> dict[str, Any]:
    candidates = [ROOT / "mcp_server.py", ROOT / "mcp_server_fixed.py"]
    available = [str(path) for path in candidates if path.exists()]
    return {
        "status": "ready" if available else "missing",
        "message": "Local MCP server entrypoint detected" if available else "No local MCP server entrypoint found",
        "available_entrypoints": available,
    }


def check_shazam() -> dict[str, Any]:
    shazamio_available = _spec_available("shazamio")
    script_path = ROOT / "lib" / "shazam_recognizer.py"
    script_exists = script_path.exists()
    status = "ready" if shazamio_available and script_exists else ("ready_via_uv" if script_exists else "missing")
    return {
        "status": status,
        "message": "ShazamIO acoustic engine ready" if status in {"ready", "ready_via_uv"} else "ShazamIO engine missing",
        "shazamio_installed": shazamio_available,
        "script_exists": script_exists,
        "engine_script": str(script_path),
    }


def aggregate(serato: dict[str, Any], spotify: dict[str, Any], musicbrainz: dict[str, Any], mcp: dict[str, Any], shazam: dict[str, Any] | None = None) -> dict[str, Any]:
    overall_ok_core = serato["status"] in {"ready", "missing_optional_deps"} and musicbrainz["status"] == "configured" and mcp["status"] == "ready"
    overall_ok_strict = overall_ok_core and serato["parser_available"] and serato["tools_available"] and spotify["status"] == "configured"
    payload = {
        "overall_ok_core": overall_ok_core,
        "overall_ok_strict": overall_ok_strict,
        "serato": serato,
        "spotify": spotify,
        "musicbrainz": musicbrainz,
        "mcp": mcp,
    }
    if shazam:
        payload["shazam"] = shazam
    return payload


def _emit(payload: dict[str, Any]) -> int:
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    if payload.get("overall_ok_core") is False:
        return 1
    for key, value in payload.items():
        if isinstance(value, dict) and value.get("status") in {"not_configured", "not_found", "missing"}:
            return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Deterministic local/web integration checks")
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in ("serato", "spotify", "musicbrainz", "mcp", "shazam", "all"):
        sub = subparsers.add_parser(name)
        sub.add_argument("--serato-root")
        sub.add_argument("--spotify-client-id")
        sub.add_argument("--spotify-client-secret")
        sub.add_argument("--musicbrainz-app")
        sub.add_argument("--musicbrainz-contact")
        sub.add_argument("--json", action="store_true")
    args = parser.parse_args()

    serato = check_serato(getattr(args, "serato_root", None))
    spotify = check_spotify(getattr(args, "spotify_client_id", None), getattr(args, "spotify_client_secret", None))
    musicbrainz = check_musicbrainz(getattr(args, "musicbrainz_app", None), getattr(args, "musicbrainz_contact", None))
    mcp = check_mcp()

    if args.command == "serato":
        return _emit({"serato": serato})
    if args.command == "spotify":
        return _emit({"spotify": spotify})
    if args.command == "musicbrainz":
        return _emit({"musicbrainz": musicbrainz})
    shazam = check_shazam()

    if args.command == "serato":
        return _emit({"serato": serato})
    if args.command == "spotify":
        return _emit({"spotify": spotify})
    if args.command == "musicbrainz":
        return _emit({"musicbrainz": musicbrainz})
    if args.command == "mcp":
        return _emit({"mcp": mcp})
    if args.command == "shazam":
        return _emit({"shazam": shazam})
    return _emit(aggregate(serato, spotify, musicbrainz, mcp, shazam))


if __name__ == "__main__":
    raise SystemExit(main())
