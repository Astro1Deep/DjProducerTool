#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import signal
import threading
import time
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


class ReusableHTTPServer(ThreadingHTTPServer):
    allow_reuse_address = True


def _build_handler(status_factory, reports_factory, auth_token: str | None):
    class Handler(BaseHTTPRequestHandler):
        def _authorized(self) -> bool:
            if not auth_token:
                return True
            return self.headers.get('Authorization') == f'Bearer {auth_token}'

        def _send_json(self, payload: Any, status: HTTPStatus = HTTPStatus.OK) -> None:
            body = json.dumps(payload, indent=2, ensure_ascii=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:  # noqa: N802
            if not self._authorized():
                self._send_json({'error': 'unauthorized'}, HTTPStatus.UNAUTHORIZED)
                return
            if self.path == '/status':
                self._send_json(status_factory())
                return
            if self.path == '/reports':
                self._send_json(reports_factory())
                return
            self._send_json({'error': 'not_found', 'path': self.path}, HTTPStatus.NOT_FOUND)

        def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
            return

    return Handler


def main() -> int:
    parser = argparse.ArgumentParser(description='Run a lightweight DJPT HTTP/OSC integration server')
    parser.add_argument('--base', required=True)
    parser.add_argument('--state', required=True)
    parser.add_argument('--report', required=True)
    parser.add_argument('--http-port', type=int, default=8000)
    parser.add_argument('--osc-port', type=int, default=9000)
    parser.add_argument('--auth-token')
    parser.add_argument('--disable-osc', action='store_true')
    args = parser.parse_args()

    base = Path(args.base).expanduser().resolve()
    state = Path(args.state).expanduser().resolve()
    report_dir = Path(args.report).expanduser().resolve()
    state.mkdir(parents=True, exist_ok=True)
    report_dir.mkdir(parents=True, exist_ok=True)

    osc_enabled = False
    osc_server = None
    osc_thread = None
    if not args.disable_osc:
        try:
            from pythonosc.dispatcher import Dispatcher  # type: ignore
            from pythonosc.osc_server import ThreadingOSCUDPServer  # type: ignore

            dispatcher = Dispatcher()
            dispatcher.map('/djpt/ping', lambda address, *osc_args: None)
            osc_server = ThreadingOSCUDPServer(('127.0.0.1', args.osc_port), dispatcher)
            osc_thread = threading.Thread(target=osc_server.serve_forever, daemon=True)
            osc_thread.start()
            osc_enabled = True
        except Exception:
            osc_server = None
            osc_thread = None
            osc_enabled = False

    def status_payload() -> dict[str, Any]:
        return {
            'ts': datetime.now(timezone.utc).isoformat(),
            'base_path': str(base),
            'state_dir': str(state),
            'reports_dir': str(report_dir),
            'http_port': args.http_port,
            'osc_port': args.osc_port,
            'osc_enabled': osc_enabled,
        }

    def reports_payload() -> dict[str, Any]:
        files = sorted(p.name for p in report_dir.glob('*') if p.is_file())
        return {'reports': files, 'count': len(files)}

    handler = _build_handler(status_payload, reports_payload, args.auth_token)
    http_server = ReusableHTTPServer(('127.0.0.1', args.http_port), handler)
    http_thread = threading.Thread(target=http_server.serve_forever, daemon=True)
    http_thread.start()

    stop_event = threading.Event()

    def handle_signal(signum, frame):  # type: ignore[unused-argument]
        stop_event.set()
        http_server.shutdown()
        if osc_server is not None:
            osc_server.shutdown()

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    try:
        while not stop_event.is_set():
            time.sleep(0.2)
    finally:
        http_server.server_close()
        if osc_server is not None:
            osc_server.server_close()
        if osc_thread is not None:
            osc_thread.join(timeout=1.0)
        http_thread.join(timeout=1.0)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
