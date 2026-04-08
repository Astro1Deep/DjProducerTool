#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path

AUDIO_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aac", ".aif", ".aiff", ".ogg"}
BPM_RE = re.compile(r"(?<!\d)(\d{2,3})(?:\.?\d+)?\s?bpm(?!\d)", re.IGNORECASE)


def _bpm_from_name(path: Path):
    m = BPM_RE.search(path.name)
    if not m:
        return None
    bpm = float(m.group(1))
    if 40 <= bpm <= 250:
        return bpm
    return None


def _bpm_from_tags(path: Path):
    try:
        from mutagen import File as MutagenFile  # type: ignore
    except Exception:
        return None

    try:
        meta = MutagenFile(str(path), easy=True)
    except Exception:
        return None

    if not meta:
        return None

    for key in ("bpm", "tbpm", "tempo"):
        if key in meta and meta[key]:
            raw = str(meta[key][0]).strip()
            try:
                bpm = float(raw)
                if 40 <= bpm <= 250:
                    return bpm
            except Exception:
                continue
    return None


def analyze(base: str, out: str, limit: int | None = None):
    base_path = Path(base).expanduser().resolve()
    output_path = Path(out).expanduser().resolve()

    if not base_path.exists():
        print(f"Error: Base directory does not exist: {base}", file=sys.stderr)
        sys.exit(1)

    if not base_path.is_dir():
        print(f"Error: Base path is not a directory: {base}", file=sys.stderr)
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    files = []
    for path in base_path.rglob("*"):
        if path.is_file() and path.suffix.lower() in AUDIO_EXTS:
            files.append(path)

    files.sort()
    if limit and limit > 0:
        files = files[:limit]

    try:
        with output_path.open("w", encoding="utf-8") as f:
            f.write("File\tBPM\tMethod\tConfidence\n")
            for path in files:
                bpm = _bpm_from_name(path)
                method = "filename"
                conf = 0.80

                if bpm is None:
                    bpm = _bpm_from_tags(path)
                    method = "tags"
                    conf = 0.90

                if bpm is None:
                    method = "unknown"
                    conf = 0.0
                    f.write(f"{path}\t\t{method}\t{conf:.2f}\n")
                else:
                    f.write(f"{path}\t{bpm:.2f}\t{method}\t{conf:.2f}\n")

        print(f"Report saved to {output_path} ({len(files)} files)")
    except OSError as e:
        print(f"Error writing to {output_path}: {e}", file=sys.stderr)
        sys.exit(1)


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze BPM for audio files")
    parser.add_argument("--base", required=True, help="Base directory containing audio files")
    parser.add_argument("--out", required=True, help="Output file path")
    parser.add_argument("--limit", type=int, help="Limit number of files to process")

    args = parser.parse_args()
    analyze(args.base, args.out, args.limit)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        raise SystemExit(1)
