#!/usr/bin/env python3
"""
Bridge playlists (.m3u/.m3u8) to OSC/DMX timelines.
Uses ffprobe to estimate durations and assigns start times cumulatively.
"""
import csv
import json
import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Tuple


def ffprobe_duration(path: Path) -> float:
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "a:0",
        "-show_entries",
        "format=duration",
        "-of",
        "default=nw=1:nk=1",
        str(path),
    ]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
        return float(out)
    except Exception:
        return 0.0


def read_playlist(pl_path: Path) -> List[Path]:
    entries: List[Path] = []
    base = pl_path.parent
    with pl_path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            p = Path(line)
            if not p.is_absolute():
                p = (base / line).resolve()
            entries.append(p)
    return entries


def osc_plan(entries: List[Path], out_tsv: Path) -> None:
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    start = 0.0
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["start_sec", "address", "type", "value", "note", "file"])
        for idx, p in enumerate(entries, start=1):
            dur = ffprobe_duration(p)
            scene = "INTRO" if idx == 1 else "OUTRO" if idx == len(entries) else "DROP"
            w.writerow([f"{start:.2f}", f"/layer1/clip{idx}/trigger", "string", "PLAY", scene, str(p)])
            start += dur


def dmx_plan(entries: List[Path], out_tsv: Path, base_ch: int = 1) -> None:
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    start = 0.0
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["start_sec", "scene", "channels", "file"])
        for idx, p in enumerate(entries, start=1):
            dur = ffprobe_duration(p)
            scene = "INTRO" if idx == 1 else "OUTRO" if idx == len(entries) else "DROP"
            if scene == "INTRO":
                values = f"CH{base_ch}=80,CH{base_ch+1}=40,CH{base_ch+4}=0"
            elif scene == "OUTRO":
                values = f"CH{base_ch}=60,CH{base_ch+1}=30,CH{base_ch+4}=0"
            else:
                values = f"CH{base_ch}=255,CH{base_ch+1}=180,CH{base_ch+4}=160"
            w.writerow([f"{start:.2f}", scene, values, str(p)])
            start += dur


def main():
    if len(sys.argv) < 4:
        print("Usage: playlist_bridge.py [osc|dmx] <playlist> <out_tsv> [base_channel]", file=sys.stderr)
        sys.exit(1)
    mode = sys.argv[1]
    pl_path = Path(sys.argv[2]).expanduser()
    out_tsv = Path(sys.argv[3]).expanduser()
    base_ch = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    entries = read_playlist(pl_path)
    if mode == "osc":
        osc_plan(entries, out_tsv)
    elif mode == "dmx":
        dmx_plan(entries, out_tsv, base_ch)
    else:
        print(f"Unknown mode: {mode}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
