#!/usr/bin/env python3
"""
AI system analyzer orchestrates multiple analyzers and produces a consolidated report.
"""

import argparse
import json
import os
import subprocess
import time
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional

ROOT_DEFAULT = "."
DEFAULT_TIMEOUT = 45
DEFAULT_RETRIES = 3
RETRIABLE_ERRORS = {"timeout", "spawn_error", "process_error", "empty_output", "json_error"}


def _error_payload(
    *,
    error_type: str,
    error: str,
    command: Optional[str] = None,
    stderr: Optional[str] = None,
    stdout: Optional[str] = None,
) -> Dict[str, Any]:
    payload: Dict[str, Any] = {
        "error_type": error_type,
        "error": error,
        "ok": False,
    }
    if command:
        payload["command"] = command
    if stderr:
        payload["stderr"] = stderr[:1000]
    if stdout:
        payload["stdout"] = stdout[:1000]
    return payload


def validate_command_exists(cmd_path: Path) -> bool:
    """Validate that command exists before execution"""
    return cmd_path.exists() and cmd_path.is_file() and os.access(cmd_path, os.R_OK)


def run_json_with_backoff(cmd: List[str], timeout: int = DEFAULT_TIMEOUT, retries: int = DEFAULT_RETRIES) -> Dict[str, Any]:
    """Run command with exponential backoff"""
    for attempt in range(retries):
        result = run_json(cmd, timeout_seconds=timeout * (2**attempt))
        if not _is_stage_error(result):
            return result
        error_type = str(result.get("error_type", "unknown"))
        if attempt == retries - 1 or error_type not in RETRIABLE_ERRORS:
            return result
        time.sleep(2**attempt)
    return _error_payload(error_type="backoff_exhausted", error="Backoff exhausted unexpectedly", command=" ".join(cmd))


def run_json(cmd: List[str], timeout_seconds: int = DEFAULT_TIMEOUT) -> Dict[str, Any]:
    """Run command and parse JSON output with defensive error handling."""
    command_str = " ".join(cmd)
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return _error_payload(
            error_type="timeout",
            error="Command timeout",
            command=command_str,
        )
    except OSError as exc:
        return _error_payload(
            error_type="spawn_error",
            error=f"Could not execute command: {exc}",
            command=command_str,
        )

    if proc.returncode != 0:
        return _error_payload(
            error_type="process_error",
            error=f"Command failed with exit code {proc.returncode}",
            command=command_str,
            stderr=proc.stderr,
            stdout=proc.stdout,
        )

    raw_out = (proc.stdout or "").strip()
    if not raw_out:
        return _error_payload(
            error_type="empty_output",
            error="Command produced empty output",
            command=command_str,
        )

    try:
        parsed = json.loads(raw_out)
    except json.JSONDecodeError as exc:
        return _error_payload(
            error_type="json_error",
            error=f"JSON parsing failed: {exc}",
            command=command_str,
            stdout=raw_out,
            stderr=proc.stderr,
        )

    if isinstance(parsed, dict):
        parsed.setdefault("ok", True)
    return parsed


def _finalize_stage_payload(stage: str, command: List[str], raw_payload: Any, duration_ms: int) -> Dict[str, Any]:
    command_str = " ".join(command)
    payload: Dict[str, Any] = {}
    if isinstance(raw_payload, dict):
        payload.update(raw_payload)
    else:
        payload["result"] = raw_payload

    is_error = _is_stage_error(payload)
    success = bool(payload.get("ok", not is_error)) and not is_error
    payload["ok"] = success
    payload["success"] = success
    payload["stage"] = stage
    payload["command"] = command_str
    payload["duration_ms"] = duration_ms
    payload["error_summary"] = None if success else str(payload.get("error", payload.get("error_type", "unknown_error")))
    return payload


def run_stage(
    *,
    root: Path,
    stage: str,
    script_rel_path: str,
    args: List[str],
    timeout_seconds: int,
    python_bin: str,
    retries: int,
) -> Dict[str, Any]:
    script_path = root / script_rel_path
    if not validate_command_exists(script_path):
        payload = _error_payload(
            error_type="command_missing",
            error=f"Missing script for stage '{stage}': {script_path}",
        )
        return _finalize_stage_payload(stage, [python_bin, str(script_path), *args], payload, 0)

    command = [python_bin, str(script_path)] + args
    start = time.perf_counter()
    payload = run_json_with_backoff(command, timeout=timeout_seconds, retries=retries)
    duration_ms = int((time.perf_counter() - start) * 1000)
    return _finalize_stage_payload(stage, command, payload, duration_ms)


def _is_stage_error(payload: Any) -> bool:
    return isinstance(payload, dict) and "error_type" in payload


def validate_report_schema(report: Dict[str, Any]) -> Dict[str, Any]:
    required_top = {
        "timestamp",
        "root",
        "deploy",
        "system_analyzer",
        "deep_debugger",
        "production_tester",
        "structure_optimizer",
        "cross_directory",
    }
    missing_top = sorted(required_top - set(report.keys()))
    invalid_stage_keys: List[str] = []
    missing_stage_fields: Dict[str, List[str]] = {}

    for key in (
        "system_analyzer",
        "deep_debugger",
        "production_tester",
        "structure_optimizer",
        "cross_directory",
    ):
        if key not in report:
            invalid_stage_keys.append(key)
            continue
        stage_payload = report[key]
        if not isinstance(stage_payload, dict):
            invalid_stage_keys.append(key)
            continue
        missing_fields = [fld for fld in ("success", "error_summary", "duration_ms", "command") if fld not in stage_payload]
        if missing_fields:
            missing_stage_fields[key] = missing_fields

    return {
        "ok": len(missing_top) == 0 and len(invalid_stage_keys) == 0 and len(missing_stage_fields) == 0,
        "missing_top_keys": missing_top,
        "invalid_stage_keys": invalid_stage_keys,
        "missing_stage_fields": missing_stage_fields,
    }


def collect_error_buckets(report: Dict[str, Any]) -> Dict[str, int]:
    buckets: Dict[str, int] = {}
    for key in (
        "system_analyzer",
        "deep_debugger",
        "production_tester",
        "structure_optimizer",
        "cross_directory",
    ):
        payload = report.get(key)
        if isinstance(payload, dict) and not payload.get("success", True):
            error_type = str(payload.get("error_type", "unknown"))
            buckets[error_type] = buckets.get(error_type, 0) + 1
    return buckets


def _safe_write_json(path: Path, payload: Dict[str, Any], fallback_dir: Path, ts: str) -> Path:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
        return path
    except OSError:
        fallback_dir.mkdir(parents=True, exist_ok=True)
        fallback = fallback_dir / f"ai_system_report_fallback_{ts}.json"
        fallback.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
        return fallback


def _cleanup_old_reports(reports_dir: Path, max_reports: int) -> List[str]:
    if max_reports <= 0:
        return []

    def _extract_timestamp(path: Path) -> Optional[str]:
        name = path.name
        prefix = "ai_system_report_"
        suffix = ".json"
        if not (name.startswith(prefix) and name.endswith(suffix)):
            return None
        stamp = name[len(prefix) : -len(suffix)]
        if len(stamp) != 15 or stamp[8] != "_":
            return None
        numeric = stamp.replace("_", "")
        if not numeric.isdigit():
            return None
        return stamp

    all_reports = list(reports_dir.glob("ai_system_report_*.json"))
    dated_reports: List[tuple[str, str, Path]] = []
    undated_reports: List[tuple[str, Path]] = []
    for report_path in all_reports:
        stamp = _extract_timestamp(report_path)
        if stamp is None:
            undated_reports.append((report_path.name, report_path))
        else:
            dated_reports.append((stamp, report_path.name, report_path))

    dated_reports.sort(key=lambda item: (item[0], item[1]), reverse=True)
    undated_reports.sort(key=lambda item: item[0], reverse=True)
    reports = [item[2] for item in dated_reports] + [item[1] for item in undated_reports]
    to_delete = reports[max_reports:]
    removed: List[str] = []
    for path in to_delete:
        try:
            path.unlink()
            removed.append(str(path))
        except OSError:
            continue
    return removed


def _write_md_summary(path: Path, report: Dict[str, Any]) -> None:
    lines = [
        "# AI System Analysis Summary",
        "",
        f"- Timestamp: {report.get('timestamp', 'unknown')}",
        f"- Root: {report.get('root', 'unknown')}",
        f"- Deploy: {report.get('deploy', 'unknown')}",
        "",
        "## Stage status",
    ]

    for key in (
        "system_analyzer",
        "deep_debugger",
        "production_tester",
        "structure_optimizer",
        "cross_directory",
    ):
        payload = report.get(key, {})
        if isinstance(payload, dict) and not payload.get("success", True):
            lines.append(f"- {key}: FAIL ({payload.get('error_type', 'unknown')})")
        else:
            lines.append(f"- {key}: OK")

    if report.get("error_buckets"):
        lines.append("")
        lines.append("## Error buckets")
        for err, count in sorted(report["error_buckets"].items()):
            lines.append(f"- {err}: {count}")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="AI system analyzer")
    parser.add_argument("--root", default=ROOT_DEFAULT)
    parser.add_argument("--deploy", default="/Volumes/SeaGate2TB/DJPT FUERA EN DISCO")
    parser.add_argument("--fast", action="store_true")
    parser.add_argument("--max-files", type=int, default=0)
    parser.add_argument("--skip-cross", action="store_true")
    parser.add_argument("--json-out")
    parser.add_argument("--md-out")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    parser.add_argument("--retries", type=int, default=DEFAULT_RETRIES)
    parser.add_argument("--strict-schema", action="store_true")
    parser.add_argument("--no-write", action="store_true", help="Don't write report file")
    parser.add_argument("--max-reports", type=int, default=100, help="Max report files to keep")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    python_bin = os.environ.get("DJPT_PYTHON_BIN", "python3")
    reports_dir = root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")

    system_analyzer = run_stage(
        root=root,
        stage="system_analyzer",
        script_rel_path="scripts/system_analyzer.py",
        args=["--base-path", str(root)],
        timeout_seconds=args.timeout,
        python_bin=python_bin,
        retries=args.retries,
    )

    deep_args = ["--root", str(root)]
    if args.fast:
        deep_args.extend(["--paths", "scripts"])
    if args.max_files:
        deep_args.extend(["--max-files", str(args.max_files)])
    deep_debugger = run_stage(
        root=root,
        stage="deep_debugger",
        script_rel_path="scripts/deep_debugger.py",
        args=deep_args,
        timeout_seconds=args.timeout,
        python_bin=python_bin,
        retries=args.retries,
    )

    production_tester = run_stage(
        root=root,
        stage="production_tester",
        script_rel_path="scripts/production_tester.py",
        args=["--root", str(root)],
        timeout_seconds=args.timeout,
        python_bin=python_bin,
        retries=args.retries,
    )

    structure_optimizer = run_stage(
        root=root,
        stage="structure_optimizer",
        script_rel_path="scripts/structure_optimizer.py",
        args=["--root", str(root)],
        timeout_seconds=args.timeout,
        python_bin=python_bin,
        retries=args.retries,
    )

    cross_directory: Dict[str, Any] = {
        "skipped": True,
        "ok": True,
        "success": True,
        "error_summary": None,
        "duration_ms": 0,
        "command": "skipped",
        "stage": "cross_directory",
    }
    if not args.skip_cross:
        cross_args = ["--dev", str(root), "--deploy", args.deploy]
        if args.fast:
            cross_args.append("--fast")
        if args.max_files:
            cross_args.extend(["--max-files", str(args.max_files)])
        cross_directory = run_stage(
            root=root,
            stage="cross_directory",
            script_rel_path="scripts/cross_directory_analyzer.py",
            args=cross_args,
            timeout_seconds=args.timeout,
            python_bin=python_bin,
            retries=args.retries,
        )

    report: Dict[str, Any] = {
        "timestamp": ts,
        "root": str(root),
        "deploy": args.deploy,
        "system_analyzer": system_analyzer,
        "deep_debugger": deep_debugger,
        "production_tester": production_tester,
        "structure_optimizer": structure_optimizer,
        "cross_directory": cross_directory,
    }
    report["schema_validation"] = validate_report_schema(report)
    report["error_buckets"] = collect_error_buckets(report)
    report["python_bin"] = python_bin

    if args.no_write:
        report["report_file"] = None
        report["reports_pruned"] = []
    else:
        output_path = Path(args.json_out) if args.json_out else reports_dir / f"ai_system_report_{ts}.json"
        final_json_path = _safe_write_json(output_path, report, reports_dir, ts)
        report["report_file"] = str(final_json_path)
        report["reports_pruned"] = _cleanup_old_reports(reports_dir, args.max_reports)
        # Persist again if fallback path changed after adding report metadata.
        _safe_write_json(final_json_path, report, reports_dir, ts)

    if args.md_out and not args.no_write:
        _write_md_summary(Path(args.md_out), report)
    elif args.md_out and args.no_write:
        report["md_out_ignored"] = True

    print(json.dumps(report, indent=2, ensure_ascii=False))

    if args.strict_schema and not report["schema_validation"]["ok"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
