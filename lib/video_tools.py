#!/usr/bin/env python3
"""
Video tooling for DJProducerTools.
- inventory: list video files with resolution/codec/duration/size
- transcode_plan: suggest ffmpeg commands for Serato-friendly outputs
"""
import csv
import json
import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Any

VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".avi", ".m4v"}


def ffprobe_info(path: Path) -> Dict[str, Any]:
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=width,height,codec_name,bit_rate",
        "-show_entries",
        "format=duration,size",
        "-of",
        "json",
        str(path),
    ]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        data = json.loads(out)
    except Exception:
        return {}
    info: Dict[str, Any] = {}
    stream = (data.get("streams") or [{}])[0]
    fmt = data.get("format") or {}
    info["width"] = stream.get("width")
    info["height"] = stream.get("height")
    info["vcodec"] = stream.get("codec_name")
    info["v_bitrate"] = stream.get("bit_rate")
    info["duration"] = fmt.get("duration")
    info["size"] = fmt.get("size")
    return info


def inventory(root: Path, out_tsv: Path) -> None:
    files: List[Path] = [p for p in root.rglob("*") if p.suffix.lower() in VIDEO_EXTS and p.is_file()]
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "width", "height", "vcodec", "duration_sec", "size_bytes"])
        for p in files:
            info = ffprobe_info(p)
            w.writerow(
                [
                    str(p),
                    info.get("width") or "",
                    info.get("height") or "",
                    info.get("vcodec") or "",
                    info.get("duration") or "",
                    info.get("size") or p.stat().st_size,
                ]
            )


def transcode_plan(root: Path, out_tsv: Path, preset: str = "h264_1080p") -> None:
    files: List[Path] = [p for p in root.rglob("*") if p.suffix.lower() in VIDEO_EXTS and p.is_file()]
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "action", "ffmpeg_cmd"])
        for p in files:
            info = ffprobe_info(p)
            width = info.get("width") or 0
            height = info.get("height") or 0
            vcodec = (info.get("vcodec") or "").lower()
            needs = vcodec != "h264" or width > 1920 or height > 1080
            if not needs:
                w.writerow([str(p), "KEEP", ""])
                continue
            out_name = p.with_suffix(".serato.mp4")
            cmd = (
                f'ffmpeg -y -i "{p}" -c:v libx264 -preset medium -crf 20 '
                f'-vf "scale=min(1920\\,iw):min(1080\\,ih):force_original_aspect_ratio=decrease" '
                f'-c:a aac -b:a 192k "{out_name}"'
            )
            w.writerow([str(p), preset, cmd])


def main():
    if len(sys.argv) < 4:
        print("Usage: video_tools.py [inventory|transcode_plan] <base_path> <out_tsv>", file=sys.stderr)
        sys.exit(1)
    mode = sys.argv[1]
    base = Path(sys.argv[2]).expanduser()
    out_tsv = Path(sys.argv[3]).expanduser()
    if mode == "inventory":
        inventory(base, out_tsv)
    elif mode == "transcode_plan":
        preset = sys.argv[4] if len(sys.argv) > 4 else "h264_1080p"
        transcode_plan(base, out_tsv, preset)
    else:
        print(f"Unknown mode: {mode}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
