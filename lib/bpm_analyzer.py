#!/usr/bin/env python3
"""
Audio analysis (BPM/key/energy) helper.
- Reads BPM from tags; if librosa is available, estimates BPM.
- Extracts simple key (chroma max) and energy (RMS) when librosa is present.
Outputs TSV: path, bpm, confidence, method, key, key_confidence, energy_rms, beat_count, first_beat_sec.
"""
import argparse
import csv
import subprocess
from pathlib import Path
from typing import List, Tuple, Any, Optional

try:
    import librosa  # type: ignore
except Exception:
    librosa = None

AUDIO_EXTS = {".mp3", ".wav", ".flac", ".m4a", ".aiff", ".aif", ".ogg"}


def bpm_from_tags(path: Path) -> Tuple[float, float, str]:
    # Check if ffprobe is available
    import shutil
    if not shutil.which("ffprobe"):
        return 0.0, 0.0, "ffprobe_missing"
    
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


def bpm_librosa(path: Path, max_duration: float, tempo_min: float, tempo_max: float) -> Tuple[float, float, str, Any]:
    if librosa is None:
        return 0.0, 0.0, "librosa_missing", None
    try:
        y, sr = librosa.load(path, sr=22050, mono=True, duration=max_duration)
        tempo, beats = librosa.beat.beat_track(y=y, sr=sr, start_bpm=min(max(tempo_min, 60.0), tempo_max))
        if tempo < tempo_min or tempo > tempo_max:
            return 0.0, 0.0, "librosa_out_of_range", (y, sr, beats)
        conf = min(len(beats) / 50.0, 1.0)
        return float(tempo), conf, "librosa", (y, sr, beats)
    except Exception:
        return 0.0, 0.0, "librosa_error", None


def audio_features(y_sr_beats: Any) -> Tuple[str, float, float, Optional[int], Optional[float]]:
    """Return key, key_confidence (0-1), energy (RMS), beat count, first beat sec."""
    if librosa is None or y_sr_beats is None:
        return "", 0.0, 0.0, None, None
    if len(y_sr_beats) == 3:
        y, sr, beats = y_sr_beats
    else:
        y, sr = y_sr_beats
        beats = []
    try:
        chroma = librosa.feature.chroma_cqt(y=y, sr=sr)
        weights = chroma.mean(axis=1)
        if weights.sum() > 0:
            idx = int(weights.argmax())
            conf = float(weights[idx] / weights.sum())
        else:
            idx = 0
            conf = 0.0
        keys = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        key_name = keys[idx % len(keys)]
        energy = float(librosa.feature.rms(y=y).mean())
        beat_count = len(beats) if beats is not None else None
        first_beat_sec = None
        if beats is not None and len(beats) > 0:
            first_beat_sec = float(librosa.frames_to_time(beats[0], sr=sr))
        return key_name, conf, energy, beat_count, first_beat_sec
    except Exception:
        return "", 0.0, 0.0, None, None


def analyze(base: Path, out_tsv: Path, limit: int, max_duration: float, tempo_min: float, tempo_max: float) -> None:
    files: List[Path] = [p for p in base.rglob("*") if p.suffix.lower() in AUDIO_EXTS and p.is_file()]
    if limit > 0:
        files = files[:limit]
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(
            ["path", "bpm", "confidence", "method", "key", "key_confidence", "energy_rms", "beat_count", "first_beat_sec"]
        )
        for p in files:
            bpm, conf, method = bpm_from_tags(p)
            y_sr = None
            if bpm <= 0:
                bpm, conf, method, y_sr = bpm_librosa(p, max_duration, tempo_min, tempo_max)
            key, key_conf, energy, beat_count, first_beat_sec = audio_features(y_sr)
            row = [
                str(p),
                f"{bpm:.2f}" if bpm > 0 else "",
                f"{conf:.2f}" if conf > 0 else "",
                method,
                key,
                f"{key_conf:.2f}",
                f"{energy:.4f}",
                beat_count if beat_count is not None else "",
                f"{first_beat_sec:.3f}" if first_beat_sec is not None else "",
            ]
            w.writerow(row)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=".", help="Base path for audio search")
    ap.add_argument("--out", default="bpm_report.tsv", help="Output TSV path")
    ap.add_argument("--limit", type=int, default=200, help="Max files to process (0 = all)")
    ap.add_argument("--max-duration", type=float, default=120.0, help="Max seconds to analyze per file (default 120s)")
    ap.add_argument("--tempo-min", type=float, default=60.0, help="Minimum acceptable BPM (default 60)")
    ap.add_argument("--tempo-max", type=float, default=200.0, help="Maximum acceptable BPM (default 200)")
    args = ap.parse_args()
    analyze(
        Path(args.base).expanduser().resolve(),
        Path(args.out).expanduser().resolve(),
        args.limit,
        args.max_duration,
        args.tempo_min,
        args.tempo_max,
    )


if __name__ == "__main__":
    main()
