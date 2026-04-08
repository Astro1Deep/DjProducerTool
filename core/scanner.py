#!/usr/bin/env python3
"""Canonical scanner implementation for the root-level core package."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path
from typing import Iterable, List, Optional

try:
    from .config import Config
except ImportError:
    from core.config import Config  # type: ignore


def _optional_int(value: str) -> Optional[int]:
    if value == "":
        return None
    return int(value)


AUDIO_EXTENSIONS = {".mp3", ".wav", ".flac", ".aiff", ".aif", ".m4a", ".aac", ".ogg"}
VIDEO_EXTENSIONS = {".mp4", ".mov", ".avi", ".mkv", ".wmv"}
MEDIA_EXTENSIONS = AUDIO_EXTENSIONS | VIDEO_EXTENSIONS

SCAN_FILTER_ALIASES = {
    "all": "__all__",
    "todo": "__all__",
    "everything": "__all__",
    "media": "__media__",
    "audio": "__audio__",
    "video": "__video__",
    "other": "__other__",
    "otros": "__other__",
    "non-media": "__other__",
    "no-media": "__other__",
}


def classify_file_type(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in AUDIO_EXTENSIONS:
        return "audio"
    if suffix in VIDEO_EXTENSIONS:
        return "video"
    return "other"


def resolve_scan_filter(tokens: Optional[Iterable[str]] = None) -> tuple[Optional[set[str]], bool, list[str]]:
    if not tokens:
        return set(Config.EXTENSIONS), False, ["media"]

    normalized_tokens: list[str] = []
    for token in tokens:
        for part in str(token).split(","):
            cleaned = part.strip().lower()
            if cleaned:
                normalized_tokens.append(cleaned)

    if not normalized_tokens:
        return set(Config.EXTENSIONS), False, ["media"]

    extensions: set[str] = set()
    include_other = False
    labels: list[str] = []

    for token in normalized_tokens:
        mapped = SCAN_FILTER_ALIASES.get(token, token)
        if mapped == "__all__":
            return None, True, ["all"]
        if mapped == "__media__":
            extensions.update(MEDIA_EXTENSIONS)
            labels.append("media")
            continue
        if mapped == "__audio__":
            extensions.update(AUDIO_EXTENSIONS)
            labels.append("audio")
            continue
        if mapped == "__video__":
            extensions.update(VIDEO_EXTENSIONS)
            labels.append("video")
            continue
        if mapped == "__other__":
            include_other = True
            labels.append("other")
            continue

        ext = mapped if mapped.startswith(".") else f".{mapped}"
        extensions.add(ext)
        labels.append(ext.lstrip("."))

    if not extensions and include_other:
        return set(), True, labels or ["other"]
    return extensions, include_other, labels or ["media"]


class Scanner:
    """File scanner with optional parallel hashing and path safety checks."""

    def __init__(self, root_path: Path, only: Optional[Iterable[str]] = None):
        self.root_path = Path(root_path).resolve()

        allow_outside = os.environ.get("DJPT_ALLOW_OUTSIDE", "0") == "1"
        base_dir = Config.BASE_DIR.resolve()
        if not allow_outside and not self._is_relative_to(self.root_path, base_dir):
            raise ValueError(
                f"Root {self.root_path} está fuera de BASE_DIR ({base_dir}). "
                "Exporta DJPT_ALLOW_OUTSIDE=1 para forzar."
            )

        Config.ensure_dirs()

        self.scan_id = f"scan_{int(time.time())}_{self.root_path.name}"
        self.scans_dir = Path(os.environ.get("DJPT_SCANS_DIR") or Config.SCANS_DIR).resolve()
        self.output_dir = self.scans_dir / self.scan_id
        self.csv_path = self.output_dir / "files_index.csv"
        self.manifest_path = self.output_dir / "manifest.json"
        self.hashes_path = self.output_dir / "hashes.sha256"
        self.max_file_bytes = int(os.environ.get("DJPT_MAX_FILE_BYTES", "0"))
        self.allowed_extensions, self.include_other, self.selection_labels = resolve_scan_filter(only)

        self.use_parallel = os.environ.get("DJPT_PARALLEL", "1") != "0"
        env_workers = os.environ.get("DJPT_PARALLEL_THREADS")
        self.max_workers: Optional[int] = int(env_workers) if env_workers else None

    @staticmethod
    def _is_relative_to(path: Path, base: Path) -> bool:
        try:
            path.relative_to(base)
            return True
        except Exception:
            return False

    def calculate_sha256(self, filepath: Path, block_size: int = 65536) -> Optional[str]:
        sha2 = hashlib.sha256()
        try:
            with open(filepath, "rb") as handle:
                for block in iter(lambda: handle.read(block_size), b""):
                    sha2.update(block)
            return sha2.hexdigest()
        except Exception:
            return None

    def run(self, quick: bool = False, parallel: Optional[bool] = None, max_workers: Optional[int] = None):
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.manifest_path.parent.mkdir(parents=True, exist_ok=True)

        use_parallel = self.use_parallel if parallel is None else parallel
        workers = max_workers or self.max_workers

        print(
            f"Starting scan of {self.root_path} -> {self.output_dir} "
            f"(parallel={use_parallel}, only={','.join(self.selection_labels)})"
        )

        start_time = time.time()
        file_list: List[Path] = []
        for root, dirs, files in os.walk(self.root_path):
            dirs[:] = [entry for entry in dirs if not entry.startswith(".") and entry not in {"_DJProducerTools", "_archive"}]
            for name in files:
                if name.startswith("."):
                    continue
                full_path = Path(root) / name
                suffix = full_path.suffix.lower()
                file_type = classify_file_type(full_path)
                if self.allowed_extensions is None:
                    pass
                elif suffix in self.allowed_extensions:
                    pass
                elif self.include_other and file_type == "other":
                    pass
                else:
                    continue
                file_list.append(full_path)

        results = self._scan_parallel(file_list, quick, workers) if use_parallel else self._scan_sequential(file_list, quick)

        file_count = 0
        total_size = 0
        errors = []

        with open(self.csv_path, "w", newline="", encoding="utf-8") as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(["rel_path", "full_path", "size", "mtime", "sha256", "type"])
            for res in results:
                if not res.get("ok"):
                    errors.append(res.get("error"))
                    continue
                writer.writerow(
                    [
                        str(res["rel_path"]),
                        str(res["full_path"]),
                        res["size"],
                        res["mtime"],
                        res["sha256"] or "",
                        res["type"],
                    ]
                )
                file_count += 1
                total_size += res["size"]

        with open(self.hashes_path, "w", encoding="utf-8") as handle:
            for res in results:
                if res.get("ok") and res.get("sha256"):
                    handle.write(f"{res['sha256']}  {res['rel_path']}\n")

        duration = time.time() - start_time
        print(f"Scan complete. {file_count} files in {duration:.2f}s (errors={len(errors)}).")

        manifest = {
            "scan_id": self.scan_id,
            "root_path": str(self.root_path),
            "timestamp": datetime.now().isoformat(),
            "file_count": file_count,
            "total_size_bytes": total_size,
            "duration_seconds": duration,
            "type": "quick" if quick else "full",
            "parallel": use_parallel,
            "max_workers": workers or os.cpu_count(),
            "selection": self.selection_labels,
            "errors": errors,
        }

        with open(self.manifest_path, "w", encoding="utf-8") as handle:
            json.dump(manifest, handle, indent=2)

        return self.output_dir

    def _process_file(self, full_path: Path, quick: bool):
        try:
            stats = full_path.stat()
            rel_path = full_path.relative_to(self.root_path)
            if self.max_file_bytes and stats.st_size > self.max_file_bytes:
                file_hash = "SKIPPED_TOO_LARGE"
            else:
                file_hash = None if quick else (self.calculate_sha256(full_path) or "ERROR")
            file_type = classify_file_type(full_path)
            return {
                "ok": True,
                "rel_path": rel_path,
                "full_path": full_path,
                "size": stats.st_size,
                "mtime": stats.st_mtime,
                "sha256": file_hash,
                "type": file_type,
            }
        except Exception as exc:
            return {"ok": False, "full_path": str(full_path), "error": str(exc)}

    def _scan_sequential(self, file_list: Iterable[Path], quick: bool):
        results = []
        for idx, full_path in enumerate(file_list, 1):
            results.append(self._process_file(full_path, quick))
            if idx % 100 == 0:
                print(f"\rScanned {idx} files...", end="")
        if results:
            print()
        return results

    def _scan_parallel(self, file_list: List[Path], quick: bool, workers: Optional[int]):
        if workers is None or workers <= 0:
            workers = max(os.cpu_count() or 2, 2)

        results: List[dict] = []
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {executor.submit(self._process_file, path, quick): path for path in file_list}
            for idx, future in enumerate(as_completed(futures), 1):
                results.append(future.result())
                if idx % 100 == 0:
                    print(f"\rScanned {idx} files...", end="")
        if results:
            print()
        return results


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="DJPT Scanner (parallel/hash).")
    parser.add_argument("path", nargs="?", default=".", help="Path to scan")
    parser.add_argument("--quick", action="store_true", help="Skip hash calculation")
    parser.add_argument("--parallel", dest="parallel", action="store_true", default=True, help="Enable parallel hashing (default)")
    parser.add_argument("--no-parallel", dest="parallel", action="store_false", help="Disable parallel hashing")
    parser.add_argument("--max-workers", type=_optional_int, default=None, help="Max workers for parallel mode")
    parser.add_argument("--allow-outside", action="store_true", help="Permit scan outside BASE_DIR")
    parser.add_argument(
        "--only",
        action="append",
        default=[],
        help="Filter by kind or extension. Examples: audio, video, other, all, mp3, wav, mp4. Can be repeated or comma-separated.",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    if args.allow_outside:
        os.environ["DJPT_ALLOW_OUTSIDE"] = "1"
    if "DJPT_BASE_DIR" not in os.environ:
        os.environ["DJPT_BASE_DIR"] = str(Path(args.path).resolve())
    scanner = Scanner(args.path, only=args.only)
    out = scanner.run(quick=args.quick, parallel=args.parallel, max_workers=args.max_workers)
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
