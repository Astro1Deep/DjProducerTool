#!/usr/bin/env python3
"""
Lightweight OSC + HTTP status server for DJProducerTools.
- HTTP: /status, /reports (JSON)
- OSC: /djpt/ping -> "pong", /djpt/status -> basic info
Requires: python3; optional python-osc for OSC listener.
"""
import argparse
import json
import os
import threading
import time
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Any, Dict, List, Optional
import sys

try:
    from pythonosc import dispatcher, osc_server  # type: ignore
except Exception:
    dispatcher = None
    osc_server = None


def tail_file(path: Path, limit: int = 50) -> List[str]:
    if not path.exists():
        return []
    try:
        with path.open("r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        return [ln.rstrip("\n") for ln in lines[-limit:]]
    except Exception:
        return []


def dupes_summary(state_dir: Path) -> Dict[str, Any]:
    plan = state_dir / "plans" / "dupes_plan.tsv"
    if not plan.exists():
        return {"path": None, "entries": 0}
    try:
        with plan.open("r", encoding="utf-8", errors="replace") as f:
            lines = [ln for ln in f.readlines() if ln.strip()]
        # If there is a header, ignore the first row
        entries = max(len(lines) - 1, 0)
    except Exception:
        entries = 0
    return {"path": str(plan), "entries": entries}


def list_reports(report_dir: Path, limit: int = 20) -> List[Dict[str, Any]]:
    if not report_dir.exists():
        return []
    files: List[Path] = sorted(report_dir.glob("*"), key=lambda p: p.stat().st_mtime, reverse=True)
    out: List[Dict[str, Any]] = []
    for p in files[:limit]:
        try:
            st = p.stat()
            out.append(
                {
                    "path": str(p),
                    "name": p.name,
                    "size": st.st_size,
                    "mtime": st.st_mtime,
                }
            )
        except Exception:
            continue
    return out


class StatusHandler(BaseHTTPRequestHandler):
    def _write(self, code: int, obj: Dict[str, Any]) -> None:
        payload = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802
        token = getattr(self.server, "auth_token", None)  # type: ignore[attr-defined]
        if token:
            auth = self.headers.get("Authorization")
            if auth != f"Bearer {token}":
                self._write(401, {"error": "unauthorized"})
                return
        try:
            parsed = urllib.parse.urlparse(self.path)
            query = urllib.parse.parse_qs(parsed.query)
            if parsed.path.startswith("/status"):
                self._write(
                    200,
                    {
                        "base_path": str(self.server.base_path),  # type: ignore[attr-defined]
                        "state_dir": str(self.server.state_dir),  # type: ignore[attr-defined]
                        "ts": time.time(),
                    },
                )
            elif parsed.path.startswith("/reports"):
                self._write(200, {"reports": list_reports(self.server.report_dir)})  # type: ignore[attr-defined]
            elif parsed.path.startswith("/dupes/summary"):
                self._write(200, dupes_summary(self.server.state_dir))  # type: ignore[attr-defined]
            elif parsed.path.startswith("/logs/tail"):
                limit = int(query.get("limit", ["50"])[0])
                logs_dir: Path = self.server.state_dir / "logs"  # type: ignore[attr-defined]
                latest: Optional[Path] = None
                if logs_dir.exists():
                    log_files = sorted(logs_dir.glob("*.log"), key=lambda p: p.stat().st_mtime, reverse=True)
                    latest = log_files[0] if log_files else None
                lines = tail_file(latest, limit) if latest else []
                self._write(200, {"file": str(latest) if latest else None, "lines": lines})
            else:
                self._write(404, {"error": "not found"})
        except Exception as e:  # pragma: no cover - defensive
            self._write(500, {"error": str(e)})


def start_http_server(
    host: str, port: int, base: Path, state: Path, report: Path, auth_token: Optional[str] = None
) -> HTTPServer:
    server = HTTPServer((host, port), StatusHandler)
    server.base_path = base  # type: ignore[attr-defined]
    server.state_dir = state  # type: ignore[attr-defined]
    server.report_dir = report  # type: ignore[attr-defined]
    server.auth_token = auth_token  # type: ignore[attr-defined]
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    return server


def start_osc_server(host: str, port: int, base: Path, state: Path) -> Optional[Any]:
    if dispatcher is None or osc_server is None:
        return None
    disp = dispatcher.Dispatcher()

    def ping_handler(unused_addr, *args):  # type: ignore[unused-argument]
        return "pong"

    def status_handler(unused_addr, *args):  # type: ignore[unused-argument]
        return json.dumps({"base_path": str(base), "state_dir": str(state), "ts": time.time()})

    disp.map("/djpt/ping", ping_handler)
    disp.map("/djpt/status", status_handler)
    server = osc_server.ThreadingOSCUDPServer((host, port), disp)
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    return server


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=os.getcwd(), help="BASE_PATH")
    ap.add_argument("--state", default=None, help="STATE_DIR (default: BASE/_DJProducerTools)")
    ap.add_argument("--report", default=None, help="Reports dir (default: STATE/reports)")
    ap.add_argument("--http-host", default="127.0.0.1")
    ap.add_argument("--http-port", type=int, default=8000)
    ap.add_argument("--osc-host", default="127.0.0.1")
    ap.add_argument("--osc-port", type=int, default=9000)
    ap.add_argument("--no-osc", action="store_true", help="Disable OSC server")
    ap.add_argument("--auth-token", default=None, help="Bearer token for HTTP/OSC (optional)")
    args = ap.parse_args()

    base = Path(args.base).expanduser().resolve()
    state = Path(args.state).expanduser().resolve() if args.state else base / "_DJProducerTools"
    report = Path(args.report).expanduser().resolve() if args.report else state / "reports"

    http_srv = start_http_server(args.http_host, args.http_port, base, state, report, auth_token=args.auth_token)
    osc_srv = None
    if not args.no_osc:
        osc_srv = start_osc_server(args.osc_host, args.osc_port, base, state)
        if osc_srv is None:
            print("python-osc no instalado, servidor OSC no iniciado", file=sys.stderr)
    print(f"[INFO] HTTP server on http://{args.http_host}:{args.http_port} base={base}")
    if osc_srv:
        print(f"[INFO] OSC server on {args.osc_host}:{args.osc_port}")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    http_srv.shutdown()
    if osc_srv:
        osc_srv.shutdown()


if __name__ == "__main__":
    main()
