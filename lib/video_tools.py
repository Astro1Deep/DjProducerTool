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
from typing import List, Dict, Any, Optional

VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".avi", ".m4v"}
TARGET_BITRATE_VIDEO = 6_000_000  # ~6 Mbps for 1080p
TARGET_BITRATE_AUDIO = 192_000    # 192 kbps AAC


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


def inventory(root: Path, out_tsv: Path, out_json: Optional[Path] = None) -> None:
    files: List[Path] = [p for p in root.rglob("*") if p.suffix.lower() in VIDEO_EXTS and p.is_file()]
    out_json = out_json or out_tsv.with_suffix(".json")
    entries: List[Dict[str, Any]] = []
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "width", "height", "vcodec", "duration_sec", "size_bytes"])
        for p in files:
            info = ffprobe_info(p)
            duration = info.get("duration")
            size_bytes = info.get("size") or p.stat().st_size
            row = {
                "path": str(p),
                "width": info.get("width") or None,
                "height": info.get("height") or None,
                "vcodec": info.get("vcodec") or "",
                "duration_sec": float(duration) if duration is not None else None,
                "size_bytes": int(size_bytes) if size_bytes is not None else None,
            }
            entries.append(row)
            w.writerow(
                [
                    row["path"],
                    row["width"] or "",
                    row["height"] or "",
                    row["vcodec"],
                    row["duration_sec"] or "",
                    row["size_bytes"] or "",
                ]
            )
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(entries, indent=2), encoding="utf-8")


def transcode_plan(root: Path, out_tsv: Path, preset: str = "h264_1080p", out_json: Optional[Path] = None) -> None:
    files: List[Path] = [p for p in root.rglob("*") if p.suffix.lower() in VIDEO_EXTS and p.is_file()]
    out_json = out_json or out_tsv.with_suffix(".json")
    entries: List[Dict[str, Any]] = []
    out_tsv.parent.mkdir(parents=True, exist_ok=True)
    with out_tsv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["path", "action", "ffmpeg_cmd", "est_size_mb", "est_time_sec"])
        for p in files:
            info = ffprobe_info(p)
            width = info.get("width") or 0
            height = info.get("height") or 0
            vcodec = (info.get("vcodec") or "").lower()
            duration = float(info.get("duration")) if info.get("duration") else None
            needs = vcodec != "h264" or width > 1920 or height > 1080
            if not needs:
                row = {
                    "path": str(p),
                    "action": "KEEP",
                    "ffmpeg_cmd": "",
                    "est_size_mb": None,
                    "est_time_sec": None,
                }
                entries.append(row)
                w.writerow([row["path"], row["action"], row["ffmpeg_cmd"], "", ""])
                continue
            out_name = p.with_suffix(".serato.mp4")
            target_bitrate = TARGET_BITRATE_VIDEO + TARGET_BITRATE_AUDIO
            est_size_mb = None
            est_time_sec = None
            if duration:
                est_size_mb = round(duration * target_bitrate / 8 / 1_000_000, 2)
                # Assuming ~1.5x realtime on modest CPU/GPU; leave as hint
                est_time_sec = round(duration * 1.5, 2)
            cmd = (
                f'ffmpeg -y -i "{p}" -c:v libx264 -preset medium -crf 20 '
                f'-vf "scale=min(1920\\,iw):min(1080\\,ih):force_original_aspect_ratio=decrease" '
                f'-c:a aac -b:a 192k "{out_name}"'
            )
            row = {
                "path": str(p),
                "action": preset,
                "ffmpeg_cmd": cmd,
                "est_size_mb": est_size_mb,
                "est_time_sec": est_time_sec,
            }
            entries.append(row)
            w.writerow(
                [
                    row["path"],
                    row["action"],
                    row["ffmpeg_cmd"],
                    row["est_size_mb"] if row["est_size_mb"] is not None else "",
                    row["est_time_sec"] if row["est_time_sec"] is not None else "",
                ]
            )
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(entries, indent=2), encoding="utf-8")


def main():
    if len(sys.argv) < 4:
        print(
            "Usage: video_tools.py [inventory|transcode_plan] <base_path> <out_tsv> [out_json] [preset]",
            file=sys.stderr,
        )
        sys.exit(1)
    mode = sys.argv[1]
    base = Path(sys.argv[2]).expanduser()
    out_tsv = Path(sys.argv[3]).expanduser()
    out_json = Path(sys.argv[4]).expanduser() if len(sys.argv) > 4 else None
    if mode == "inventory":
        inventory(base, out_tsv, out_json)
    elif mode == "transcode_plan":
        preset_arg = sys.argv[5] if len(sys.argv) > 5 else sys.argv[4] if len(sys.argv) > 4 else "h264_1080p"
        transcode_plan(base, out_tsv, preset_arg, out_json)
    else:
        print(f"Unknown mode: {mode}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
