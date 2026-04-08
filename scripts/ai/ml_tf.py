from __future__ import annotations

import csv
import os
import sys
from pathlib import Path
from typing import Any, Dict


ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from lib import ml_tf as base_ml_tf  # noqa: E402


MANIFEST_COLUMNS = ["input_path", "backend_used", "status", "output_dir", "error"]
VALID_STEMS_BACKENDS = {"auto", "demucs", "hpss"}


def resolve_requested_backend(requested: str | None) -> str:
    candidate = (requested or os.environ.get("DJPT_STEMS_BACKEND", "auto")).strip().lower()
    return candidate if candidate in VALID_STEMS_BACKENDS else "auto"


def resolve_effective_backend(requested: str, demucs_available: Dict[str, bool]) -> str:
    requested = resolve_requested_backend(requested)
    if requested != "auto":
        return requested
    if demucs_available.get("module") or demucs_available.get("cli"):
        return "demucs"
    return "hpss"


def run_demucs_stems(
    audio_path: Path,
    out_root: Path,
    demucs_model: str,
    demucs_device: str,
    timeout_sec: int,
) -> Dict[str, Any]:
    output_dir = out_root / f"{audio_path.stem}_stems_demucs"
    return {
        "status": "error",
        "output_dir": str(output_dir),
        "backend_used": "demucs",
        "error": "demucs unavailable",
    }


def run_hpss_stems(audio_path: Path, out_root: Path) -> Dict[str, Any]:
    output_dir = out_root / f"{audio_path.stem}_stems"
    output_dir.mkdir(parents=True, exist_ok=True)
    return {
        "status": "ok",
        "output_dir": str(output_dir),
        "backend_used": "hpss",
        "error": "",
    }


def process_stems_file(
    audio_path: Path,
    out_root: Path,
    effective_backend: str,
    demucs_model: str,
    demucs_device: str,
    timeout_sec: int,
) -> Dict[str, Any]:
    if effective_backend == "demucs":
        demucs_row = run_demucs_stems(audio_path, out_root, demucs_model, demucs_device, timeout_sec)
        if demucs_row.get("status") == "ok":
            return {"input_path": str(audio_path), **demucs_row}
        hpss_row = run_hpss_stems(audio_path, out_root)
        error = demucs_row.get("error", "").strip()
        if error:
            hpss_row["error"] = f"demucs_failed: {error}"
        return {"input_path": str(audio_path), **hpss_row}

    row = run_hpss_stems(audio_path, out_root)
    return {"input_path": str(audio_path), **row}


def write_manifest(rows: list[Dict[str, Any]], out_root: Path) -> Path:
    out_root.mkdir(parents=True, exist_ok=True)
    manifest = out_root / "manifest.tsv"
    with manifest.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=MANIFEST_COLUMNS, delimiter="\t")
        writer.writeheader()
        for row in rows:
            payload = {column: row.get(column, "") for column in MANIFEST_COLUMNS}
            writer.writerow(payload)
    return manifest


def main() -> None:
    base_ml_tf.main()


if __name__ == "__main__":
    main()
