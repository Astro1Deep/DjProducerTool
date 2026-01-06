#!/usr/bin/env python3
"""
Audio analysis (BPM) helper.
Attempts to read BPM from tags; if librosa is available, estimates BPM.
Outputs TSV: path, bpm, confidence, method.
"""
import argparse
import csv
import subprocess
from pathlib import Path
from typing import List, Tuple

try:
    import librosa  # type: ignore
except Exception:
    librosa = None

AUDIO_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif", ".ogg"}


def bpm_from_tags(path: Path) -> Tuple[float, float, str]:
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format_tags=TBPM",
        "-of",
        "default=nk=1:nw=1",
        str(path),
    ]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
        if out:
            return float(out), 0.4, "ffprobe_tag"
    except Exception:
        pass
    return 0.0, 0.0, "none"


def bpm_librosa(path: Path) -> Tuple[float, float, str]:
    if librosa is None:
        return 0.0, 0.0, "librosa_missing"
    try:
        y, sr = librosa.load(path, sr=22050, mono=True, duration=120)
        tempo, beats = librosa.beat.beat_track(y=y, sr=sr)
        conf = min(len(beats) / 50.0, 1.0)
        return float(tempo), conf, "librosa"
    except Exception:
        return 0.0, 0.0, "librosa_error"


def analyze(base: Path, out_tsv: Path, limit: int) -> None:
    files: List[Path] = [p for p in base.rglob("*") if p.suffix.lower() in AUDIO_EXTS and p.is_file()]
    if limit > 0:
        files = files[:limit]
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "bpm", "confidence", "method"])
        for p in files:
            bpm, conf, method = bpm_from_tags(p)
            if bpm <= 0:
                bpm, conf, method = bpm_librosa(p)
            if bpm <= 0:
                w.writerow([str(p), "", "", method])
            else:
                w.writerow([str(p), f"{bpm:.2f}", f"{conf:.2f}", method])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=".", help="Base path for audio search")
    ap.add_argument("--out", default="bpm_report.tsv", help="Output TSV path")
    ap.add_argument("--limit", type=int, default=200, help="Max files to process (0 = all)")
    args = ap.parse_args()
    analyze(Path(args.base).expanduser().resolve(), Path(args.out).expanduser().resolve(), args.limit)


if __name__ == "__main__":
    main()
